//
//  String+Tentacles.swift
//  Tentacles
//
//  Created by Mike Leavy on 6/26/18.
//  Copyright © 2018 Squid Store. All rights reserved.
//

import Foundation

public extension String {
    init?(jsonObject: Any, pretty: Bool) {
        var result:String?
        
        if JSONSerialization.isValidJSONObject(jsonObject) {
            let outputStream:OutputStream = OutputStream.toMemory()
            outputStream.open()
            var error:NSError?
            let bytesWritten:Int = JSONSerialization.writeJSONObject(jsonObject, to: outputStream, options: pretty ? JSONSerialization.WritingOptions.prettyPrinted : JSONSerialization.WritingOptions(rawValue: 0), error: &error)
            outputStream.close()
            
            if bytesWritten > 0 {
                if let data:Data = outputStream.property(forKey: Stream.PropertyKey.dataWrittenToMemoryStreamKey) as? Data {
                    result = NSString(data: data, encoding: String.Encoding.utf8.rawValue) as String?
                }
            }
        }
        
        guard let string = result else {return nil}
        self.init(string)
    }
    
    func environmentalized(manager: EnvironmentManager?, environment: Environment?) -> String {
        if let manager = manager, let environment = environment {
            return manager.replaceVariables(in: self, for: environment)
        }
        return self
    }
}
