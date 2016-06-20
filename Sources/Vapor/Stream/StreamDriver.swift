public protocol StreamDriver {
    static func listen(host: String, port: Int, handler: (Stream) throws -> ()) throws
}

//// //////////


import Foundation

public final class FoundationStream: NSObject, Stream, NSStreamDelegate {
    public var timeout: Double = 0
    public var closed: Bool {
        // TODO: Either?
        return backingInputStream.streamStatus == .closed || backingOutputStream.streamStatus == .closed
    }

    public func close() throws {
        backingOutputStream.close()
        backingInputStream.close()
    }

    func send(_ byte: Byte) throws {
        try send([byte])
    }

    public func send(_ bytes: Bytes) throws {
        var buffer = bytes
        // TODO: Compare written and keep writing if more to write
        let written = backingOutputStream.write(&buffer, maxLength: buffer.count)
        if written != bytes.count { print("// TODO: HANDLE THIS CONDITION") }
    }

    public func flush() throws {
        print("NSStream doesn't implement flush")
    }

    public func receive() throws -> Byte? {
        return try receive(max: 1).first
    }

    public func receive(max: Int) throws -> Bytes {
        var buffer = Bytes(repeating: 0, count: max)
        // TODO: Compare read to expected
        let read = backingInputStream.read(&buffer, maxLength: max)
        if read != max { print("Out of bytes or didn't get all") }

        return buffer.prefix(read).array
    }

    let backingInputStream: NSInputStream
    let backingOutputStream: NSOutputStream

    init(host: String, port: Int) throws {
        var inputStream: NSInputStream? = nil
        var outputStream: NSOutputStream? = nil
        NSStream.getStreamsToHost(withName: host,
                                  port: port,
                                  inputStream: &inputStream,
                                  outputStream: &outputStream)
        guard let input = inputStream, let output = outputStream else { fatalError("throw") }
        input.open()
        output.open()
        self.backingInputStream = input
        self.backingOutputStream = output
        print("Status: \(self.backingInputStream.streamStatus)")
        print("Status: \(self.backingOutputStream.streamStatus)")
    }



    public func stream(_ aStream: NSStream, handle eventCode: NSStreamEvent) {
        print("Not handling event \(eventCode) from \(aStream)")
    }
}

extension FoundationStream: ClientStream {
    public static func makeConnection(host: String, port: Int, usingSSL: Bool) throws -> Stream {
        let stream = try FoundationStream(host: host, port: port)
        if usingSSL {
            _ = stream.backingOutputStream.upgradeSSL()
            _ = stream.backingInputStream.upgradeSSL()
        }
        return stream
    }
}

extension NSStream {
    func upgradeSSL() -> Bool {
        return setProperty(NSStreamSocketSecurityLevelNegotiatedSSL, forKey: NSStreamSocketSecurityLevelKey)
    }
}


#if os(OSX) || os(iOS) || os(tvOS) || os(watchOS)
    import Darwin
    import Foundation
    import Socket
#elseif os(Linux)
    import Glibc
    import Foundation
    import Socket
#endif


import SSLService

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

public final class BlueStream: ClientStream {
    public static func makeConnection(host: String, port: Int, usingSSL: Bool) throws -> Stream {
        let myConfig = SSLService.Configuration()
        guard
            let signature = try Socket.Signature(
                socketType: .stream,
                proto: .tcp,
                hostname: host,
                port: Int32(port)
            )
            else { fatalError("// TODO: throw") }

        let socket = try Socket.create()
        if usingSSL {
            socket.delegate = try SSLService(usingConfiguration: myConfig)
        }
        try socket.connect(using: signature)
        return socket
    }
}

extension Socket: ClientStream {
    public static func makeConnection(host: String, port: Int, usingSSL: Bool) throws -> Stream {
        let myConfig = SSLService.Configuration()
        guard
            let signature = try Socket.Signature(
                socketType: .stream,
                proto: .tcp,
                hostname: host,
                port: Int32(port)
            )
            else { fatalError("// TODO: throw") }

        let socket = try Socket.create()
        if usingSSL {
            socket.delegate = try SSLService(usingConfiguration: myConfig)
        }
        try socket.connect(using: signature)
        return socket
    }
}



extension Socket: Stream {
    // TODO:
    public var timeout: Double {
        get {
            return 0
        }
        set {
            print("NOT IMPLEMENTED")
        }
    }

    public var closed: Bool { return !isConnected }

    public func send(_ bytes: Bytes) throws {
        let data = bytes.makeData()
        try write(from: data)
        try flush()
    }

    public func send(_ bytes: Bytes, flushing: Bool) throws {
        print("Flushing not supported by blue socket")
        try send(bytes)
    }

    public func flush() throws {
        print("Flush not supported by blue socket")
    }

    public func receive(max: Int) throws -> Bytes {
        let data = NSMutableData()
        // number of bytes
        let _ = try read(into: data)
        // TODO: Ignoring counts and all of that right now since Iknow it'll be ins tream buffer. Fix going forward
        return data.byteArray
    }

    public func receive() throws -> Byte? {
        fatalError()
    }
}

public final class BlueWrapper {
    private let sock: Socket
    private let data = NSMutableData()

    init(_ sock: Socket) {
        self.sock = sock
    }

    public var timeout: Double {
        get {
            return 0
        }
        set {
            print("NOT IMPLEMENTED")
        }
    }

    public var closed: Bool { return !sock.isConnected }

    public func send(_ bytes: Bytes) throws {
        let data = bytes.makeData()
        try sock.write(from: data)
        try flush()
    }

    public func send(_ bytes: Bytes, flushing: Bool) throws {
        print("Flushing not supported by blue socket")
        try send(bytes)
    }

    public func flush() throws {
        print("Flush not supported by blue socket")
    }

    public func receive(max: Int) throws -> Bytes {
//        let existing = data.byteArray
//        if existing.count <= max {
//            let subsection = existing.dropFirst(max)
//        }

        let data = NSMutableData()
        // returns number of  bytes
        let _ = try sock.read(into: data)
        return data.byteArray
    }

    public func receive() throws -> Byte? {
        fatalError()
    }
}

public final class BlueBuffer: Stream {
    public var closed: Bool {
        return stream.closed
    }
    public func close() throws {
        try stream.close()
    }

    private let stream: Stream
    private let size: Int

    public var timeout: Double {
        get {
            return stream.timeout
        }
        set {
            stream.timeout = newValue
        }
    }

    private var receiveIterator: IndexingIterator<[Byte]>
    private var sendBuffer: Bytes

    public init(_ stream: Stream, size: Int = 2048) {
        self.size = size
        self.stream = stream

        self.receiveIterator = Data().makeIterator()
        self.sendBuffer = []

        timeout = 0
    }

    public func receive() throws -> Byte? {
        guard let next = receiveIterator.next() else {
            receiveIterator = try stream.receive(max: size).makeIterator()
            return receiveIterator.next()
        }
        return next
    }

    public func receive(max: Int) throws -> Bytes {
        var bytes: Bytes = []

        for _ in 0 ..< max {
            guard let byte = try receive() else {
                break
            }

            bytes += byte
        }

        return bytes
    }

    public func send(_ bytes: Bytes) throws {
        sendBuffer += bytes
    }

    public func flush() throws {
        try stream.send(sendBuffer)
        sendBuffer = []
    }

    /**
     Sometimes we let sockets queue things up before flushing, but in situations like web sockets,
     we may want to skip that functionality
     */
    public func send(_ bytes: Bytes, flushing: Bool) throws {
        guard flushing else {
            try send(bytes)
            return
        }

        if !sendBuffer.isEmpty {
            try stream.send(bytes)
            sendBuffer = []
        }
        try stream.send(bytes)
    }
}

extension Sequence where Iterator.Element == Byte {
    func makeData() -> NSData {
        return NSData(bytes: self.array)
    }
}
