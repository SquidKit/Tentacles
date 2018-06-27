//
//  HomeViewModel.swift
//  TentaclesExample
//
//  Created by Mike Leavy on 6/26/18.
//  Copyright © 2018 Squid Store. All rights reserved.
//

import Foundation
import Tentacles

struct HomeViewModel {
    
    enum Rows: Int, CustomStringConvertible {
        case hosts
        case endpoint
        case count
        
        var description: String {
            switch self {
            case .hosts:
                return "Hosts"
            case .endpoint:
                return "Endpoint Test"
            case .count:
                return "<<count>>"
            }
        }
    }
    var sections: Int = 1
    
    var hostMapManager = HostMapManager(cacheStore: HostMapCache())
    
    func rows(for section: Int) -> Int {
        return Rows.count.rawValue
    }
    
    func title(for indexPath: IndexPath) -> String? {
        return Rows(rawValue: indexPath.row)?.description
    }
    
    func detailTitle(for indexPath: IndexPath) -> String? {
        return nil
    }
    
    init() {
        let hostMapLoaded = hostMapManager.loadConfigurationMap(resourceFileName: "HostMap.json")
        print("Host map loaded = \(hostMapLoaded)")
    }
    
    var endpointHosts: [String] {
        return hostMapManager.mappedHosts
    }
    
    var canonicalHosts: [String] {
        return hostMapManager.canonicalHosts
    }
    
    func host(for canonical: String) -> String {
        return hostMapManager.mappedHost(for: canonical) ?? "host not found"
    }
    
    func host(named: String) -> String {
        return hostMapManager.mappedHost(named: named) ?? "host not found"
    }
}

class HostMapCache: HostMapCacheStorable {
    func setEntry(_ entry:[String: AnyObject], key:String) {
        UserDefaults.standard.set(entry, forKey: key)
    }
    
    func getEntry(_ key:String) -> [String: AnyObject]? {
        return UserDefaults.standard.object(forKey: key) as? [String: AnyObject]
    }
    
    func remove(_ key:String) {
        UserDefaults.standard.set(nil, forKey: key)
    }
}
