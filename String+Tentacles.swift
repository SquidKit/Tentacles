//
//  String+Tentacles.swift
//  Tentacles
//
//  Created by Mike Leavy on 6/26/18.
//  Copyright © 2018 Squid Store. All rights reserved.
//

import Foundation

public extension String {
    public static func stringWithPathToResourceDirectory() -> String {
        return Bundle.main.resourcePath!
    }
    
    public static func stringWithPathToResourceFile(_ fileName:String) -> String {
        let path = String.stringWithPathToResourceDirectory()
        var url = URL(fileURLWithPath: path)
        url = url.appendingPathComponent(fileName)
        return url.path
    }
}
