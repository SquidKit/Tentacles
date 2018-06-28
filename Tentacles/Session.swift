//
//  Session.swift
//  Tentacles
//
//  Created by Mike Leavy on 3/28/18.
//  Copyright © 2018 Squid Store. All rights reserved.
//

import Foundation


open class Session: NSObject, URLSessionDelegate, URLSessionDataDelegate {
    
    public enum Scheme: String {
        case http
        case https
    }
    
    public static var shared = Session()
    
    //MARK: - URLSession
    open var urlSession: URLSession?
    open var configuration: URLSessionConfiguration?
    
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
    open var scheme: Scheme = .https
    private var composedScheme: String {
        if let manager = environmentManager, let env = environment {
            return manager.scheme(for: env)
        }
        return scheme.rawValue
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
    open var urlCache: URLCache?
    
    //MARK: - Endpoints
    open var endpoints = [Endpoint]()
    
    
    //MARK: - Request Timeout
    open var timeout: TimeInterval = 60
    
    //MARK: - Private members
    private var _host: String?
    
    public override init() {
        super.init()
        configuration = URLSessionConfiguration.default
        
        urlSession = URLSession(configuration: configuration!, delegate: self, delegateQueue: nil)
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
        
        urlSession = URLSession(configuration: configuration!, delegate: self, delegateQueue: nil)
    }
    
    public func cancel(_ taskId: Endpoint.Task) {
        let semaphore = DispatchSemaphore(value: 0)
        urlSession?.getTasksWithCompletionHandler { dataTasks, uploadTasks, downloadTasks in
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
        }
        
        _ = semaphore.wait(timeout: DispatchTime.now() + 60.0)
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
        let semaphore = DispatchSemaphore(value: 0)
        urlSession?.getTasksWithCompletionHandler { dataTasks, uploadTasks, downloadTasks in
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
        }
        
        _ = semaphore.wait(timeout: DispatchTime.now() + 60.0)
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
        let urlString = composedScheme + "://" + host
        
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
        var found: Int?
        for i in 0..<endpoints.count {
            if endpoints[i].task?.identifier == task.taskIdentifier {
                endpoints[i].completed(task: task, error: error)
                found = i
                break
            }
        }
        
        if let found = found {
            endpoints.remove(at: found)
        }
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
    
    public func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, willCacheResponse proposedResponse: CachedURLResponse, completionHandler: @escaping (CachedURLResponse?) -> Void) {
        
        completionHandler(proposedResponse)
        Tentacles.shared.log("urlSession willCacheResponse", level: .info)
    }
}









