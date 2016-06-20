public protocol StreamDriver {
    static func listen(host: String, port: Int, handler: (Stream) throws -> ()) throws
}

//// //////////

import Foundation

public final class FoundationStream: NSObject, Stream, NSStreamDelegate {
    public enum Error: ErrorProtocol {
        case unableToCompleteWriteOperation
        case unableToConnectToHost
        case unableToUpgradeToSSL
    }

    public var timeout: Double = 0

    public var closed: Bool {
        return input.streamStatus == .closed
            || output.streamStatus == .closed
    }

    let input: NSInputStream
    let output: NSOutputStream

    init(host: String, port: Int) throws {
        var inputStream: NSInputStream? = nil
        var outputStream: NSOutputStream? = nil
        NSStream.getStreamsToHost(withName: host,
                                  port: port,
                                  inputStream: &inputStream,
                                  outputStream: &outputStream)
        guard
            let input = inputStream,
            let output = outputStream
            else { throw Error.unableToConnectToHost }
        input.open()
        output.open()
        self.input = input
        self.output = output
        super.init()

        self.input.delegate = self
        self.output.delegate = self
    }

    public func close() throws {
        output.close()
        input.close()
    }

    func send(_ byte: Byte) throws {
        try send([byte])
    }

    public func send(_ bytes: Bytes) throws {
        var buffer = bytes
        let written = output.write(&buffer, maxLength: buffer.count)
        guard written == bytes.count else {
            throw Error.unableToCompleteWriteOperation
        }
    }

    public func flush() throws {}

    public func receive() throws -> Byte? {
        return try receive(max: 1).first
    }

    public func receive(max: Int) throws -> Bytes {
        var buffer = Bytes(repeating: 0, count: max)
        let read = input.read(&buffer, maxLength: max)
        return buffer.prefix(read).array
    }

    // MARK: Stream Events

    public func stream(_ aStream: NSStream, handle eventCode: NSStreamEvent) {
        Log.warning("Not handling event \(eventCode) from \(aStream)")
        if eventCode.contains(.endEncountered) { _ = try? close() }
    }
}

extension FoundationStream: ClientStream {
    public static func makeConnection(host: String, port: Int, usingSSL: Bool) throws -> Stream {
        let stream = try FoundationStream(host: host, port: port)
        if usingSSL {
            guard stream.output.upgradeSSL() else { throw Error.unableToUpgradeToSSL }
            guard stream.input.upgradeSSL() else { throw Error.unableToUpgradeToSSL }
        }
        return stream
    }
}

extension NSStream {
    func upgradeSSL() -> Bool {
        return setProperty(NSStreamSocketSecurityLevelNegotiatedSSL, forKey: NSStreamSocketSecurityLevelKey)
    }
}

// MARK: Blue

#if os(OSX) || os(iOS) || os(tvOS) || os(watchOS)
    import Darwin
    import Foundation
    import Socket
#elseif os(Linux)
    import Glibc
    import Foundation
    import Socket
#endif

import Foundation
import SSLService

// MARK: Blue Stream

public typealias BlueStream = Socket

public enum BlueStreamError: ErrorProtocol {
    case notSupportedOnBlueStream
    case unableToMakeSocket
}

extension BlueStream: Stream {
    public var timeout: Double {
        get {
            return 0
        }
        set {
            Log.info("Timeout not implemented on blue socket")
        }
    }

    public var closed: Bool { return !isConnected }

    public func send(_ bytes: Bytes) throws {
        var buffer = bytes
        try write(from: &buffer, bufSize: bytes.count)
    }

    public func send(_ bytes: Bytes, flushing: Bool) throws {
        try send(bytes)
    }

    public func flush() throws { }

    public func receive(max: Int) throws -> Bytes {
        /*
            This is the only read version that consistently worked.
            Will further investigate in future
        */
        let buffer = NSMutableData()
        _ = try read(into: buffer)
        return buffer.byteArray
    }

    public func receive() throws -> Byte? {
        /**
            Having trouble reading buffers into specific size, need to read all and then parse from
            it.
         
            To use like a normal stream, wrap in StreamBufer
        */
        throw BlueStreamError.notSupportedOnBlueStream
    }
}

// MARK: Blue Server

public final class BlueStreamDriver: StreamDriver {
    public static func listen(host: String, port: Int, handler: (Stream) throws -> ()) throws {
        let sock = try Socket.create()
        try sock.listen(on: port, maxPendingConnections: 4096) // TODO: What's good max
        while true {
            let next = try sock.acceptClientConnection()
            try handler(next)
        }
    }
}

// MARK: Blue Client

extension BlueStream: ClientStream {
    public static func makeConnection(host: String, port: Int, usingSSL: Bool) throws -> Stream {
        let myConfig = SSLService.Configuration()
        guard
            let signature = try Socket.Signature(
                socketType: .stream,
                proto: .tcp,
                hostname: host,
                port: Int32(port)
            )
            else { throw BlueStreamError.unableToMakeSocket }

        let blue = try BlueStream.create()
        if usingSSL {
            blue.delegate = try SSLService(usingConfiguration: myConfig)
        }
        try blue.connect(using: signature)
        return blue
    }
}
