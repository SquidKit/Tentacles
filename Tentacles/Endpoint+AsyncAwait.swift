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
            
            return try await withTaskCancellationHandler(operation: {
                return try await withCheckedThrowingContinuation({ (continuation: CheckedContinuation<Output, Error>) -> Void in
                    self.get(
                        path: path,
                        parameters: parameters,
                        dateFormatters: dateFormatters) { result in
                            continuation.resume(with: result)
                        }
                })
            }, onCancel: {
                Tentacles.shared.logger?.log("Endpoint Get request canceled", level: .info)
                self.cancel()
            })
    }
    
    public func post<Input: Encodable, Output: Decodable >(
        path: String,
        body: Input,
        inputDateFormatter: DateFormatter,
        dateFormatters: [DateFormatter]) async throws -> Output {
            
            return try await withTaskCancellationHandler(operation: {
                return try await withCheckedThrowingContinuation({ (continuation: CheckedContinuation<Output, Error>) -> Void in
                    self.post(
                        path: path,
                        body: body,
                        inputDateFormatter: inputDateFormatter,
                        dateFormatters: dateFormatters) { result in
                            continuation.resume(with: result)
                        }
                })
            }, onCancel: {
                Tentacles.shared.logger?.log("Endpoint Post request canceled", level: .info)
                self.cancel()
            })
    }
    
    public func post<Input: Encodable >(
        path: String,
        body: Input,
        inputDateFormatter: DateFormatter ) async throws -> Void {
            
            return try await withTaskCancellationHandler(operation: {
                return try await withCheckedThrowingContinuation({ (continuation: CheckedContinuation<Void, Error>) -> Void in
                    self.post(
                        path: path,
                        body: body,
                        inputDateFormatter: inputDateFormatter) { result in
                            continuation.resume(with: result)
                        }
                })
            }, onCancel: {
                Tentacles.shared.logger?.log("Endpoint Post request canceled", level: .info)
                self.cancel()
            } )
    }
    
    public func put<Input: Encodable, Output: Decodable>(
        path: String,
        body: Input,
        inputDateFormatter: DateFormatter,
        dateFormatters: [DateFormatter] ) async throws -> Output {
            
            return try await withTaskCancellationHandler(operation: {
                return try await withCheckedThrowingContinuation({ (continuation: CheckedContinuation<Output, Error>) -> Void in
                    self.put(
                        path: path,
                        body: body,
                        inputDateFormatter: inputDateFormatter,
                        dateFormatters: dateFormatters) { result in
                            continuation.resume(with: result)
                        }
                })
            }, onCancel: {
                Tentacles.shared.logger?.log("Endpoint Put request canceled", level: .info)
                self.cancel()
            } )
    }
    
    public func put<Input: Encodable> (
        path: String,
        body: Input,
        inputDateFormatter: DateFormatter ) async throws -> Void {
            
            return try await withTaskCancellationHandler(operation: {
                return try await withCheckedThrowingContinuation({ (continuation: CheckedContinuation<Void, Error>) -> Void in
                    self.put(
                        path: path,
                        body: body,
                        inputDateFormatter: inputDateFormatter ) { result in
                            continuation.resume(with: result)
                        }
                })
            }, onCancel: {
                Tentacles.shared.logger?.log("Endpoint Put request canceled", level: .info)
                self.cancel()
            })
    }
    
    public func patch <Input: Encodable, Output: Decodable> (
        path: String,
        body: Input,
        inputDateFormatter: DateFormatter,
        dateFormatters: [DateFormatter] ) async throws -> Output {
            
            return try await withTaskCancellationHandler(operation: {
                return try await withCheckedThrowingContinuation({ (continuation: CheckedContinuation<Output, Error>) -> Void in
                    self.patch(
                        path: path,
                        body: body,
                        inputDateFormatter: inputDateFormatter,
                        dateFormatters: dateFormatters) { result in
                            continuation.resume(with: result)
                        }
                })
            }, onCancel: {
                Tentacles.shared.logger?.log("Endpoint Patch request canceled", level: .info)
                self.cancel()
            } )
    }
    
    public func patch<Output: Decodable> (
        path: String,
        dateFormatters: [DateFormatter] ) async throws -> Output {
            
            return try await withTaskCancellationHandler(operation: {
                return try await withCheckedThrowingContinuation({ (continuation: CheckedContinuation<Output, Error>) -> Void in
                    self.patch(
                        path: path,
                        dateFormatters: dateFormatters) { result in
                            continuation.resume(with: result)
                        }
                })
            }, onCancel: {
                Tentacles.shared.logger?.log("Endpoint Patch request canceled", level: .info)
                self.cancel()
            } )
    }
    
    public func delete<Input: Encodable> (
        path: String,
        body: Input,
        inputDateFormatter: DateFormatter ) async throws -> Void {
            
            return try await withTaskCancellationHandler(operation: {
                return try await withCheckedThrowingContinuation({ (continuation: CheckedContinuation<Void, Error>) -> Void in
                    self.delete(
                        path: path,
                        body: body,
                        inputDateFormatter: inputDateFormatter ) { result in
                            continuation.resume(with: result)
                        }
                })
            }, onCancel: {
                Tentacles.shared.logger?.log("Endpoint Delete request canceled", level: .info)
                self.cancel()
            })
    }
    
    public func delete (path: String ) async throws -> Void {
            
        return try await withTaskCancellationHandler(operation: {
                return try await withCheckedThrowingContinuation({ (continuation: CheckedContinuation<Void, Error>) -> Void in
                    self.delete(
                        path: path) { result in
                            continuation.resume(with: result)
                        }
                })
            }, onCancel: {
                Tentacles.shared.logger?.log("Endpoint Delete request canceled", level: .info)
                self.cancel()
            })
    }
    
}

