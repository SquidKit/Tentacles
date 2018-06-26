//
//  NSDictionary+Tentacles.swift
//  Tentacles
//
//  Created by Mike Leavy on 6/26/18.
//  Copyright © 2018 Squid Store. All rights reserved.
//

import Foundation

public extension NSDictionary {
    
    public class func dictionaryFromResourceFile(_ fileName:String) -> NSDictionary? {
        guard let inputStream = InputStream(fileAtPath: String.stringWithPathToResourceFile(fileName)) else {return nil}
        inputStream.open()
        
        let dictionary = try? JSONSerialization.jsonObject(with: inputStream, options:JSONSerialization.ReadingOptions(rawValue: 0))
        
        inputStream.close()
        
        return dictionary as? NSDictionary
    }
}
