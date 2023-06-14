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
 The  callback allowing a client to create it's onw key-value pair during the parameter encoding process.
 
 - Parameter key: the key value that should be encoded
 - Parameter value: the value that should be encoded
 - Returns an array of strings that are fully qualified key-value pair query parameters (e.g. "myKey=myValue")
 */
public typealias CustomParameterEncoder = (_ key: String, _ value: Any) -> [String]?

/**
 A progress callback for an `Endpoint` network request. Note: this callback is only used in a `download` request.
 
 - Parameter bytesWritten: the number of bytes transferred since the last time this callback was executed
 - Parameter totalBytesWritten: the total number of bytes transferred so far
 - Parameter totalBytesExpectedToWrite: the expected length of the requested resource, as provided by the Content-Length header. If this header was not provided, the value is NSURLSessionTransferSizeUnknown
 - Parameter percentComplete: the percent complete for this resource download request; will be nil if totalBytesExpectedToWrite == NSURLSessionTransferSizeUnknown
 */
public typealias EndpointProgress = (_ bytesWritten: Int64, _ totalBytesWritten: Int64, _ totalBytesExpectedToWrite: Int64, _ percentComplete: Double?) -> Void

open class Endpoint: Equatable, Hashable {
    
    public static func == (lhs: Endpoint, rhs: Endpoint) -> Bool {
        return lhs.task == rhs.task
    }
    
    public func hash(into hasher: inout Hasher) {
        hasher.combine(task?.identifier)
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
        public enum TaskResponseType: String, CustomStringConvertible {
            case network
            case system
            case cached
            case mock
            case invalid
            case disabled
            case throttled
            case simulatedOffline
            
            public var description: String {
                return self.rawValue
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
    public enum RequestType: String, CaseIterable {
        case get = "GET", post = "POST", put = "PUT", patch = "PATCH", delete = "DELETE"
        
        /// Is the response for the given requst type cachable. Currently, only `get` responses
        /// can be cached.
        public var isCachable: Bool {
            return self == .get
        }
        
        /// Does (or can) the request perform write transactions.
        public var isWrite: Bool {
            switch self {
            case .get:
                return false
            case .post, .put, .patch, .delete:
                return true
            }
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
     - customKeys an application defined parameter type that allows for application processing of particular key-value pairs in
        a given request.
        The `String` parameter, if non-nil, will be used for the HTTP header's `Content-Type` value.
        The `[String]` parameter is the array of keys for which  the client wants to handle key-value encoding.
        The `CustomParameterEncoder` parameter is the callback for client key-value encoding.
     */
    public enum ParameterType: CustomStringConvertible {
        case none
        case json
        case formURLEncoded
        case custom(String?)
        case customKeys(String?, [String], CustomParameterEncoder)
        
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
            case .customKeys(let value, _, _):
                return value
            }
        }
        
        public var description: String {
            switch self {
            case .none:
                return "none"
            case .json:
                return "json"
            case .formURLEncoded:
                return "formURLEncoded"
            case .custom(let s):
                return "Custom: \(s ?? "")"
            case .customKeys(let s, _, _):
                return "Custom Keys: \(s ?? "")"
            }
        }
    }
    
    
    /**
     Specifies how to handle parameter values that are arrays _when used as query parameters_.
     Note that only types conforming to `CustomStringConvertable`
     are handled as array values when specifying a `list` or `repeat` behavior; any other array types will
     encoded using default behavior..
     
     - default: do nothing (existing behavior)
     - list: the array will be expanded into a list of values, with each element seperated by the delimater value given in the `String` parameter
     - repeat: the array will be expanded into repeated key-value pairs (e.g. myKey=1&myKey=2&myKey=3)
     */
    public enum ParameterArrayBehavior: Hashable {
        case `default`
        case list(String)
        case `repeat`
    }
    
    /**
     A dictionary of key-values wheren the key is a `ParameterArrayBehavior` and the value
     is an array of keys for which that behavior applies.
        
     Examples:
        [.list(","): ["items"]]   - this will apply the list behavior - using a comma as the delimiter - to the
            parameter named "items".
        [.repeat: []] - this will apply the repeat behavior to all query parameters whose type is an array
        [.repeat: [], .list(","): ["items"]] - this will apply the repeat behavior to all query parameters whose type is an array EXCEPT
            for the parameter whose key is "items", for which it will apply the list behavior
     */
    public typealias ParameterArrayBehaviors = [ParameterArrayBehavior: [String]]
    
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
        case optionalJson
        case data
        case image
        case custom(String?, ResponseMaking)
        
        public var accept: String? {
            switch self {
            case .json, .optionalJson:
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
    /// the parameter array behaviors for this endpoint
    public var parameterArrayBehaviors: ParameterArrayBehaviors = [:]
    private(set) public var task: Task?
    
    /// Throttling
    public var throttle: Throttle?
    
    //MARK: - Private/Internal Instance Members
    private var cache: TentaclesCaching?
    private var cachedTimestamp: Date?
    private var responseType = ResponseType.json
    private var data: Data?
    private var mockData: Data?
    private var mockHTTPStatusCode: Int?
    private var mockHTTPResponseHeaders: [String: String]?
    private var mockPaginationHeaderKeys: [String]?
    internal var requestDescription: String?
    
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
    
    /**
    Provide mock HTTP response headers that will be returned
    by the next mocked request (if there are no pending mock requests, these header values are ignored).
    The mocked headers will be used for any mocked results from this endpoint until/unless
    the client sends nil for headers.
    
    - Parameter headers:    The header dictionary that should be returned by subsequent mock requests.
    */
    @discardableResult
    open func mock(headers: [String: String]?) -> Self {
        mockHTTPResponseHeaders = headers
        return self
    }
    
    /**
    Given mocked headers are provided in the method above, the client can set the key values
    for pagination data elements in the headers. Tentacles will auto-increment these key values
    (assuming they can be represented as integers) before each mock request/response session. This
    means that the inital values of these header keys should be 1 less than the expected initial value
    after one request/response session
    
    - Parameter paginationHeaderKeys:    The header keys that should be auto-incremented by subsequent mock requests.
    */
    @discardableResult
    open func mock(paginationHeaderKeys: [String]?) -> Self {
        mockPaginationHeaderKeys = paginationHeaderKeys
        return self
    }
    
    //MARK: - Helpers
    open func url(for path: String) -> URL? {
        return session.composedURL(path)
    }
    
    //MARK: - Throttling
    public func throttle(_ throttle: Throttle) -> Self {
        self.throttle = throttle
        return self
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
    open func get(_ path: String, parameterType: ParameterType, parameters: Any?, completion: @escaping EndpointCompletion) -> Self {
        return dataRequest(path, requestType: .get, responseType: .json, parameterType: parameterType, parameters: parameters, completion: completion)
    }
    
    @discardableResult
    open func get(_ path: String, parameterType: ParameterType, parameterArrayBehaviors: ParameterArrayBehaviors?, parameters: Any?, completion: @escaping EndpointCompletion) -> Self {
        return dataRequest(path, requestType: .get, responseType: .json, parameterType: parameterType, parameterArrayBehaviors: parameterArrayBehaviors, parameters: parameters, completion: completion)
    }
    
    @discardableResult
    open func get(_ path: String, parameters: Any?, responseType: ResponseType, completion: @escaping EndpointCompletion) -> Self {
        let parameterType: ParameterType = parameters != nil ? .formURLEncoded : .none
        return dataRequest(path, requestType: .get, responseType: responseType, parameterType: parameterType, parameters: parameters, completion: completion)
    }
    
    @discardableResult
    open func get(_ path: String, parameterType: ParameterType, parameters: Any?, responseType: ResponseType, completion: @escaping EndpointCompletion) -> Self {
        return dataRequest(path, requestType: .get, responseType: responseType, parameterType: parameterType, parameters: parameters, completion: completion)
    }
    
    /**
     This request will only go as far as checking for, and returning if found, the cached
     response for this request. No network transaction takes place, and no mocked data will be
     returned.
     
     - Parameter path:          The path for the request.
     - Parameter parameters:    The URL parameters for the request, or nil.
     - Parameter responseType:  The type of response expected.
     - Parameter completion:    The completion handler to call once the request is completed.
     */
    @discardableResult
    open func getCached(_ path: String, parameters: Any?, responseType: ResponseType, completion: @escaping EndpointCompletion) -> Self {
        let parameterType: ParameterType = parameters != nil ? .formURLEncoded : .none
        return dataRequest(path, requestType: .get, responseType: responseType, parameterType: parameterType, parameters: parameters, completion: completion, cachedOnly: true)
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
    
    @discardableResult
    open func patch(_ path: String, parameterType: ParameterType, parameters: Any?, responseType: ResponseType, completion: @escaping EndpointCompletion) -> Self {
        return dataRequest(path, requestType: .patch, responseType: responseType, parameterType: parameterType, parameters: parameters, completion: completion)
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
    open func delete(_ path: String, parameterType: ParameterType, parameters: Any?, completion: @escaping EndpointCompletion) -> Self {
        return dataRequest(path, requestType: .delete, responseType: .json, parameterType: parameterType, parameters: parameters, completion: completion)
    }
    
    @discardableResult
    open func delete(_ path: String, parameters: Any?, responseType: ResponseType, completion: @escaping EndpointCompletion) -> Self {
        let parameterType: ParameterType = parameters != nil ? .formURLEncoded : .none
        return dataRequest(path, requestType: .delete, responseType: responseType, parameterType: parameterType, parameters: parameters, completion: completion)
    }
    
    @discardableResult
    open func delete(_ path: String, parameterType: ParameterType, parameters: Any?, responseType: ResponseType, completion: @escaping EndpointCompletion) -> Self {
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
    
    //MARK: - Data request
    public func dataRequest(_ path: String,
                            requestType: RequestType,
                            responseType: ResponseType,
                            parameterType: ParameterType,
                            parameterArrayBehaviors: ParameterArrayBehaviors? = nil,
                            parameters: Any?,
                            completion: @escaping EndpointCompletion, cachedOnly: Bool = false) -> Self {
        
        
        if let precondition = session.precondition, precondition.requiresPrecondition(path: path) {
            precondition.waitForPrecondition { [weak self] success in
                if success {
                    if let self {
                        let _ = self.prepareDataTask(
                            path,
                            requestType: requestType,
                            responseType: responseType,
                            parameterType: parameterType,
                            parameterArrayBehaviors: parameterArrayBehaviors,
                            parameters: parameters,
                            completion: completion)
                    }
                }
            }
            return self
        }
        else {
            return self.prepareDataTask(
                path,
                requestType: requestType,
                responseType: responseType,
                parameterType: parameterType,
                parameterArrayBehaviors: parameterArrayBehaviors,
                parameters: parameters,
                completion: completion)
        }
    }
    
    private func prepareDataTask(_ path: String,
                                 requestType: RequestType,
                                 responseType: ResponseType,
                                 parameterType: ParameterType,
                                 parameterArrayBehaviors: ParameterArrayBehaviors?,
                                 parameters: Any?,
                                 completion: @escaping EndpointCompletion, cachedOnly: Bool = false) -> Self {
        session.updateSessionConfiguration()
        self.responseType = responseType
        guard let url = session.composedURL(path) else {
            completion(Result(data: nil, urlResponse: HTTPURLResponse(), error: session.urlError(), responseType: responseType, requestType: requestType, requestData: nil))
            task = .invalid
            return self
        }
        
        if let parameterArrayBehaviors = parameterArrayBehaviors {
            self.parameterArrayBehaviors = parameterArrayBehaviors
        }
        
        return dataRequest(requestType: requestType,
                           url: url,
                           parameterType: parameterType,
                           parameters: parameters,
                           completion: completion,
                           cachedOnly: cachedOnly)
    }
    
    //MARK: - Completion Previewing
    open func previewResult(result: Result) {
        
    }
    
    private func reset() {
        data = nil
        completionHandler = nil
        task = nil
        cache = nil
        cachedTimestamp = nil
        requestDescription = nil
    }
        
    private func dataRequest(requestType: RequestType,
                             url: URL,
                             parameterType: ParameterType,
                             parameters: Any?,
                             completion: @escaping EndpointCompletion, cachedOnly: Bool) -> Self {
        
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
            let request = try URLRequest(url: url,
                                         cachePolicy: URLRequest.CachePolicy.useProtocolCachePolicy,
                                         timeoutInterval: session.timeout,
                                         requestType: requestType,
                                         parameterType: parameterType,
                                         parameterArrayBehaviors: parameterArrayBehaviors,
                                         responseType: responseType,
                                         parameters: parameters,
                                         session: session)
            
            Tentacles.shared.internalLogger?.logRequest(request)
            
            // check for disabled
            if session.disabledRequestTypes.contains(requestType) {
                let httpResponse = HTTPURLResponse(url: url, statusCode: TentaclesErrorCode.requestTypeDisabledError.rawValue, httpVersion: nil, headerFields: nil)!
                handleCompletion(data: nil, urlResponse: httpResponse, error: NSError.tentaclesError(code: .requestTypeDisabledError, localizedDescription: "The \(requestType.rawValue) request type has been disabled by the client"), responseType: responseType, requestType: requestType)
                task = Task(nil, urlRequest: request, taskResponseType: .disabled)
                return self
            }
            
            // check for throttled
            if let throttle = throttle, let url = request.url, Throttler.shared.throttled(url: url, throttle: throttle) {
                let httpResponse = HTTPURLResponse(url: url, statusCode: TentaclesErrorCode.requestExceedsThrottleLimitError.rawValue, httpVersion: nil, headerFields: nil)!
                handleCompletion(data: nil, urlResponse: httpResponse, error: NSError.tentaclesError(code: .requestExceedsThrottleLimitError, localizedDescription: "The request exceeds the throttle limit set by the client"), responseType: responseType, requestType: requestType)
                task = Task(nil, urlRequest: request, taskResponseType: .throttled)
                return self
            }
            
            // check for simulated offline mode
            if Tentacles.shared.networkingMode == .simulatedOffline {
                let httpResponse = HTTPURLResponse(url: url, statusCode: TentaclesErrorCode.simulatedOfflineError.rawValue, httpVersion: nil, headerFields: nil)!
                handleCompletion(data: nil, urlResponse: httpResponse, error: NSError.tentaclesError(code: .simulatedOfflineError, localizedDescription: "The Internet connection appears to be offline."), responseType: responseType, requestType: requestType)
                task = Task(nil, urlRequest: request, taskResponseType: .simulatedOffline)
                return self
            }
            
            if !cachedOnly {
                //MARK: - Check for mocked data
                if let mocked = mockData {
                    if let mockedPageKeys = mockPaginationHeaderKeys, let mockedHeaders = mockHTTPResponseHeaders {
                        var updatedHeaders = mockedHeaders
                        for key in mockedPageKeys {
                            if let s = mockedHeaders[key], let i = Int(s) {
                                updatedHeaders[key] = String(i+1)
                            }
                        }
                        mockHTTPResponseHeaders = updatedHeaders
                    }
                    let httpResponse = HTTPURLResponse(url: url, statusCode: mockHTTPStatusCode ?? 200, httpVersion: nil, headerFields: mockHTTPResponseHeaders)!
                    handleCompletion(data: mocked, urlResponse: httpResponse, error: nil, responseType: responseType, requestType: requestType)
                    task = Task(nil, urlRequest: request, taskResponseType: .mock)
                    mockData = nil
                    mockHTTPStatusCode = nil
                    return self
                }
                
                //MARK: - Check for mocked status
                if let mockedStatus = mockHTTPStatusCode {
                    let httpResponse = HTTPURLResponse(url: url, statusCode: mockedStatus, httpVersion: nil, headerFields: mockHTTPResponseHeaders)!
                    handleCompletion(data: nil, urlResponse: httpResponse, error: nil, responseType: responseType, requestType: requestType)
                    task = Task(nil, urlRequest: request, taskResponseType: .mock)
                    mockHTTPStatusCode = nil
                    return self
                }
            }
            
            //MARK: - Check for cached
            if let cache = cache, requestType.isCachable, cacheUsePolicy == .normal {
                let (cached, timestamp) = CachedResponse.cached(from: cache, request: request)
                cachedTimestamp = timestamp
                if let cached = cached {
                    let httpResponse = HTTPURLResponse(url: url, statusCode: cached.httpStatusCode, httpVersion: nil, headerFields: nil)!
                    handleCompletion(data: cached.data, urlResponse: httpResponse, error: nil, responseType: responseType, requestType: requestType)
                    task = Task(nil, urlRequest: request, taskResponseType: .cached)
                    return self
                }
            }
            
            if cachedOnly {
                // if we got this far and are only looking for the cached response,
                // then we didn't find a cached response, so call completion and exit
                let httpResponse = HTTPURLResponse(url: url, statusCode: TentaclesErrorCode.cachedNotFoundError.rawValue, httpVersion: nil, headerFields: nil)!
                handleCompletion(data: nil, urlResponse: httpResponse, error: NSError.tentaclesError(code: .cachedNotFoundError, localizedDescription: "Requested cached response not found"), responseType: responseType, requestType: requestType)
                task = Task(nil, urlRequest: request, taskResponseType: .invalid)
                return self
            }
            
            appendToDescription(request: request, requestType: requestType, parameterType: parameterType, parameters: parameters)
            
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
            handleCompletion(data: nil, urlResponse: response, error: error, responseType: responseType, requestType: requestType)
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
            self.session.requestCompletedAction?(self, task.response)
        }
        
        var connectionError = error
        var canceled = false
        
        var requestType: RequestType?
        if let original = task.originalRequest, let method = original.httpMethod {
            requestType = RequestType(rawValue: method)
        }
        
        if let httpResponse = task.response as? HTTPURLResponse, httpResponse.statusCode.statusCodeType != .successful {
            var errorCode = httpResponse.statusCode
            if let error = error as NSError?, error.code == URLError.cancelled.rawValue {
                errorCode = error.code
                canceled = true
            }
            connectionError = NSError.tentaclesError(code: errorCode, localizedDescription: HTTPURLResponse.localizedString(forStatusCode: httpResponse.statusCode))
        }
        
        var shouldContinue = true
        if let unauthorizedRequestCallback = session.unauthorizedRequestCallback, let error = connectionError as NSError?, session.unauthorizedStatusCodes.contains(error.code) {
            shouldContinue = unauthorizedRequestCallback()
        }
        
        guard shouldContinue else {return}
        
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
                    handleCompletion(data: cached.data, urlResponse: httpResponse, error: nil, responseType: responseType, requestType: requestType, requestData: originalRequest.httpBody)
                    completionHandled = true
                }
            }
        }
        
        if !completionHandled {
            handleCompletion(data: data, urlResponse: task.response ?? URLResponse(), error: connectionError, responseType: responseType, requestType: requestType, requestData: task.originalRequest?.httpBody)
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
    
    private func handleCompletion(data: Data?,
                                  urlResponse: URLResponse,
                                  error: Error?,
                                  responseType: ResponseType,
                                  requestType: RequestType?,
                                  requestData: Data? = nil) {
        DispatchQueue.main.async {
            let result = Result(data: data,
                                urlResponse: urlResponse,
                                error: error,
                                responseType: responseType,
                                requestType: requestType,
                                requestData: requestData)
            self.appendToDescription(string: "\n\nResponse:\n\(result.debugDescription)")
            self.previewResult(result: result)
            self.completionHandler?(result)
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
    
    func urlEncodedString(customKeys: [String]?,
                          encodingCallback: CustomParameterEncoder?,
                          arrayBehaviors: Endpoint.ParameterArrayBehaviors) throws -> String {
        
        let pairs = try reduce([]) { current, keyValuePair -> [String] in
            if let custom = customKeys, let callback = encodingCallback, let key = keyValuePair.key as? String, custom.contains(key) {
                if let params = callback(key, keyValuePair.value) {
                    return current + params
                }
                else {
                    return current
                }
            }
            else {
                if let array = keyValuePair.value as? [CustomStringConvertible], let key = keyValuePair.key as? String {
                    switch arrayBehaviors.behavior(for: key) {
                    case .default:
                        break
                    case .list(let delimiter):
                        if let value = array.list(delimiter: delimiter).addingPercentEncoding(withAllowedCharacters: .urlQueryParametersAllowed) {
                            return current + ["\(keyValuePair.key)=\(value)"]
                        }
                    case .repeat:
                        var queries = [String]()
                        for element in array {
                            if let encodedValue = "\(element)".addingPercentEncoding(withAllowedCharacters: .urlQueryParametersAllowed) {
                                queries.append("\(keyValuePair.key)=\(encodedValue)")
                            }
                        }
                        return current + queries
                    }
                }
                if let encodedValue = "\(keyValuePair.value)".addingPercentEncoding(withAllowedCharacters: .urlQueryParametersAllowed) {
                    return current + ["\(keyValuePair.key)=\(encodedValue)"]
                }
                else {
                    throw NSError.tentaclesError(code: TentaclesErrorCode.serializationError.rawValue, localizedDescription: "Couldn't encode \(keyValuePair.value)")
                }
            }
        }
        
        let converted = pairs.joined(separator: "&")
        
        return converted
    }
}

public extension Array where Element: ExpressibleByStringLiteral {
    func urlEncodedString() -> String {
        let items = self.compactMap { (item) -> String? in
            return (item as? String)?.addingPercentEncoding(withAllowedCharacters: .urlQueryParametersAllowed)
        }
        
        let converted = items.joined(separator: ",")
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
}

private extension Array {
    func list(delimiter: String) -> String {
        var result = ""
        
        for element in self {
            result.append(String(describing: element), delimiter: delimiter)
        }
        
        return result
    }
}

private extension String {
    mutating func append(_ other: String, delimiter: String) {
        if self.count > 0 {
            self.append(delimiter)
        }
        self.append(other)
    }
}

private extension Endpoint.ParameterArrayBehaviors {
    func behavior(for key: String) -> Endpoint.ParameterArrayBehavior {
        for behaviorKey in self.keys {
            // look for any behaviorKey with values that contains given key
            if self[behaviorKey]?.contains(key) ?? false {
                return behaviorKey
            }
        }
        // if we didn't find a case where a behavior was explicitly handling
        // the given key, let the first empty set behavior handle it
        for behaviorKey in self.keys {
            if self[behaviorKey]?.isEmpty ?? false {
                return behaviorKey
            }
        }
        
        return .default
    }
}
