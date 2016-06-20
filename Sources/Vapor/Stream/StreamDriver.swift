public protocol StreamDriver {
    static func listen(host: String, port: Int, handler: (Stream) throws -> ()) throws
}

import Foundation

/*
 public protocol Stream: class {
 var timeout: Double { get set }

 var closed: Bool { get }
 func close() throws

 func send(_ bytes: Bytes) throws
 func send(_ bytes: Bytes, flushing: Bool) throws
 func flush() throws

 func receive(max: Int) throws -> Bytes
 func receive() throws -> Byte?
 }
 */
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
