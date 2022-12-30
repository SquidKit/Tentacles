//
//  File.swift
//  
//
//  Created by Donald Largen on 12/29/22.
//

import Foundation

extension Error {
    public var APIError: APIError? {
        return self as? APIError
    }
}


extension Endpoint {
    
    public func get<Output: Codable> (
        path: String,
        parameterType: Endpoint.ParameterType = .json,
        parameterArrayBehaviors: Endpoint.ParameterArrayBehaviors = [.repeat: []],
        parameters: [String: Any]?,
        dateFormatters: [DateFormatter]) async throws -> Output {
            
            return try await withCheckedThrowingContinuation({ (continuation: CheckedContinuation<Output, Error>) -> Void in
                self.get(
                    path: path,
                    parameters: nil,
                    dateFormatters: dateFormatters) { result in
                        continuation.resume(with: result)
                    }
            })
            
    }
    
    public func post<Input: Encodable, Output: Decodable >(
        path: String,
        body: Input,
        inputDateFormatter: DateFormatter,
        dateFormatters: [DateFormatter]) async throws -> Output {
            
            return try await withCheckedThrowingContinuation({ (continuation: CheckedContinuation<Output, Error>) -> Void in
                self.post(
                    path: path,
                    body: body,
                    inputDateFormatter: inputDateFormatter,
                    dateFormatters: dateFormatters) { result in
                        continuation.resume(with: result)
                    }
            })
    }
    
    public func post<Input: Encodable >(
        path: String,
        body: Input,
        inputDateFormatter: DateFormatter ) async throws -> Void {
            
            return try await withCheckedThrowingContinuation({ (continuation: CheckedContinuation<Void, Error>) -> Void in
                self.post(
                    path: path,
                    body: body,
                    inputDateFormatter: inputDateFormatter) { result in
                        continuation.resume(with: result)
                    }
            })
    }
    
    public func put<Input: Encodable, Output: Decodable>(
        path: String,
        body: Input,
        inputDateFormatter: DateFormatter,
        dateFormatters: [DateFormatter] ) async throws -> Output {
            
            return try await withCheckedThrowingContinuation({ (continuation: CheckedContinuation<Output, Error>) -> Void in
                self.put(
                    path: path,
                    body: body,
                    inputDateFormatter: inputDateFormatter,
                    dateFormatters: dateFormatters) { result in
                        continuation.resume(with: result)
                    }
            })
    }
    
    public func put<Input: Encodable> (
        path: String,
        body: Input,
        inputDateFormatter: DateFormatter ) async throws -> Void {
            
            return try await withCheckedThrowingContinuation({ (continuation: CheckedContinuation<Void, Error>) -> Void in
                self.put(
                    path: path,
                    body: body,
                    inputDateFormatter: inputDateFormatter ) { result in
                        continuation.resume(with: result)
                    }
            })
    }
    
    public func patch <Input: Encodable, Output: Decodable> (
        path: String,
        body: Input,
        inputDateFormatter: DateFormatter,
        dateFormatters: [DateFormatter] ) async throws -> Output {
            
            return try await withCheckedThrowingContinuation({ (continuation: CheckedContinuation<Output, Error>) -> Void in
                self.put(
                    path: path,
                    body: body,
                    inputDateFormatter: inputDateFormatter,
                    dateFormatters: dateFormatters) { result in
                        continuation.resume(with: result)
                    }
            })
        }
    
}

