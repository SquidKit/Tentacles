//
//  Session.swift
//  Tentacles
//
//  Created by Mike Leavy on 3/28/18.
//  Copyright © 2018 Squid Store. All rights reserved.
//

import Foundation

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
public typealias NetworkRequestCompletedClosure = (_ endpoint: Endpoint) -> Void

open class Session: NSObject, URLSessionDelegate, URLSessionDataDelegate, URLSessionDownloadDelegate, URLSessionTaskDelegate {
    
    public static var shared = Session()
    
    //MARK: - URLSession
    open var urlSession: URLSession {
        if _urlSession == nil {
            _urlSession = URLSession(configuration: configuration, delegate: self, delegateQueue: nil)
        }
        return _urlSession!
    }
    open var configuration: URLSessionConfiguration!
    
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
    open var unauthorizedRequestCallback: (() -> Void)?
    
    //MARK: - Headers
    open var headers: [String: String]?
    
    //MARK: - Environment
    open var environmentManager: EnvironmentManager?
    open var environment: Environment?
    
    //MARK: - Caching
    public struct SystemCacheConfiguration {
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
    
    public var cachingStore: CachingStore?
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
    
    //MARK: - Endpoints
    open var endpoints = [Endpoint]()
    
    //MARK: - State
    open var isBusy: Bool {
        return _urlSession != nil
    }
    
    
    //MARK: - Request Timeout
    open var timeout: TimeInterval = 60
    
    //MARK: - Callbacks
    open var requestStartedAction: NetworkRequestBegunClosure?
    open var requestCompletedAction: NetworkRequestCompletedClosure?
    
    //MARK: - Private members
    private var _host: String?
    private var _scheme: String = "https"
    private var _urlSession: URLSession?
    
    public override init() {
        super.init()
        configuration = URLSessionConfiguration.default
    }
    
    deinit {
        Tentacles.shared.log("deleting session", level: .info)
    }
    
    public init(cachingStore: CachingStore) {
        super.init()
        
        configuration = URLSessionConfiguration.default
        
        self.cachingStore = cachingStore
        
        switch cachingStore {
        case .system(let config):
            urlCache = URLCache(memoryCapacity: config.memoryCapacity, diskCapacity: config.diskCapacity, diskPath: config.diskPath)
            configuration?.urlCache = urlCache
        default:
            break
        }
    }
    
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
    
    //MARK: - Delegate methods
    public func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        Tentacles.shared.log("urlSession didCompleteWithError", level: .info)
        guard let endpoint = task.endpoint(for: self) else {return}
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









