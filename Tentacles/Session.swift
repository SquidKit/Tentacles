//
//  Session.swift
//  Tentacles
//
//  Created by Mike Leavy on 3/28/18.
//  Copyright © 2018 Squid Store. All rights reserved.
//

import Foundation

extension Notification.Name {
    public static let tentaclesOrphanedSessionTask = Notification.Name("com.squidstore.tentacles.tentaclesOrphanedSessionTask")
}

/**
 A closure that will be called for every endpoint on this session when a network task begins.
 You might want to begin showing progress in this closure, for example.
 Note that this closure is not executed if the response is coming from an internal cache.
 
 - Parameter endpoint: the `Endpoint` object for which the network request is about to begin
 */
public typealias NetworkRequestBegunClosure = (_ endpoint: Endpoint) -> Void

/**
 A closure that will always be called for every endpoint on this session when a network task begins.
 You might want to stop showing progress in this closure, for example.
 
 Note that this closure is not executed if the response is coming from an internal cache.
 Otherwise, this closure is executed regardless of the success or failure of the request.
 
 - Parameter endpoint: the `Endpoint` object for which the network request has completed.
 */
public typealias NetworkRequestCompletedClosure = (_ endpoint: Endpoint, _ response: URLResponse?) -> Void

/**
 A closure that will always be called for every endpoint on this session when a network task is created.
 You may want to update header values or host name in this closure, for example.
 
 Note that this closure is not executed if the response is coming from an internal cache.
 
 - Returns an optional Session.SessionConfiguration object, any non-nil values in this object
 are used to set the corresponding value on the Session
 */
public typealias SessionConfigurationClosure = () -> Session.SessionConfiguration?

public typealias SessionPreconditionCompletion = (Bool) -> Void

public typealias SessionCancelationClosure = (Endpoint.Task?) -> Void

public typealias SessionChallengeHandler = (
    URLSession,
    URLSessionTask,
    URLAuthenticationChallenge) -> (URLSession.AuthChallengeDisposition, URLCredential?)
    

public protocol SessionPrecondition {
    func requiresPrecondition(path: String) -> Bool
    func waitForPrecondition(completion: @escaping SessionPreconditionCompletion)
}

open class Session: NSObject, URLSessionDelegate, URLSessionDataDelegate, URLSessionDownloadDelegate, URLSessionTaskDelegate {
    
    public static var shared = Session()
    
    //MARK: - URLSession
    open var urlSession: URLSession {
        if _urlSession == nil {
            _urlSession = URLSession(configuration: urlSessionConfiguration, delegate: self, delegateQueue: nil)
        }
        return _urlSession!
    }
    open var urlSessionConfiguration: URLSessionConfiguration!
    
    public var precondition: SessionPrecondition?
    public var challengeHandler: SessionChallengeHandler?
    
    //MARK: - URL
    open var host: String? {
        get {
            if let manager = environmentManager, let env = environment {
                return manager.host(for: env) ?? _host
            }
            return _host
        }
        set {
            _host = newValue
        }
    }
    open var scheme: String {
        get {
            if let manager = environmentManager, let env = environment {
                return manager.scheme(for: env)
            }
            return _scheme
        }
        set {
            _scheme = newValue
        }
    }
    
    //MARK: - Authorization
    open var authorizationHeaderKey: String = "Authorization"
    open var authorizationHeaderValue: String?
    open var authorizationBearerToken: String?
    open var unauthorizedRequestCallback: (() -> Bool)?
    
    //MARK: - Headers
    open var headers: [String: String]?
    
    //MARK: - Environment
    open var environmentManager: EnvironmentManager?
    open var environment: Environment?
    
    //MARK: - Caching
    public struct SystemCacheConfiguration: Equatable {
        public var memoryCapacity: Int!
        public var diskCapacity: Int!
        public var requestCachePolicy: URLRequest.CachePolicy!
        public var diskPath: String?
        
        
        public init(memoryCapacity: Int, diskCapacity: Int, diskPath: String?, requestCachePolicy: URLRequest.CachePolicy) {
            self.memoryCapacity = memoryCapacity
            self.diskCapacity = diskCapacity
            self.diskPath = diskPath
            self.requestCachePolicy = requestCachePolicy
        }
        
        public static var `default`: SystemCacheConfiguration {
            return SystemCacheConfiguration(memoryCapacity: 4 * 1024 * 1024, diskCapacity: 20 * 1024 * 1024, diskPath: nil, requestCachePolicy: .useProtocolCachePolicy)
        }
    }
    
    public enum CachingStore {
        case system(SystemCacheConfiguration)
        case tentaclesEphemeral
        case tentaclesPersistant
        case client(TentaclesCaching)
    }
    
    public var cachingStore: CachingStore? {
        didSet {
            if let value = cachingStore {
                switch value {
                case .system(let config):
                    var isSame = false
                    if let previous = oldValue {
                        switch previous {
                        case .system(let previousConfig):
                            isSame = previousConfig == config
                        default:
                            break
                        }
                    }
                    if !isSame {
                        urlCache = URLCache(memoryCapacity: config.memoryCapacity, diskCapacity: config.diskCapacity, diskPath: config.diskPath)
                        urlSessionConfiguration?.urlCache = urlCache
                    }
                default:
                    break
                }
            }
        }
    }
    
    public var cache: TentaclesCaching? {
        guard let store = cachingStore else {return nil}
        switch store {
        case .system(_):
            return nil
        case .tentaclesEphemeral:
            return TentaclesEphemeralCache.shared
        case .tentaclesPersistant:
            return TentaclesPersistantCache.shared
        case .client(let caching):
            return caching
        }
    }
    open var urlCache: URLCache?
    
    public enum QueryParameterPlusEncodingBehavior {
        case `default`
        case encode
    }
    
    //MARK: - Configuration
    public struct SessionConfiguration {
        public var scheme: String?
        public var host: String?
        public var authorizationHeaderKey: String?
        public var authorizationHeaderValue: String?
        public var headers: [String: String]?
        public var isWrittingDisabled: Bool?
        public var timeout: Double?
        public var queryParameterPlusEncodingBehavior: QueryParameterPlusEncodingBehavior
        public var allowsLongRunningTasks: Bool
        
        public init(scheme: String?,
                    host: String?,
                    authorizationHeaderKey: String?,
                    authorizationHeaderValue: String?,
                    headers: [String: String]?,
                    isWrittingDisabled: Bool?,
                    timeout: Double?,
                    queryParameterPlusEncodingBehavior: QueryParameterPlusEncodingBehavior = .default,
                    allowsLongRunningTasks: Bool = false) {
            self.scheme = scheme
            self.host = host
            self.authorizationHeaderKey = authorizationHeaderKey
            self.authorizationHeaderValue = authorizationHeaderValue
            self.headers = headers
            self.isWrittingDisabled = isWrittingDisabled
            self.timeout = timeout
            self.queryParameterPlusEncodingBehavior = queryParameterPlusEncodingBehavior
            self.allowsLongRunningTasks = allowsLongRunningTasks
        }
    }
    
    open var sessionConfiguration: SessionConfiguration? {
        didSet {
            if let configScheme = sessionConfiguration?.scheme {
                self.scheme = configScheme
            }
            if let configHost = sessionConfiguration?.host {
                self.host = configHost
            }
            if let configAuthKey = sessionConfiguration?.authorizationHeaderKey {
                self.authorizationHeaderKey = configAuthKey
            }
            if let configAuthValue = sessionConfiguration?.authorizationHeaderValue {
                self.authorizationHeaderValue = configAuthValue
            }
            if let configHeaders = sessionConfiguration?.headers {
                self.headers = configHeaders
            }
            if let configWritingDisabled = sessionConfiguration?.isWrittingDisabled {
                self.isWrittingDisabled = configWritingDisabled
            }
            if let configTimeout = sessionConfiguration?.timeout {
                self.timeout = configTimeout
            }
            self.queryParameterPlusEncodingBehavior = sessionConfiguration?.queryParameterPlusEncodingBehavior ?? .default
        }
    }
    open var sessionConfigurationCallback: SessionConfigurationClosure?
    
    //MARK: - Endpoints
    open var endpoints = [Endpoint]()
    
    //MARK: - State
    open var isBusy: Bool {
        return _urlSession != nil
    }
    
    //MARK Disabling request types
    open var disabledRequestTypes = Set<Endpoint.RequestType>()
    open var isWrittingDisabled = false {
        didSet {
            if isWrittingDisabled {
                disabledRequestTypes = disabledRequestTypes.union(writeRequestTypes)
            }
            else {
                disabledRequestTypes = disabledRequestTypes.subtracting(writeRequestTypes)
            }
        }
    }
    
    
    //MARK: - Request Timeout
    open var timeout: TimeInterval = 60
    
    //MARK: - Plus (+) character encoding behavior
    open var queryParameterPlusEncodingBehavior: QueryParameterPlusEncodingBehavior = .default
    
    //MARK: - Unauthorized status codes
    open var unauthorizedStatusCodes: [Int] = [401, 403]
    
    //MARK: - Callbacks
    open var requestStartedAction: NetworkRequestBegunClosure?
    open var requestCompletedAction: NetworkRequestCompletedClosure?
    
    //MARK: - Private members
    private var _host: String?
    private var _scheme: String = "https"
    private var _urlSession: URLSession?
    
    private var writeRequestTypes: Set<Endpoint.RequestType> {
        var writes = Set<Endpoint.RequestType>()
        for request in Endpoint.RequestType.allCases {
            if request.isWrite {
                writes.insert(request)
            }
        }
        return writes
    }
    
    public override init() {
        super.init()
        urlSessionConfiguration = URLSessionConfiguration.default
    }
    
    deinit {
        Tentacles.shared.log("deleting session", level: .info)
    }
    
    public init(cachingStore: CachingStore) {
        super.init()
        
        urlSessionConfiguration = URLSessionConfiguration.default
        
        self.cachingStore = cachingStore
        
        switch cachingStore {
        case .system(let config):
            urlCache = URLCache(memoryCapacity: config.memoryCapacity, diskCapacity: config.diskCapacity, diskPath: config.diskPath)
            urlSessionConfiguration?.urlCache = urlCache
        default:
            break
        }
    }
    
    //MARK: will be deprecated
    public func cancel(_ taskId: Endpoint.Task) {
        let semaphore = DispatchSemaphore(value: 1)
        let _ = semaphore.wait(timeout: DispatchTime.now() + 60.0)
        urlSession.getTasksWithCompletionHandler { dataTasks, uploadTasks, downloadTasks in
            var tasks = [URLSessionTask]()
            tasks.append(contentsOf: dataTasks as [URLSessionTask])
            tasks.append(contentsOf: uploadTasks as [URLSessionTask])
            tasks.append(contentsOf: downloadTasks as [URLSessionTask])
            
            for task in tasks {
                if task.taskIdentifier == taskId.identifier {
                    task.cancel()
                    break
                }
            }
            
            semaphore.signal()
            self.checkSessionCompleted()
        }
    }
    
    public func cancel(_ taskId: Endpoint.Task, closure: @escaping SessionCancelationClosure) {
        urlSession.getTasksWithCompletionHandler { dataTasks, uploadTasks, downloadTasks in
            var tasks = [URLSessionTask]()
            tasks.append(contentsOf: dataTasks as [URLSessionTask])
            tasks.append(contentsOf: uploadTasks as [URLSessionTask])
            tasks.append(contentsOf: downloadTasks as [URLSessionTask])
            
            for task in tasks {
                if task.taskIdentifier == taskId.identifier {
                    print("canceling task id: \(taskId.urlRequest?.url?.absoluteString ?? "n/a")")
                    task.cancel()
                    break
                }
            }
            
            var completed = true
            for task in tasks {
                switch task.state {
                case .running, .suspended:
                    completed = false
                case .canceling, .completed:
                    break
                @unknown default:
                    break
                }
            }
            if completed {
                self._urlSession?.invalidateAndCancel()
                self._urlSession = nil
            }
            
            closure(taskId)
        }
    }
    
    open func removeAllCachedResponses() {
        urlCache?.removeAllCachedResponses()
        TentaclesEphemeralCache.shared.removeAll()
        TentaclesPersistantCache.shared.removeAll()
        if let store = cachingStore {
            switch store {
            case .client(let cachable):
                cachable.removeAll()
            default:
                break
            }
        }
    }
    
    /// Cancels all the current requests.
    public func cancelAllRequests() {
        let semaphore = DispatchSemaphore(value: 1)
        let _ = semaphore.wait(timeout: DispatchTime.now() + 60.0)
        urlSession.getTasksWithCompletionHandler { dataTasks, uploadTasks, downloadTasks in
            for sessionTask in dataTasks {
                sessionTask.cancel()
            }
            for sessionTask in downloadTasks {
                sessionTask.cancel()
            }
            for sessionTask in uploadTasks {
                sessionTask.cancel()
            }
            
            semaphore.signal()
            self.checkSessionCompleted()
        }
    }
    
    open func apiError(errorType: APIError.ErrorType, error: Error?, response: Response?) -> APIError {
        switch errorType {
        case .http, .encode:
            return APIError(errorType: errorType, message: error?.localizedDescription, error: error, response: response)
        case .decode:
            return APIError(errorType: errorType,
                            message: "An unexpected error occurred. Please try again later.\n\n[parsing error]",
                            error: error,
                            response: response)
        }
    }
    
    internal func composedURL(_ path: String) -> URL? {
        let composedPath = path.environmentalized(manager: environmentManager, environment: environment)
        // path may be a fully qualified URL string - check for that
        if let precomposed = URL(string: composedPath) {
            if precomposed.scheme != nil && precomposed.host != nil {
                return precomposed
            }
        }
        
        guard let host = host else {return nil}
        let urlString = scheme + "://" + host
        
        guard let url = URL(string: urlString) else {return nil}
        
        return url.appendingPathComponent(composedPath)
    }
    
    internal func urlError() -> Error {
        let error = NSError.tentaclesError(code: URLError.badURL.rawValue, localizedDescription: "Bad URL")
        return error
    }
    
    internal func updateSessionConfiguration() {
        if let callback = sessionConfigurationCallback, let config = callback() {
            self.sessionConfiguration = config
        }
    }
    
    //MARK: - Delegate methods
    public func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        Tentacles.shared.log("urlSession didCompleteWithError", level: .info)
        guard let endpoint = task.endpoint(for: self) else {
            print(error ?? "No endpoint found")
            NotificationCenter.default.post(name: .tentaclesOrphanedSessionTask, object: task)
            return
        }
        endpoint.completed(task: task, error: error)
        
        // remove this endpoint from our session
        endpoints = endpoints.filter({ (test) -> Bool in
            return test !== endpoint
        })
        
        checkSessionCompleted()
    }
    
    public func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, didReceive response: URLResponse, completionHandler: @escaping (URLSession.ResponseDisposition) -> Void) {
        completionHandler(.allow)
        Tentacles.shared.log("urlSession didReceive response", level: .info)
    }
    
    public func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, didReceive data: Data) {
        Tentacles.shared.log("urlSession didReceive data", level: .info)
        for endpoint in endpoints {
            if endpoint.task?.identifier == dataTask.taskIdentifier {
                endpoint.didReceiveData(receivedData: data)
                break
            }
        }
    }
    
    public func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didWriteData bytesWritten: Int64, totalBytesWritten: Int64, totalBytesExpectedToWrite: Int64) {
        var percentComplete: Double?
        if totalBytesExpectedToWrite != NSURLSessionTransferSizeUnknown {
            percentComplete = Double(totalBytesWritten) / Double(totalBytesExpectedToWrite)
        }
        downloadTask.endpoint(for: self)?.progress(bytesWritten: bytesWritten, totalBytesWritten: totalBytesWritten, totalBytesExpectedToWrite: totalBytesExpectedToWrite, percentComplete: percentComplete)
    }
    
    public func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didFinishDownloadingTo location: URL) {
        Tentacles.shared.log(location.absoluteString, level: .info)
        Tentacles.shared.log("urlSession didFinishDownloadingTo", level: .info)
        if let data = try? Data(contentsOf: location) {
            downloadTask.endpoint(for: self)?.didReceiveData(receivedData: data)
        }
        // Note we do not call Endpoint:completed here, it will get called by the URLSessionTask delegate method 'didCompleteWithError'
    }
    
    public func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, willCacheResponse proposedResponse: CachedURLResponse, completionHandler: @escaping (CachedURLResponse?) -> Void) {
        
        completionHandler(proposedResponse)
        Tentacles.shared.log("urlSession willCacheResponse", level: .info)
    }
    
    public func urlSession(
        _ session: URLSession,
        task: URLSessionTask,
        didReceive challenge: URLAuthenticationChallenge,
        completionHandler: @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> Void) {
            
            Tentacles.shared.log(
                "urlSession didReceiveChallenge \(challenge.protectionSpace.host)",
                level: .warning)
            
            guard let handler = self.challengeHandler else {
                        
                Tentacles.shared.log(
                    "urlSession didReceiveChallenge, using default handler",
                    level: .warning)
                        completionHandler(.performDefaultHandling, nil)
                        return
            }
            
            Tentacles.shared.log(
                "urlSession didReceiveChallenge calling configured handler",
                level: .warning)
            
            let result = handler(session, task, challenge)
            completionHandler(result.0, result.1)
         
    }
    
    private func checkSessionCompleted() {
        let semaphore = DispatchSemaphore(value: 1)
        let _ = semaphore.wait(timeout: DispatchTime.now() + 60.0)
        urlSession.getTasksWithCompletionHandler { dataTasks, uploadTasks, downloadTasks in
            var tasks = [URLSessionTask]()
            tasks.append(contentsOf: dataTasks as [URLSessionTask])
            tasks.append(contentsOf: uploadTasks as [URLSessionTask])
            tasks.append(contentsOf: downloadTasks as [URLSessionTask])
            
            var completed = true
            for task in tasks {
                switch task.state {
                case .running, .suspended:
                    completed = false
                case .canceling, .completed:
                    break
                @unknown default:
                    break
                }
            }
            if completed {
                self._urlSession?.invalidateAndCancel()
                self._urlSession = nil
            }
            
            semaphore.signal()
        }
    }
}

extension URLSessionTask {
    func endpoint(for session: Session) -> Endpoint? {
        return session.endpoints.first(where: { (endpoint) -> Bool in
            return endpoint.task?.identifier == taskIdentifier
        })
    }
}









