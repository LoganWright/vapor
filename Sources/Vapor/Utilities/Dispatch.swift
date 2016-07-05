
import Foundation

public typealias Block = () -> Void

let background = DispatchQueue(label: "vapor-background-queue")
public func background(function: Block) {
    background.async(execute: function)
}
