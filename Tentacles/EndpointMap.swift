//
//  EndpointMap.swift
//  Tentacles
//
//  Created by Mike Leavy on 8/27/14.
//  Copyright (c) 2018 Squid Store. All rights reserved.
//

import Foundation

public protocol HostMapCacheStorable {
    func setEntry(_ entry:[String: AnyObject], key:String)
    func getEntry(_ key:String) -> [String: AnyObject]?
    func remove(_ key:String)
}

public struct ProtocolHostPair: CustomStringConvertible, CustomDebugStringConvertible {
    public var `protocol`:String?
    public var host:String?
    
    internal init(_ `protocol`:String?, _ host:String?) {
        self.protocol = `protocol`
        self.host = host
    }
    
    public var description: String {
        return "ProtocolHostPair: protocol = \(String(describing: `protocol`)); host = \(String(describing: host))"
    }

    public var debugDescription: String {
        return self.description
    }

}

public func == (left:ProtocolHostPair, right:ProtocolHostPair) -> Bool {
    return left.host == right.host && left.protocol == right.protocol
}

internal class EndpointMapper {
    
    fileprivate var mappedHosts = [String: ProtocolHostPair]()
    
    fileprivate init() {
        
    }
    
    static let sharedInstance = EndpointMapper()
    
    class func addProtocolHostMappedPair(_ mappedPair:ProtocolHostPair, canonicalHost:String) {
        EndpointMapper.sharedInstance.mappedHosts[canonicalHost] = mappedPair
    }
    
    class func removeProtocolHostMappedPair(_ canonicalHost:String) {
        EndpointMapper.sharedInstance.mappedHosts[canonicalHost] = nil
    }
    
    class func mappedPairForCanonicalHost(_ canonicalHost:String) -> (ProtocolHostPair?) {
        return EndpointMapper.sharedInstance.mappedHosts[canonicalHost]
    }
    
}

open class HostMap {
    open let canonicalProtocolHost:ProtocolHostPair
    
    open var name: String?
    open var releaseKey = ""
    open var prereleaseKey = ""
    open var mappedPairs = [String: ProtocolHostPair]()
    open var sortedKeys = [String]()
    open var editableKeys = [String]()

    open var canonicalHost:String {
        if let host = canonicalProtocolHost.host {
            return host
        }
        return ""
    }
    
    public init(canonicalProtocolHostPair:ProtocolHostPair) {
        self.canonicalProtocolHost = canonicalProtocolHostPair
    }
    
    open func pairWithKey(_ key:String) -> ProtocolHostPair? {
        return mappedPairs[key]
    }

    open func isEditable(_ key:String) -> Bool {
        return editableKeys.contains(key)
    }
}

open class HostMapManager {
    open var hostMaps = [HostMap]()

    fileprivate var hostMapCache:HostMapCache!
    
    required public init(cacheStore:HostMapCacheStorable?) {
        self.hostMapCache = HostMapCache(cacheStore: cacheStore)
    }
    
    public var mappedHosts: [String] {
        var hosts = [String]()
        for host in hostMaps {
            let mapped = EndpointMapper.mappedPairForCanonicalHost(host.canonicalHost)
            hosts.append(mapped?.host ?? host.canonicalHost)
        }
        return hosts
    }
    
    public var canonicalHosts: [String] {
        var hosts = [String]()
        for host in hostMaps {
            hosts.append(host.canonicalHost)
        }
        return hosts
    }
    
    open func mappedHost(for canonicalHost: String) -> String? {
        let first = hostMaps.first { (hostMap) -> Bool in
            return hostMap.canonicalHost.caseInsensitiveCompare(canonicalHost) == ComparisonResult.orderedSame
        }
        guard let hostMap = first else {return nil}
        let mapped = EndpointMapper.mappedPairForCanonicalHost(hostMap.canonicalHost)
        return mapped?.host ?? hostMap.canonicalHost
    }
    
    open func mappedHost(named: String) -> String? {
        let first = hostMaps.first { (hostMap) -> Bool in
            guard let name = hostMap.name else {return false}
            return name.caseInsensitiveCompare(named) == ComparisonResult.orderedSame
        }
        guard let hostMap = first else {return nil}
        let mapped = EndpointMapper.mappedPairForCanonicalHost(hostMap.canonicalHost)
        return mapped?.host ?? hostMap.canonicalHost
    }

    open func loadConfigurationMap(resourceFileName: String) -> Bool {
        let result = HostConfigurationsLoader.loadConfigurations(resourceFileName: resourceFileName, manager: self)
        self.restoreFromCache()
        return result
    }
    
    open func loadConfigurationMap(jsonString: String) -> Bool {
        let result = HostConfigurationsLoader.loadConfigurations(jsonString: jsonString, manager: self)
        self.restoreFromCache()
        return result
    }
    
    open func loadConfigurationMap(dictionary: [String: Any]) -> Bool {
        let result = HostConfigurationsLoader.loadConfigurations(dictionary: dictionary, manager: self)
        self.restoreFromCache()
        return result
    }

    open func setReleaseConfigurations() {
        for hostMap in self.hostMaps {
            if let releasePair = hostMap.pairWithKey(hostMap.releaseKey) {
                EndpointMapper.addProtocolHostMappedPair(releasePair, canonicalHost: hostMap.canonicalHost)
            }
        }
    }

    open func setPrereleaseConfigurations() {
        for hostMap in self.hostMaps {
            if let preReleasePair = hostMap.pairWithKey(hostMap.prereleaseKey) {
                EndpointMapper.addProtocolHostMappedPair(preReleasePair, canonicalHost: hostMap.canonicalHost)
            }
        }
    }
    
    open func setConfigurationForCanonicalHost(_ configurationKey:String, mappedHost:String?, canonicalHost:String, withCaching:Bool = true) {
        for hostMap in self.hostMaps {
            if hostMap.canonicalProtocolHost.host == canonicalHost {
                var runtimePair = hostMap.pairWithKey(configurationKey)
                if runtimePair != nil {
                    if mappedHost != nil {
                        runtimePair!.host = mappedHost
                        hostMap.mappedPairs[configurationKey] = runtimePair
                    }
                    let empty:Bool = (runtimePair!.host == nil || runtimePair!.host!.isEmpty)
                    if !empty {
                        EndpointMapper.addProtocolHostMappedPair(runtimePair!, canonicalHost: canonicalHost)
                    }
                    else {
                        EndpointMapper.removeProtocolHostMappedPair(canonicalHost)
                    }
                    if withCaching {
                        if !empty {
                            self.hostMapCache.cacheKeyAndHost(configurationKey, mappedHost:runtimePair!.host!, forCanonicalHost: canonicalHost)
                        }
                        else {
                            self.hostMapCache.removeCachedKeyForCanonicalHost(canonicalHost)
                        }
                    }
                }
                break
            }
        }
    }


    fileprivate func restoreFromCache() {
        for hostMap in self.hostMaps {
            if let (key, host) = self.hostMapCache.retreiveCachedKeyAndHostForCanonicalHost(hostMap.canonicalHost) {
                self.setConfigurationForCanonicalHost(key, mappedHost:host, canonicalHost: hostMap.canonicalHost, withCaching: false)
            }
        }
    }

    fileprivate class HostConfigurationsLoader {
    
        fileprivate class func loadConfigurations(resourceFileName: String, manager: HostMapManager) -> Bool {
            guard var url = Bundle.main.resourceURL else {return false}
            url = url.appendingPathComponent(resourceFileName, isDirectory: false)
            guard let data = try? Data(contentsOf: url) else {return false}
            
            return loadConfigurations(from: data, manager: manager)
        }
        
        fileprivate class func loadConfigurations(jsonString: String, manager: HostMapManager) -> Bool {
            guard let jsonData = jsonString.data(using: .utf8) else {return false}
            return loadConfigurations(from: jsonData, manager: manager)
        }
        
        fileprivate class func loadConfigurations(dictionary: [String: Any], manager: HostMapManager) -> Bool {
            guard let jsonData = try? JSONSerialization.data(withJSONObject: dictionary, options: []) else {return false}
            return loadConfigurations(from: jsonData, manager: manager)
        }
        
        private class func loadConfigurations(from data:Data, manager:HostMapManager) -> Bool {
            
            let decoder = JSONDecoder()
            
            do {
                let map = try decoder.decode(HostMapModel.self, from: data)
                
                guard let configurations = map.configurations else {return false}
                for configuration in configurations {
                    let hostMap = HostMap(canonicalProtocolHostPair: ProtocolHostPair(configuration.canonicalProtocol, configuration.canonicalHost))
                    hostMap.releaseKey = configuration.releaseKey ?? hostMap.releaseKey
                    hostMap.prereleaseKey = configuration.prereleaseKey ?? hostMap.prereleaseKey
                    hostMap.name = configuration.name
                    
                    if let hosts = configuration.hosts {
                        for host in hosts {
                            let pair = ProtocolHostPair(host.protocol, host.host)
                            hostMap.mappedPairs[host.key] = pair
                            hostMap.sortedKeys.append(host.key)
                            if host.host == nil {
                                hostMap.editableKeys.append(host.key)
                            }
                        }
                    }
                    manager.hostMaps.append(hostMap)
                }
            }
            catch (let error) {
                Tentacles.shared.log(error.localizedDescription, level: .error)
                return false
            }
            return true
        }
    }
}

private struct HostMapModel: Codable {
    struct Configuration: Codable {
        struct Host: Codable {
            let key: String
            let host: String?
            let `protocol`: String?
            
            enum CodingKeys: String, CodingKey {
                case key
                case host
                case `protocol`
            }
        }
        let name: String?
        let canonicalHost: String
        let canonicalProtocol: String
        let releaseKey: String?
        let prereleaseKey: String?
        let hosts: [Host]?
        
        enum CodingKeys: String, CodingKey {
            case name
            case canonicalHost = "canonical_host"
            case canonicalProtocol = "canonical_protocol"
            case releaseKey = "release_key"
            case prereleaseKey = "prerelease_key"
            case hosts
        }
    }
    
    let configurations: [Configuration]?
    
    enum CodingKeys: String, CodingKey {
        case configurations
    }
}


private class HostMapCache {
    let tentaclesHostMapCacheKey = "com.squidkit.tentacles.hostMapCachePreferenceKey"

    typealias CacheDictionary = [String: [String: String]]
    
    var cacheStore:HostMapCacheStorable?

    required init(cacheStore:HostMapCacheStorable?) {
        self.cacheStore = cacheStore
    }

    func cacheKeyAndHost(_ key:String, mappedHost:String, forCanonicalHost canonicalHost:String) {
        var mutableCache:[String: AnyObject]?
        if let cache:[String: AnyObject] = cacheStore?.getEntry(tentaclesHostMapCacheKey) {
            mutableCache = cache
        }
        else {
            mutableCache = [String: AnyObject]()
        }
        
        var dictionaryItem = [String: String]()
        dictionaryItem["key"] = key
        dictionaryItem["host"] = mappedHost
        mutableCache![canonicalHost] = dictionaryItem as AnyObject?
        
        cacheStore?.setEntry(mutableCache!, key: tentaclesHostMapCacheKey)
    }

    
    func retreiveCachedKeyAndHostForCanonicalHost(_ canonicalHost:String) -> (String, String)? {
        var result:(String, String)?
        if let cache:[String: AnyObject] = cacheStore?.getEntry(tentaclesHostMapCacheKey) {
            if let hostDict:[String: String] = cache[canonicalHost] as? [String: String] {
                result = (hostDict["key"]! , hostDict["host"]! )
            }
        }
        return result
    }

    func removeCachedKeyForCanonicalHost(_ canonicalHost:String) {
        if let cache:[String: AnyObject] = cacheStore?.getEntry(tentaclesHostMapCacheKey) {
            var mutableCache = cache
            mutableCache.removeValue(forKey: canonicalHost)
            cacheStore?.setEntry(mutableCache, key: tentaclesHostMapCacheKey)
        }
    }

    func removeAll() {
        cacheStore?.remove(tentaclesHostMapCacheKey)
    }
}
