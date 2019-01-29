//
//  Endpoint.swift
//  Tentacles
//
//  Created by Mike Leavy on 3/30/18.
//  Copyright © 2018 Squid Store. All rights reserved.
//

import Foundation

/**
 The completion callback for an `Endpoint` network request.
 
 - Parameter result: a `Result` object containing the success or failure result for the network request
 */
public typealias EndpointCompletion = (_ result: Result) -> Void

/**
 A progress callback for an `Endpoint` network request. Note: this callback is only used in a `download` request.
 
 - Parameter bytesWritten: the number of bytes transferred since the last time this callback was executed
 - Parameter totalBytesWritten: the total number of bytes transferred so far
 - Parameter totalBytesExpectedToWrite: the expected length of the requested resource, as provided by the Content-Length header. If this header was not provided, the value is NSURLSessionTransferSizeUnknown
 - Parameter percentComplete: the percent complete for this resource download request; will be nil if totalBytesExpectedToWrite == NSURLSessionTransferSizeUnknown
 */
public typealias EndpointProgress = (_ bytesWritten: Int64, _ totalBytesWritten: Int64, _ totalBytesExpectedToWrite: Int64, _ percentComplete: Double?) -> Void

open class Endpoint: Equatable {
    
    public static func == (lhs: Endpoint, rhs: Endpoint) -> Bool {
        return lhs.task == rhs.task
    }
    
    /**
     The `Task` structure is returned by the various `Endpoint` requests. It describes
     and identifies the request once it has been evaluated.
     */
    public struct Task: Equatable {
        
        public static func == (lhs: Task, rhs: Task) -> Bool {
            return lhs.identifier == rhs.identifier && lhs.urlRequest == rhs.urlRequest
        }
        
        /**
         The types of responses expected for this task.
         
         - network: Response will come from the network; however, the network may not be available
         - system:  Response provenance is up to the system, depenidng on cache availability and caching policy
         - cached:  Response is coming from cache
         - mock:    Response is coming from client-provided mock data
         - invalid: The request is invalid
         */
        public enum TaskResponseType: CustomStringConvertible {
            case network
            case system
            case cached
            case mock
            case invalid
            
            public var description: String {
                switch self {
                case .network:
                    return "network"
                case .system:
                    return "system"
                case .cached:
                    return "cached"
                case .mock:
                    return "mock"
                case .invalid:
                    return "invalid"
                }
            }
        }
        
        /// A unique integer that identifies the Task. Will be nil for response types other than `.network`
        public let identifier: Int?
        /// The `URLRequest` that the `Endpoint` uses to access the specified network resource
        public let urlRequest: URLRequest?
        /// The `TaskResponseType` for the `Endpoint` request
        public let taskResponseType: TaskResponseType
        
        
        fileprivate static let invalid = Task(.invalid)
        
        internal init(_ identifier: Int?, urlRequest: URLRequest, taskResponseType: TaskResponseType) {
            self.identifier = identifier
            self.urlRequest = urlRequest
            self.taskResponseType = taskResponseType
        }
        
        private init(_ taskResponseType: TaskResponseType) {
            self.identifier = nil
            self.urlRequest = nil
            self.taskResponseType = taskResponseType
        }
    }
    
    //MARK: - Request Types
    
    /**
     The type of the HTTP request that the `Endpoint` will issue.
     
     - get: HTTP GET
     - post: HTTP POST
     - put: HTTP PUT
     - patch: HTTP PATCH
     - delete: HTTP DELETE
     */
    public enum RequestType: String {
        case get = "GET", post = "POST", put = "PUT", patch = "PATCH", delete = "DELETE"
        
        /// Is the response for the given requst type cachable. Currently, only `get` responses
        /// can be cached.
        public var isCachable: Bool {
            return self == .get
        }
    }
    
    //MARK: - Parameter Types
    
    /**
     The parameter type for any given parameters for an `Endpoint` request.
     
     - none: no parameter type
     - json: parameters are in the form of a JSON array or dictionary
     - formURLEncoded: parameters are encoded as `application/x-www-form-urlencoded`
     - custom: an application defined parameter type; The `String` parameter, if non-nil,
     will be used for the HTTP header's `Content-Type` value.
     */
    public enum ParameterType {
        case none
        case json
        case formURLEncoded
        case custom(String?)
        
        var contentType: String? {
            switch self {
            case .none:
                return nil
            case .json:
                return "application/json"
            case .formURLEncoded:
                return "application/x-www-form-urlencoded"
            case .custom(let value):
                return value
            }
        }
    }
    
    //MARK: - Response Types
    
    /**
     The expected response type for an `Endpoint` request.
     
     - none: no response type
     - json: the request should return a JSON array or dictionary
     - data: request should return a Data object
     - image: requst should return a UIImage
     - custom: request should return an application-defined response, which confroms to the `ResponseMaking` protocol.
     The `String` parameter, if non-nil, will be used for the HTTP header's `Accept` value.
    */
    public enum ResponseType {
        case none
        case json
        case data
        case image
        case custom(String?, ResponseMaking)
        
        var accept: String? {
            switch self {
            case .json:
                return "application/json"
            case .custom(let value, _):
                return value
            default:
                return nil
            }
        }
    }
    
    //MARK: - Status Code Types
    
    /**
     The type of the HTTP status code returned by the `Endpoint` request.
     
     - informational: an informational status (HTTP status code range 100-199)
     - successful: a successful status (HTTP status code range 200-299)
     - redirect: a redirect status (HTTP status code range 300-399)
     - clientError: a client error occurred status (HTTP status code range 400-499)
     - serverError: a server error occurred status (HTTP status code range 500-599)
     - canceled: the HTTP request was cancelled
     - unknown: a status code that cannot be categorized
     */
    public enum StatusCodeType {
        case informational, successful, redirect, clientError, serverError, canceled, unknown
    }
    
    //MARK: - Cache Use Policy
    
    /**
     Specifies how Endpoint should handle any caching behavior attached to the Session instance.
     
     - normal: Use whatever cache policy is in use for the Session. This is the default.
     - ignore: Ignore caching; this is useful for forcing a network request
     when otherwise you want caching behavior to be in effect. For example,
     pull-to-refresh might set the policy to .ignore, then set it back to .normal
     when the network request completes.
     Please note that even if the policy is .ignore, successful responses will
     still be cached according to the Session's caching policy.
     */
    public enum CacheUsePolicy {
        case normal
        case ignore
    }
    
    //MARK: - Public Instance Members
    
    /// The Session instance that this Endpoint will use. Read-only.
    public let session: Session
    /// The Endpoint's cache use policy.
    public var cacheUsePolicy: CacheUsePolicy = .normal
    /// Client-supplied data, Tentacles itself does nothing but persist this
    public var userData: Any?
    /// Client-supplied string, Tentacles itself does nothing but persist this
    public var userDescription: String?
    /// Is this endpoint executing a download task
    public var isDownload: Bool {
        return progressHandler != nil
    }
    private(set) public var task: Task?
    
    //MARK: - Private/Internal Instance Members
    private var cache: TentaclesCaching?
    private var cachedTimestamp: Date?
    private var responseType = ResponseType.json
    private var data: Data?
    private var mockData: Data?
    private var mockHTTPStatusCode: Int?
    
    //MARK: - Callbacks
    private var completionHandler: EndpointCompletion?
    private var progressHandler: EndpointProgress?
    
    //MARK: - Initializers
    
    /**
     Initialize an Endpoint object.
     
     - Parameter session:   The `Session` object that this `Endpoint` will be associated with.
     */
    public init(session: Session) {
        self.session = session
    }
    
    /// Initialize an Endpoint object, which will be associated with the `shared` `Session` instance.
    public init() {
        self.session = Session.shared
    }
    
    deinit {
        Tentacles.shared.log("deleting endpoint", level: .info)
    }
    
    //MARK: - Convenience Setters
    @discardableResult
    open func with(_ description: String?) -> Self {
        userDescription = description
        return self
    }
    
    @discardableResult
    open func with(_ data: Any?) -> Self {
        userData = data
        return self
    }
    
    //MARK: - Mock
    /**
     Provide mock data in the form of a JSON string that will be returned
     by the next request (the actual server request will not be issued).
     The mock data will be discarded after the next request
     completes.
     
     - Parameter jsonString:    The JSON data as a `String` object.
    */
    @discardableResult
    open func mock(jsonString: String) -> Self {
        mockData = jsonString.data(using: .utf8)
        return self
    }
    
    /**
     Provide mock data in the form of a `Data` object will be returned
     by the next request (the actual server request will not be issued).
     The mock data will be discarded after the next request
     completes.
     
     - Parameter data:    The data that should be returned by the next request.
     */
    @discardableResult
    open func mock(data: Data?) -> Self {
        mockData = data
        return self
    }
    
    /**
     Provide mock data in the form of a JSON file at the specified path,
     the mock data will be returned by the next request (the actual server
     request will not be issued). The mock data will be discarded after the next request
     completes.
     
     - Parameter jsonFileAtPath:    The path to the JSON file.
     */
    @discardableResult
    open func mock(jsonFileAtPath: String) -> Self {
        guard let inputStream = InputStream(fileAtPath: jsonFileAtPath) else {return self}
        inputStream.open()
        
        defer {
            inputStream.close()
        }
        
        guard let jsonObject = try? JSONSerialization.jsonObject(with: inputStream, options: []) else {return self}
        
        
        mockData = try? JSONSerialization.data(withJSONObject: jsonObject, options: [])
        return self
    }
    
    /**
     Provide a mock HTTP status code that will be returned
     by the next request (the actual server request will not be issued).
     The mock HTTP status code will be discarded after the next request
     completes.
     
     - Parameter httpStatuscode:    The `Int` value of the HTTP status that should be returned by the next request.
     */
    @discardableResult
    open func mock(httpStatuscode: Int) -> Self {
        mockHTTPStatusCode = httpStatuscode
        return self
    }
    
    //MARK: - Helpers
    open func url(for path: String) -> URL? {
        return session.composedURL(path)
    }
    
    //MARK: - GET
    @discardableResult
    open func get(_ path: String, completion: @escaping EndpointCompletion) -> Self {
        return dataRequest(path, requestType: .get, responseType: .json, parameterType: .none, parameters: nil, completion: completion)
    }
    
    @discardableResult
    open func get(_ path: String, parameters: Any?, completion: @escaping EndpointCompletion) -> Self {
        let parameterType: ParameterType = parameters != nil ? .formURLEncoded : .none
        return dataRequest(path, requestType: .get, responseType: .json, parameterType: parameterType, parameters: parameters, completion: completion)
    }
    
    @discardableResult
    open func get(_ path: String, parameters: Any?, responseType: ResponseType, completion: @escaping EndpointCompletion) -> Self {
        let parameterType: ParameterType = parameters != nil ? .formURLEncoded : .none
        return dataRequest(path, requestType: .get, responseType: responseType, parameterType: parameterType, parameters: parameters, completion: completion)
    }
    
    //MARK: - POST
    @discardableResult
    open func post(_ path: String, parameterType: ParameterType, parameters: Any?, completion: @escaping EndpointCompletion) -> Self {
        return dataRequest(path, requestType: .post, responseType: .json, parameterType: parameterType, parameters: parameters, completion: completion)
    }
    
    @discardableResult
    open func post(_ path: String, parameterType: ParameterType, parameters: Any?, responseType: ResponseType, completion: @escaping EndpointCompletion) -> Self {
        return dataRequest(path, requestType: .post, responseType: responseType, parameterType: parameterType, parameters: parameters, completion: completion)
    }
    
    //MARK: - PUT
    @discardableResult
    open func put(_ path: String, parameterType: ParameterType, parameters: Any?, completion: @escaping EndpointCompletion) -> Self {
        return dataRequest(path, requestType: .put, responseType: .json, parameterType: parameterType, parameters: parameters, completion: completion)
    }
    
    //MARK: - PATCH
    @discardableResult
    open func patch(_ path: String, parameterType: ParameterType, parameters: Any?, completion: @escaping EndpointCompletion) -> Self {
        return dataRequest(path, requestType: .patch, responseType: .json, parameterType: parameterType, parameters: parameters, completion: completion)
    }
    
    //MARK: - DELETE
    @discardableResult
    open func delete(_ path: String, completion: @escaping EndpointCompletion) -> Self {
        return dataRequest(path, requestType: .delete, responseType: .json, parameterType: .none, parameters: nil, completion: completion)
    }
    
    @discardableResult
    open func delete(_ path: String, parameters: Any?, completion: @escaping EndpointCompletion) -> Self {
        let parameterType: ParameterType = parameters != nil ? .formURLEncoded : .none
        return dataRequest(path, requestType: .delete, responseType: .json, parameterType: parameterType, parameters: parameters, completion: completion)
    }
    
    @discardableResult
    open func delete(_ path: String, parameters: Any?, responseType: ResponseType, completion: @escaping EndpointCompletion) -> Self {
        let parameterType: ParameterType = parameters != nil ? .formURLEncoded : .none
        return dataRequest(path, requestType: .delete, responseType: responseType, parameterType: parameterType, parameters: parameters, completion: completion)
    }
    
    //MARK: - Download
    @discardableResult
    open func download(_ path: String, parameters: Any?, progress: @escaping EndpointProgress, completion: @escaping EndpointCompletion) -> Self {
        let parameterType: ParameterType = parameters != nil ? .formURLEncoded : .none
        progressHandler = progress
        return dataRequest(path, requestType: .get, responseType: .data, parameterType: parameterType, parameters: parameters, completion: completion)
    }
    
    //MARK: - Cancel
    open func cancel() {
        guard let identifier = task else {return}
        session.cancel(identifier)
    }
    
    public func dataRequest(_ path: String, requestType: RequestType, responseType: ResponseType, parameterType: ParameterType, parameters: Any?, completion: @escaping EndpointCompletion) -> Self {
        self.responseType = responseType
        guard let url = session.composedURL(path) else {
            completion(Result(data: nil, urlResponse: HTTPURLResponse(), error: session.urlError(), responseType: responseType))
            task = .invalid
            return self
        }
        
        return dataRequest(requestType: requestType, url: url, parameterType: parameterType, parameters: parameters, completion: completion)
    }
    
    private func reset() {
        data = nil
        completionHandler = nil
        task = nil
        cache = nil
        cachedTimestamp = nil
    }
    
    private func dataRequest(requestType: RequestType, url: URL, parameterType: ParameterType, parameters: Any?, completion: @escaping EndpointCompletion) -> Self {
        
        reset()
        
        completionHandler = completion
        
        // check for cached
        if let cachingStore = session.cachingStore {
            switch cachingStore {
            case .client(let caching):
                cache = caching
            case .tentaclesEphemeral:
                cache = TentaclesEphemeralCache.shared
            case .tentaclesPersistant:
                cache = TentaclesPersistantCache.shared
            default:
                break
            }
        }
        
        do {
            let request = try URLRequest(url: url, cachePolicy: URLRequest.CachePolicy.useProtocolCachePolicy, timeoutInterval: session.timeout, requestType: requestType, parameterType: parameterType, responseType: responseType, parameters: parameters, session: session)
            
            //MARK: - Check for mocked data
            if let mocked = mockData {
                let httpResponse = HTTPURLResponse(url: url, statusCode: mockHTTPStatusCode ?? 200, httpVersion: nil, headerFields: nil)!
                handleCompletion(data: mocked, urlResponse: httpResponse, error: nil, responseType: responseType)
                task = Task(nil, urlRequest: request, taskResponseType: .mock)
                mockData = nil
                mockHTTPStatusCode = nil
                return self
            }
            
            //MARK: - Check for mocked status
            if let mockedStatus = mockHTTPStatusCode {
                let httpResponse = HTTPURLResponse(url: url, statusCode: mockedStatus, httpVersion: nil, headerFields: nil)!
                handleCompletion(data: nil, urlResponse: httpResponse, error: nil, responseType: responseType)
                task = Task(nil, urlRequest: request, taskResponseType: .mock)
                mockHTTPStatusCode = nil
                return self
            }
            
            //MARK: - Check for cached
            if let cache = cache, requestType.isCachable, cacheUsePolicy == .normal {
                let (cached, timestamp) = CachedResponse.cached(from: cache, request: request)
                cachedTimestamp = timestamp
                if let cached = cached {
                    let httpResponse = HTTPURLResponse(url: url, statusCode: cached.httpStatusCode, httpVersion: nil, headerFields: nil)!
                    handleCompletion(data: cached.data, urlResponse: httpResponse, error: nil, responseType: responseType)
                    task = Task(nil, urlRequest: request, taskResponseType: .cached)
                    return self
                }
            }
            
            Tentacles.shared.log(request.debugDescription, level: .request)
            
            session.endpoints.append(self)
            var dataTask: URLSessionTask?
            if isDownload {
                dataTask = session.urlSession.downloadTask(with: request)
            }
            else {
                dataTask = session.urlSession.dataTask(with: request)
            }
            
            
            let uuid = UUID().uuidString
            dataTask?.taskDescription = uuid
            dataTask?.resume()
            DispatchQueue.main.async {
                self.session.requestStartedAction?(self)
            }
            
            task = Task(dataTask?.taskIdentifier, urlRequest: request, taskResponseType: session.urlCache == nil ? .network : .system)
            return self
        }
        catch {
            let response = HTTPURLResponse(url: url, statusCode: (error as NSError).code, httpVersion: nil, headerFields: nil) ?? HTTPURLResponse()
            handleCompletion(data: nil, urlResponse: response, error: error, responseType: responseType)
            task = .invalid
            return self
        }
        
    }
    
    internal func progress(bytesWritten: Int64, totalBytesWritten: Int64, totalBytesExpectedToWrite: Int64, percentComplete: Double?) {
        DispatchQueue.main.async {
            self.progressHandler?(bytesWritten, totalBytesWritten, totalBytesExpectedToWrite, percentComplete)
        }
    }
    
    internal func completed(task: URLSessionTask, error: Error?) {
        
        progressHandler = nil
        
        DispatchQueue.main.async {
            self.session.requestCompletedAction?(self)
        }
        
        var connectionError = error
        var canceled = false
        
        if let httpResponse = task.response as? HTTPURLResponse, httpResponse.statusCode.statusCodeType != .successful {
            var errorCode = httpResponse.statusCode
            if let error = error as NSError?, error.code == URLError.cancelled.rawValue {
                errorCode = error.code
                canceled = true
            }
            connectionError = NSError.tentaclesError(code: errorCode, localizedDescription: HTTPURLResponse.localizedString(forStatusCode: httpResponse.statusCode))
        }
        
        if let unauthorizedRequestCallback = session.unauthorizedRequestCallback, let error = connectionError as NSError?, error.code.isUnauthorizedStatus {
            unauthorizedRequestCallback()
        }
        
        var completionHandled = false
        if let httpResponse = task.response as? HTTPURLResponse,
            (httpResponse.statusCode.statusCodeType != .successful &&
                httpResponse.statusCode.statusCodeType != .canceled &&
                httpResponse.statusCode.statusCodeType != .informational &&
                httpResponse.statusCode.statusCodeType != .redirect &&
                !canceled &&
                cacheUsePolicy == .normal),
            let originalRequest = task.originalRequest,
            let url = originalRequest.url {
            if let cache = cache, let _ = cachedTimestamp {
                let (cached, _) = CachedResponse.cached(from: cache, request: originalRequest, requestDidFail: true)
                if let cached = cached {
                    let httpResponse = HTTPURLResponse(url: url, statusCode: cached.httpStatusCode, httpVersion: nil, headerFields: nil)!
                    handleCompletion(data: cached.data, urlResponse: httpResponse, error: nil, responseType: responseType)
                    completionHandled = true
                }
            }
        }
        
        if !completionHandled {
            handleCompletion(data: data, urlResponse: task.response ?? URLResponse(), error: connectionError, responseType: responseType)
        }
        
        if let cache = cache, let timestamp = cachedTimestamp, let originalRequest = task.originalRequest, cacheUsePolicy != .ignore {
            CachedResponse.remove(from: cache, request: originalRequest, cachedTimestamp: timestamp)
        }
        
        guard let data = data, connectionError == nil else {return}
        
        if let cache = cache, let httpResponse = task.response as? HTTPURLResponse, let request = task.originalRequest, let httpMethod = request.httpMethod, let requestType = RequestType(rawValue: httpMethod), requestType.isCachable {
            if connectionError == nil {
                let dataToCache = CachedResponse(code: httpResponse.statusCode, object: data, timestamp: Date())
                cache.cache(data: dataToCache, request: request)
            }
        }
    }
    
    private func handleCompletion(data: Data?, urlResponse: URLResponse, error: Error?, responseType: ResponseType) {
        DispatchQueue.main.async {
            self.completionHandler?(Result(data: data, urlResponse: urlResponse, error: error, responseType: responseType))
        }
    }
    
    internal func didReceiveData(receivedData: Data) {
        if data == nil {
            data = receivedData
        }
        else {
            data?.append(receivedData)
        }
    }
    
}


extension CharacterSet {
    static var urlQueryParametersAllowed: CharacterSet {
        /// Does not include "?" or "/" due to RFC 3986 - Section 3.4
        let generalDelimitersToEncode = ":#[]@"
        let subDelimitersToEncode = "!$&'()*+,;="
        
        var allowedCharacterSet = CharacterSet.urlQueryAllowed
        allowedCharacterSet.remove(charactersIn: "\(generalDelimitersToEncode)\(subDelimitersToEncode)")
        
        return allowedCharacterSet
    }
}


public extension Dictionary where Key: ExpressibleByStringLiteral {
    
    public func urlEncodedString() throws -> String {
        
        let pairs = try reduce([]) { current, keyValuePair -> [String] in
            if let encodedValue = "\(keyValuePair.value)".addingPercentEncoding(withAllowedCharacters: .urlQueryParametersAllowed) {
                return current + ["\(keyValuePair.key)=\(encodedValue)"]
            }
            else {
                throw NSError.tentaclesError(code: TentaclesErrorCode.serializationError.rawValue, localizedDescription: "Couldn't encode \(keyValuePair.value)")
            }
        }
        
        let converted = pairs.joined(separator: "&")
        
        return converted
    }
}

public extension Int {
    var statusCodeType: Endpoint.StatusCodeType {
        switch self {
        case URLError.cancelled.rawValue:
            return .canceled
        case 100 ..< 200:
            return .informational
        case 200 ..< 300:
            return .successful
        case 300 ..< 400:
            return .redirect
        case 400 ..< 500:
            return .clientError
        case 500 ..< 600:
            return .serverError
        default:
            return .unknown
        }
    }
    
    var isUnauthorizedStatus: Bool {
        return self == 401 || self == 403
    }
}




