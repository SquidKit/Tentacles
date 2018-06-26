//
//  EndpointMap.swift
//  Tentacles
//
//  Created by Mike Leavy on 8/27/14.
//  Copyright (c) 2018 Squid Store. All rights reserved.
//

import Foundation

private let _EndpointMapperSharedInstance = EndpointMapper()

public protocol HostMapCacheStorable {
    func setEntry(_ entry:[String: AnyObject], key:String)
    func getEntry(_ key:String) -> [String: AnyObject]?
    func remove(_ key:String)
}

public struct ProtocolHostPair: CustomStringConvertible, CustomDebugStringConvertible {
    public var `protocol`:String?
    public var host:String?
    
    public init(_ `protocol`:String?, _ host:String?) {
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

func == (left:ProtocolHostPair, right:ProtocolHostPair) -> Bool {
    return left.host == right.host && left.protocol == right.protocol
}

internal class EndpointMapper {
    
    fileprivate var mappedHosts = [String: ProtocolHostPair]()
    
    fileprivate init() {
        
    }
    
    class var sharedInstance: EndpointMapper {
        return _EndpointMapperSharedInstance
    }
    
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
            return hostMap.canonicalHost == canonicalHost
        }
        guard let hostMap = first else {return nil}
        let mapped = EndpointMapper.mappedPairForCanonicalHost(hostMap.canonicalHost)
        return mapped?.host ?? hostMap.canonicalHost
    }

    open func loadConfigurationMapFromResourceFile(_ fileName:String) -> Bool {
        let result = HostConfigurationsLoader.loadConfigurationsFromResourceFile(fileName, manager: self)
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
    
        fileprivate class func loadConfigurationsFromResourceFile(_ fileName:String, manager:HostMapManager) -> Bool {
            var result = false
            
            if let hostDictionary = NSDictionary.dictionaryFromResourceFile(fileName) {
                result = true
                
                if let configurations:NSArray = hostDictionary.object(forKey: "configurations") as? NSArray {
                    
                    for configuration in configurations {
                        HostConfigurationsLoader.handleConfiguration(configuration as AnyObject, manager: manager)
                    }
                    
                }
                
            }
            
            return result
        }

        fileprivate class func handleConfiguration(_ configuration:AnyObject, manager:HostMapManager) {
            if let config:[String: AnyObject] = configuration as? [String: AnyObject] {
                let canonicalHost:String? = config[HostConfigurationKey.canonicalHost.rawValue] as? String
                let canonicalProtocol:String? = config[HostConfigurationKey.canonicalProtocol.rawValue] as? String
                let releaseKey:String? = config[HostConfigurationKey.releaseKey.rawValue] as? String
                let prereleaseKey:String? = config[HostConfigurationKey.prereleaseKey.rawValue] as? String

                if canonicalHost != nil && canonicalProtocol != nil {
                    let hostMap = HostMap(canonicalProtocolHostPair:ProtocolHostPair(canonicalProtocol, canonicalHost))
                    
                    if let release = releaseKey {
                        hostMap.releaseKey = release
                    }
                    if let prerelease = prereleaseKey {
                        hostMap.prereleaseKey = prerelease
                    }

                    if let hostsArray:[[String: String]] = config[HostConfigurationKey.hosts.rawValue] as? [[String: String]] {
                        for host in hostsArray {
                            let aKey:String? = host[.hostsKey] as? String
                            let aHost:String? = host[.hostsHost] as? String
                            let aProtocol:String? = host[.protocol] as? String
                            if let key = aKey {
                                let pair = ProtocolHostPair(aProtocol, aHost)
                                hostMap.mappedPairs[key] = pair
                                hostMap.sortedKeys.append(key)
                                // if there is no host, consider this item editable
                                if aHost == nil {
                                    hostMap.editableKeys.append(key)
                                }
                            }
                        }
                    }

                    manager.hostMaps.append(hostMap)
                }
            }
        }
    }
}

private enum HostConfigurationKey:String {
    case canonicalHost = "canonical_host"
    case canonicalProtocol = "canonical_protocol"
    case releaseKey = "release_key"
    case prereleaseKey = "prerelease_key"
    case hosts = "hosts"
    case hostsKey = "key"
    case hostsHost = "host"
    case `protocol` = "protocol"
}
        
private class NilMarker :NSObject {
    
}

extension Dictionary {
    
    fileprivate subscript(key:HostConfigurationKey) -> NSObject {
        for k in self.keys {
            if let kstring = k as? String {
                if kstring == key.rawValue {
                    return self[k]! as! NSObject
                }
            }
        }
            
        return NilMarker()
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
