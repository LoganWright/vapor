public typealias Block = () -> Void

#if os(Linux)
    import Strand

    public func background(function: Block) throws {
        let _ = try Strand(closure: function)
    }
#else
    import Foundation

    let queue = DispatchQueue.global(attributes: .qosBackground)
    // TODO: Don't need to throw anymore
    public func background(function: Block) throws {
        queue.async(execute: function)
    }
#endif
