//
//  URL+Tentacles.swift
//  Tentacles
//
//  Created by Mike Leavy on 2/20/19.
//  Copyright © 2019 Squid Store. All rights reserved.
//

import UIKit

public extension URL {
    public var queryDictionary: [String: String]? {
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
    
    public var sortedQueryKeyValuePairs: [(String, String)]? {
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
}
