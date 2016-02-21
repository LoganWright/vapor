import Foundation

/**
    Responses that redirect to a supplied URL.
 */
public class Redirect: Response {

    ///The URL string for redirect
    public let redirectLocation: String

    /**
        Redirect headers return normal `Response` headers
        while adding `Location`.

        - returns: Dictionary of headers
     */
    override public var headers: [String: String] {
        var headers = super.headers
        headers["Location"] = self.redirectLocation
        return headers
    }

    /**
        Creates a `Response` object that redirects
        to a given URL string.

        - parameter: redirectLocation: The URL string for redirect
        
        - returns: Response
     */
    public init(to redirectLocation: String) {
        self.redirectLocation = redirectLocation
        super.init(status: .MovedPermanently, data: [], contentType: .None)
    }
}

/**
    Allows for asynchronous responses. Passes
    the server Socket to the Response for writing.
    The response calls `release()` on the Socket
    when it is complete.

    Inspired by elliottminns
*/
public class AsyncResponse: Response {
    public typealias Writer = Socket throws -> Void
    public let writer: Writer

    public init(writer: Writer) {
        self.writer = writer
        super.init(status: .OK, data: [], contentType: .None)
    }
}

/**
    Responses are objects responsible for returning
    data to the HTTP request such as the body, status 
    code and headers.
 */
public class Response {
    
    // MARK: Types

    /**
     - InvalidObject: Thrown when attempting to map a Foundation object that is not valid Json
     */
    public enum SerializationError: ErrorType {
        case InvalidObject
    }

    /**
     The content type of response being returned
     */
    public enum ContentType {
        case Text, Html, Json, None
    }

    /**
     Response status to be included in the response
     */
    public enum Status {
        case OK, Created, Accepted
        case MovedPermanently
        case BadRequest, Unauthorized, Forbidden, NotFound
        case Error
        case Unknown
        case Custom(Int)
        
        public var code: Int {
            switch self {
            case .OK: return 200
            case .Created: return 201
            case .Accepted: return 202
                
            case .MovedPermanently: return 301
                
            case .BadRequest: return 400
            case .Unauthorized: return 401
            case .Forbidden: return 403
            case .NotFound: return 404
                
            case .Error: return 500
                
            case .Unknown: return 0
            case .Custom(let code):
                return code
            }
        }
    }
    
    // MARK: Properties

    public let status: Status
    public let data: [UInt8]
    public let contentType: ContentType
    public internal(set) var cookies: [String: String] = [:]

    public var headers: [String: String] {
        var headers = ["Server" : "Vapor \(Server.VERSION)"]

        if !self.cookies.isEmpty {
            headers["Set-Cookie"] = self.cookies
                .map { key, val in
                    return "\(key)=\(val)"
                }
                .joinWithSeparator(";")
        }

        switch self.contentType {
        case .Json: 
            headers["Content-Type"] = "application/json"
        case .Html: 
            headers["Content-Type"] = "text/html"
        default:
            break
        }

        return headers
    }

    // MARK: Initializer
    
    /**
     Designated initializer for response
     
     - parameter status:      the status associated with the response
     - parameter data:        the data to include in the body of the return
     - parameter contentType: the content type associated with the data
     */
    public init<ByteSequence: SequenceType where ByteSequence.Generator.Element == UInt8>(status: Status, data: ByteSequence, contentType: ContentType) {
        self.status = status
        self.data = [UInt8](data)
        self.contentType = contentType
    }

    /**
     Convenience error initializer
     
     - parameter error: a human readable description of the error
     */
    public convenience init(error: String) {
        let text = "{\n\t\"error\": true,\n\t\"message\":\"\(error)\"\n}"
        self.init(status: .Error, data: text.utf8, contentType: .Json)
    }

    /**
     Convenience initializer for html response
     
     - parameter status: server status
     - parameter html:   html string to return
     */
    public convenience init(status: Status, html: String) {
        let serialised = "<html><meta charset=\"UTF-8\"><body>\(html)</body></html>"
        self.init(status: status, data: serialised.utf8, contentType: .Html)
    }

    /**
     Convenience initializer for text response
     
     - parameter status: server status
     - parameter text:   text to include in the return
     */
    public convenience init(status: Status, text: String) {
        self.init(status: status, data: text.utf8, contentType: .Text)
    }

    /**
     Convenience initializer for basic Json objects.  Vapor will attempt to
     serialize the passed object, but for more complex Json, use the 
     included `Json` type
     
     - parameter status: server status
     - parameter json:   json object to attempt serialization
     
     - throws: SerializationError
     */
    public convenience init(status: Status, json: Any) throws {
        let data: [UInt8]

        if let jsonObject = json as? AnyObject {
            guard NSJSONSerialization.isValidJSONObject(jsonObject) else {
                throw SerializationError.InvalidObject
            }

            let json = try NSJSONSerialization.dataWithJSONObject(jsonObject, options: NSJSONWritingOptions.PrettyPrinted)
            data = Array(UnsafeBufferPointer(start: UnsafePointer<UInt8>(json.bytes), count: json.length))
        } else {
            //fall back to manual serializer
            let string = JSONSerializer.serialize(json)
            data = [UInt8](string.utf8)
        }
       

        self.init(status: status, data: data, contentType: .Json)
    }
}

// MARK: Response Equatable

extension Response: Equatable {}

public func ==(left: Response, right: Response) -> Bool {
    return left.status.code == right.status.code
}

// MARK: Status Printing

extension Response.Status: CustomStringConvertible {
    public var description: String {
        switch self {
        case .OK:
            return "OK"
        case .Created:
            return "Created"
        case .Accepted:
            return "Accepted"
            
        case .MovedPermanently:
            return "Moved Permanently"
            
        case .BadRequest:
            return "Bad Request"
        case .Unauthorized:
            return "Unauthorized"
        case .Forbidden:
            return "Forbidden"
        case .NotFound:
            return "Not Found"
            
        case .Error:
            return "Internal Server Error"
            
        case .Unknown:
            return "Unknown"
        case let .Custom(code):
            return "Custom: \(code)"
        }
    }
}
