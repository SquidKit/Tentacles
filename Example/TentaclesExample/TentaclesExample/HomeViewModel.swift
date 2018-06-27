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
    
    var environmentManager = EnvironmentManager()
    
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
        do {
            try environmentManager.loadEnvironments(resourceFileName: "Environments.json")
        }
        catch {
            print("Failed to load Environments JSON file")
        }
    }
    
    var endpointHosts: [String] {
        return environmentManager.allHosts
    }
    
    var activeHosts: [String] {
        return environmentManager.allActiveHosts
    }
    
    func host(for environmentName: String) -> String {
        return environmentManager.host(for: environmentName) ?? "host not fount"
    }
}

