//
//  JSONEntity.swift
//  Tentacles
//
//  Created by Mike Leavy on 3/28/18.
//  Copyright © 2018 Squid Store. All rights reserved.
//

import Foundation

typealias JSONEntity = [String: Any]
enum JSON {
    
    case unknown
    case error(Error)
    case dictionary(Data, JSONEntity)
    case array(Data, [JSONEntity])
    
    var dictionary: JSONEntity {
        switch self {
        case .dictionary(_, let body):
            return body
        default:
            return JSONEntity()
        }
    }
    
    var array: [JSONEntity] {
        switch self {
        case .array(_, let body):
            return body
        default:
            return [JSONEntity]()
        }
    }
    
    var prettyString: String? {
        switch self {
        case .dictionary(_, let entity):
            return String.fromJSON(entity, pretty: true)
        case .array(_, let entity):
            return String.fromJSON(entity, pretty: true)
        default:
            return nil
        }
    }
    
    init(_ data: Data) {
        do {
            let json = try JSONSerialization.jsonObject(with: data, options: [])
            
            if let dictionary = json as? JSONEntity {
                self = .dictionary(data, dictionary)
            }
            else if let array = json as? [JSONEntity] {
                self = .array(data, array)
            }
            else {
                self = .unknown
            }
        }
        catch (let error) {
            print(error)
            self = .error(error)
        }
    }
    
    init(_ dictionary: JSONEntity) {
        do {
            let json = try JSONSerialization.data(withJSONObject: dictionary, options: [])
            self = .dictionary(json, dictionary)
        }
        catch (let error) {
            print(error)
            self = .error(error)
        }
    }
    
    init(_ array: [JSONEntity]) {
        do {
            let json = try JSONSerialization.data(withJSONObject: array, options: [])
            self = .array(json, array)
        }
        catch (let error) {
            print(error)
            self = .error(error)
        }
    }
}

public extension String {
    static func fromJSON(_ jsonObject:Any, pretty:Bool) -> String? {
        
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
}



