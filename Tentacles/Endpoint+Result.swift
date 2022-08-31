//
//  Endpoint+Result.swift
//  
//
//  Created by Donald Largen on 8/31/22.
//

import Foundation

public struct APIError: Error {
    public let message: String?
    public let error: Error?
    public let response: Response?
    
    public init(
        message: String? = nil,
        error: Error? = nil,
        response: Response? = nil) {
            
            self.message = message
            self.error = error
            self.response = response
    }
}

extension Endpoint {
    
  public func get<Output: Codable>(
            path: String,
            parameterType: Endpoint.ParameterType = .json,
            parameterArrayBehaviors: Endpoint.ParameterArrayBehaviors = [.repeat: []],
            parameters: [String: Any]?,
            dateFormatters: [DateFormatter],
            completion: @escaping (Swift.Result<Output, APIError>) -> ())  {
            
                self.parameterArrayBehaviors = parameterArrayBehaviors
                self.get(
                    path,
                    parameters: parameters,
                    responseType: .json,
                    completion: self.handleResponse(
                        dateFormatters: dateFormatters,
                        completion: completion))
    }
    
    //post with no response.
   public func post<Input: Encodable> (
        path: String,
        body: Input,
        dateFormatter: DateFormatter,
        completion: @escaping (Swift.Result<Void, APIError>) -> ()) {
            
            do {
                let encoder = JSONEncoder()
                encoder.dateEncodingStrategy = .formatted(dateFormatter)
                let data = try encoder.encode(body)
                
                self.post(
                    path,
                    parameterType: .custom("application/json"),
                    parameters: data,
                    responseType: .json,
                    completion: self.handleResponse(completion: completion))
            }
            catch {
                completion(.failure(APIError(message: error.localizedDescription)))
            }
    }
    
    public func post<Input: Encodable, Output: Decodable >(
        path: String,
        body: Input,
        dateFormatter: DateFormatter,
        completion: @escaping (Swift.Result<Output, APIError>) -> ()) {
            
            do {
                let encoder = JSONEncoder()
                encoder.dateEncodingStrategy = .formatted(dateFormatter)
                let data = try encoder.encode(body)
                
                self.post(
                    path,
                    parameterType: .custom("application/json"),
                    parameters: data,
                    responseType: .json,
                    completion: self.handleResponse(dateFormatters: [dateFormatter], completion: completion))
            }
            catch {
                completion(.failure(APIError(message: error.localizedDescription)))
            }
    }

    public func put<Input: Encodable, Output: Decodable>(
        path: String,
        body: Input,
        dateFormatter: DateFormatter,
        completion: @escaping (Swift.Result<Output, APIError>) -> ()) {
        
            do {
                let encoder = JSONEncoder()
                encoder.dateEncodingStrategy = .formatted(dateFormatter)
                let data = try encoder.encode(body)
                
                self.put(
                    path,
                    parameterType: .custom("application/json"),
                    parameters: data,
                    completion: self.handleResponse(
                        dateFormatters: [dateFormatter],
                        completion: completion))
            }
            catch {
                completion(.failure(APIError(message: error.localizedDescription)))
            }
    }

    public func put<Input: Encodable> (
        path: String,
        body: Input,
        dateFormatter: DateFormatter,
        completion: @escaping (Swift.Result<Void, APIError>) -> ()) {
            
            do {
                let encoder = JSONEncoder()
                encoder.dateEncodingStrategy = .formatted(dateFormatter)
                let data = try encoder.encode(body)
                
                self.put(
                    path,
                    parameterType: .custom("application/json"),
                    parameters: data,
                    completion: self.handleResponse(completion: completion))
            }
            catch {
                completion(.failure(APIError(message: error.localizedDescription)))
            }
    }
    
    private func handleResponse(
        completion: @escaping ((Swift.Result<Void, APIError>)) -> () ) -> EndpointCompletion {
        return { result in
            switch result {
            case .success( _ ):
                completion(.success(()))
            case .failure(let response, let error):
                print(error as Any)
                completion(.failure(
                    APIError(
                        message: error?.localizedDescription,
                        error: error,
                        response: response)))
            }
        }
    }
        
    private func handleResponse<Output: Decodable>(
        dateFormatters: [DateFormatter],
        completion: @escaping ((Swift.Result<Output, APIError>)) -> () ) -> EndpointCompletion {
            
        return { result in
               switch result {
               case .success(let response):
                   do {
                       let output = try response.decoded(
                           Output.self,
                           dateFormatters: dateFormatters )
                       completion(.success(output))
                   }
                   catch(let error) {
                       print(error)
                       completion(.failure(APIError(
                            message:"An unexpected error occurred. Please try again later.\n\n[parsing error]",
                            error: error,
                            response: nil)))
                   }
               case .failure(let response, let error ):
                   print (error as Any)
                   completion(.failure(APIError(
                        message: error?.localizedDescription,
                        error: error,
                        response: response)))
               }
           }
    }
}
