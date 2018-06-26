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
    
    public static func deserializeJSON(_ jsonObject:Any, pretty:Bool) -> String? {
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
        return result
    }
    
    init?(jsonObject:Any, pretty:Bool) {
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
}
