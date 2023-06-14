//
//  URL+Tentacles.swift
//  Tentacles
//
//  Created by Mike Leavy on 2/20/19.
//  Copyright © 2019 Squid Store. All rights reserved.
//

import UIKit

public extension URL {
    var queryDictionary: [String: String]? {
        guard let query = self.query else { return nil}
        
        var queryStrings = [String: String]()
        for pair in query.components(separatedBy: "&") {
            
            let key = pair.components(separatedBy: "=")[0]
            
            let value = pair
                .components(separatedBy:"=")[1]
                .replacingOccurrences(of: "+", with: " ")
                .removingPercentEncoding ?? ""
            
            queryStrings[key] = value
        }
        return queryStrings
    }
    
    var sortedQueryKeyValuePairs: [(String, String)]? {
        guard let dictionary = queryDictionary else {return nil}
        
        var keyValuePairs = [(String, String)]()
        dictionary.forEach { (element) in
            keyValuePairs.append((element.key, element.value))
        }
        keyValuePairs.sort { (first, second) -> Bool in
            return first.0 < second.0
        }
        
        return keyValuePairs
    }
    
    func throttleQuery(ignoredQueryKeys: [String]?) -> String {
        guard let sortedQuery = sortedQueryKeyValuePairs else {return ""}
        var query = ""
        for item in sortedQuery {
            if let ignoredQueryKeys, ignoredQueryKeys.contains(where: { key in
                return key.lowercased() == item.0.lowercased()
            }) {
                continue
            }
            if query.count > 0 {
                query += "&"
            }
            query += item.0
            query += "="
            query += item.1
        }
        return "?" + query
    }
    
    func throttledName(ignoredQueryKeys: [String]?) -> String {
        var name = (host ?? "") + path
        if let ignoredQueryKeys, ignoredQueryKeys.contains("*") {
            return name
        }
        else {
            name += throttleQuery(ignoredQueryKeys: ignoredQueryKeys)
            return name
        }
    }
}
