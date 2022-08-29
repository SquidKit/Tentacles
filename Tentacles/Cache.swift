//
//  Cache.swift
//  Tentacles
//
//  Created by Mike Leavy on 3/28/18.
//  Copyright © 2018 Squid Store. All rights reserved.
//

import Foundation

public enum CacheExpiry {
    
    // A cached response never expires
    case never
    
    // A cached response is always considered expired
    // (useful for forcing the cached response to be removed)
    case always
    
    // A cached response never expires, but is only used for
    // cases where the network request fails
    case contingent
    
    // A cached response will be used for the specified time interval,
    // but the cache is not removed after that interval and is instead
    // used as a backup for network request failures
    case contingentAfter(TimeInterval)
    
    // Normal cache behavior with a custom expiration interval
    case custom(TimeInterval)
    
    public var expiry: TimeInterval? {
        switch self {
        case .contingentAfter(let interval):
            return interval
        case .custom(let interval):
            return interval
        case .never, .always, .contingent:
            return nil
        }
    }
}


public typealias CacheExpirationCallback = (_ request: URLRequest) -> CacheExpiry?
public typealias CacheNameIncludesQueryCallback = (_ request: URLRequest) -> Bool

public class CachedResponse {
    public let httpStatusCode: Int
    public let data: Data
    public let timestamp: Date
    
    public init(code: Int, object: Data, timestamp: Date) {
        self.httpStatusCode = code
        self.data = object
        self.timestamp = timestamp
    }
    
    static func cached(from cache: TentaclesCaching, request: URLRequest, requestDidFail: Bool = false) -> (CachedResponse?, Date?) {
        var expiry = cache.defaultExpiry
        if let expiration = cache.expirationCallback?(request) {
            expiry = expiration
        }
        
        if let object = cache.cached(request: request) {
            switch expiry {
            case .never:
                return (object, object.timestamp)
            case .always:
                return (nil, object.timestamp)
            case .contingent:
                if requestDidFail {
                    return (object, object.timestamp)
                }
                else {
                    return (nil, object.timestamp)
                }
            case .contingentAfter(let expirationInterval):
                if requestDidFail {
                    return (object, object.timestamp)
                }
                else {
                    return (cachedResponse(object: object, expirationInterval: expirationInterval), object.timestamp)
                }
            case .custom(let expirationInterval):
                return (cachedResponse(object: object, expirationInterval: expirationInterval), object.timestamp)
            }
        }
        return (nil, nil)
    }
    
    static func remove(from cache: TentaclesCaching, request: URLRequest, cachedTimestamp: Date) {
        var expiry = cache.defaultExpiry
        if let expiration = cache.expirationCallback?(request) {
            expiry = expiration
        }
        
        switch expiry {
        case .never, .contingent, .contingentAfter(_):
            break
        case .always:
            return cache.remove(request: request)
        case .custom(let expirationInterval):
            let interval = Date().timeIntervalSince(cachedTimestamp)
            if interval > expirationInterval {
                cache.remove(request: request)
            }
        }
    }
    
    private static func cachedResponse(object: CachedResponse, expirationInterval: TimeInterval) -> CachedResponse? {
        let interval = Date().timeIntervalSince(object.timestamp)
        guard expirationInterval >= 0 else {
            return nil
        }
        guard interval <= expirationInterval else {
            return nil
        }
        return object
    }
        
}

public protocol TentaclesCaching {
    var defaultExpiry: CacheExpiry {get set}
    var expirationCallback: CacheExpirationCallback? {get set}
    var includeQueryInCacheNameCallback: CacheNameIncludesQueryCallback? {get set}
    func cache(data: CachedResponse, request: URLRequest)
    func cached(request: URLRequest) -> CachedResponse?
    func remove(request: URLRequest)
    func removeAll()
}

public class TentaclesEphemeralCache: TentaclesCaching {
    
    public var defaultExpiry: CacheExpiry = .custom(TimeInterval.hours(1))
    public var expirationCallback: CacheExpirationCallback?
    public var includeQueryInCacheNameCallback: CacheNameIncludesQueryCallback?
    
    private func cacheName(_ request: URLRequest) -> String? {
        guard let url = request.url else {return nil}
        var include = true
        if let callback = includeQueryInCacheNameCallback {
            include = callback(request)
        }
        
        return url.cacheName(includeQuery: include)
    }
    
    private init() {
    }
    
    public static let shared = TentaclesEphemeralCache()
    
    var cache = NSCache<NSString, CachedResponse>()
    
    public func cache(data: CachedResponse, request: URLRequest) {
        guard let name = cacheName(request) else {return}
        cache.setObject(data, forKey: name as NSString)
    }
    
    public func cached(request: URLRequest) -> CachedResponse? {
        guard let name = cacheName(request) else {return nil}
        return cache.object(forKey: name as NSString)
    }
    
    public func remove(request: URLRequest) {
        guard let name = cacheName(request) else {return}
        cache.removeObject(forKey: name as NSString)
    }
    
    public func removeAll() {
        cache.removeAllObjects()
    }
    
}

public class TentaclesPersistantCache: TentaclesCaching {
    
    public var defaultExpiry: CacheExpiry = .custom(TimeInterval.hours(1))
    public var expirationCallback: CacheExpirationCallback?
    public var includeQueryInCacheNameCallback: CacheNameIncludesQueryCallback?
    
    private init() {
    }
    
    public static let shared = TentaclesPersistantCache()
    
    private func includeQuery(_ request: URLRequest) -> Bool {
        var include = true
        if let callback = includeQueryInCacheNameCallback {
            include = callback(request)
        }
        
        return include
    }
    
    public func cache(data: CachedResponse, request: URLRequest) {
        guard let url = request.url else {return}
        if let fileURL = fileCacheURL(url: url, includeQuery: includeQuery(request)) {
            Tentacles.shared.logger?.log("found cache path at: \(fileURL.path)", level: .info)
            
            do {
                try data.data.write(to: fileURL)
                fileURL.setExtendedAttribute(value: data.httpStatusCode, forName: "httpStatusCode")
                try? FileManager.default.setAttributes([FileAttributeKey.modificationDate: data.timestamp], ofItemAtPath: fileURL.path)
            }
            catch {
                return 
            }
        }
    }
    
    public func cached(request: URLRequest) -> CachedResponse? {
        guard let url = request.url else {return nil}
        if let fileURL = fileCacheURL(url: url, includeQuery: includeQuery(request)) {
            Tentacles.shared.logger?.log("found cached path at: \(fileURL.path)", level: .info)
            do {
                let data = try Data.init(contentsOf: fileURL)
                guard let attributes = try? FileManager.default.attributesOfItem(atPath: fileURL.path) else {
                    remove(request: request)
                    return nil
                }
                guard let timestamp = (attributes as NSDictionary).fileModificationDate() else {
                    remove(request: request)
                    return nil
                }
                let status = fileURL.extendedAttribute(forName: "httpStatusCode")
                return CachedResponse(code: status, object: data, timestamp: timestamp)
            }
            catch {
                remove(request: request)
                return nil
            }
        }
        
        return nil
    }
    
    public func remove(request: URLRequest) {
        guard let url = request.url else {return}
        if let fileURL = fileCacheURL(url: url, includeQuery: includeQuery(request)) {
            try? FileManager.default.remove(at: fileURL)
        }
    }
    
    public func removeAll() {
        if let folderURL = FileManager.default.tentaclesCachesDirectory {
            
            if FileManager.default.exists(at: folderURL) {
                _ = try? FileManager.default.remove(at: folderURL)
            }
        }
    }
    
    public func fileCacheURL(url: URL, includeQuery: Bool) -> URL? {
        
        if let folderURL = FileManager.default.tentaclesCachesDirectory {
            
            try? (folderURL as NSURL).setResourceValue(true, forKey: URLResourceKey.isExcludedFromBackupKey)
            
            if FileManager.default.exists(at: folderURL) == false {
                do {
                    try FileManager.default.createDirectory(at: folderURL, withIntermediateDirectories: false, attributes: nil)
                }
                catch {
                    return nil
                }
            }
            
            let destinationURL = folderURL.appendingPathComponent(FileManager.default.filename(for: url, includeQuery: includeQuery))
            
            return destinationURL
        }
        
        return nil
    }
}

public extension FileManager {
    
    internal var userCachesDirectory: URL? {
        let directory = FileManager.SearchPathDirectory.cachesDirectory
        return FileManager.default.urls(for: directory, in: .userDomainMask).first
    }
    
    internal var tentaclesCachesDirectory: URL? {
        return userCachesDirectory?.appendingPathComponent(Tentacles.domain)
    }
    
    internal func filename(for resourceURL: URL, includeQuery: Bool) -> String {
        var normalizedFilename = resourceURL.cacheName(includeQuery: includeQuery)
        normalizedFilename = normalizedFilename.replacingOccurrences(of: "/", with: "-")
        guard let path = tentaclesCachesDirectory else {return normalizedFilename}
        
        if path.absoluteString.count + normalizedFilename.count + 1 > PATH_MAX {
            normalizedFilename = "\(normalizedFilename.hashValue)"
        }
        return normalizedFilename
    }
    
    func exists(at url: URL) -> Bool {
        let path = url.path
        
        return fileExists(atPath: path)
    }
    
    func remove(at url: URL) throws {
        let path = url.path
        guard FileManager.default.isDeletableFile(atPath: url.path) else { return }
        
        try FileManager.default.removeItem(atPath: path)
    }
}

extension URL {
    
    var appendableQuery: String {
        guard let query = query else {return ""}
        return "+" + query
    }
    
    func cacheName(includeQuery: Bool) -> String {
        var name = (host ?? "") + path
        if includeQuery {
            name += appendableQuery
        }
        return name
    }
    
    func extendedAttribute(forName name: String) -> Int  {
        
        let data = self.withUnsafeFileSystemRepresentation({ (fileSystemPath) -> Data in
            let length = getxattr(fileSystemPath, name, nil, 0, 0, 0)
            guard length > 0 else {return Data()}
            
            var data = Data(count: length)
            let count = data.count
            
            // Retrieve attribute:
            let result =  data.withUnsafeMutableBytes {
                getxattr(fileSystemPath, name, $0, count, 0, 0)
            }
            guard result >= 0 else {return Data()}
            return data
        })
        
        guard data.count >= MemoryLayout<Int>.size else {return 200}
        
        let number: Int = data.withUnsafeBytes {
            (pointer: UnsafePointer<Int>) -> Int? in
            if MemoryLayout<Int>.size != data.count { return nil }
            return pointer.pointee
        } ?? 200
        
        return number
    }
    
    /// Set extended attribute.
    func setExtendedAttribute(value: Int, forName name: String) {
        
        var myValue = value
        
        var data = Data(bytes: &myValue, count: MemoryLayout.size(ofValue: myValue))
        
        self.withUnsafeFileSystemRepresentation { fileSystemPath in
            let _ = data.withUnsafeBytes {
                setxattr(fileSystemPath, name, $0, data.count, 0, 0)
            }
        }
    }
}

extension TimeInterval {
    static func hours(_ count: Int) -> TimeInterval {
        return TimeInterval(60*60*count)
    }
}





