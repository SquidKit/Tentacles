//
//  Endpoint+Result.swift
//  
//
//  Created by Donald Largen on 8/31/22.
//

import Foundation

public struct APIError: Error {
    public enum ErrorType {
        case http
        case encode
        case decode
    }
    
    public let errorType: ErrorType
    public let message: String?
    public let error: Error?
    public let response: Response?
    
    public init (
        errorType: ErrorType,
        message: String?,
        error: Error?,
        response: Response?) {
            
            self.errorType = errorType
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
            keyDecodingStrategy: JSONDecoder.KeyDecodingStrategy = .useDefaultKeys,
            completion: @escaping (Swift.Result<Output, APIError>)-> ())  {
            
                self.parameterArrayBehaviors = parameterArrayBehaviors
                self.get(
                    path,
                    parameters: parameters,
                    responseType: .json,
                    completion: self.handleResponse(dateFormatters: dateFormatters,
                                                    keyDecodingStrategy: keyDecodingStrategy,
                                                    completion: completion))
    }
    
    //post with no response.
   public func post<Input: Encodable>(path: String,
                                       body: Input,
                                       inputDateFormatter: DateFormatter,
                                       keyEncodingStrategy: JSONEncoder.KeyEncodingStrategy = .useDefaultKeys,
                                       completion: @escaping (Swift.Result<Void, APIError>) -> ()) {
        do {
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .formatted(inputDateFormatter)
            encoder.keyEncodingStrategy = keyEncodingStrategy
            let data = try encoder.encode(body)
            
            self.post(path,
                      parameterType: .custom("application/json"),
                      parameters: data,
                      responseType: .none,
                      completion: self.handleVoidResponse(completion: completion))
        }
        catch {
            completion(.failure(session.apiError(errorType: .encode, error: error, response: nil)))
        }
    }
    
    public func post<Input: Encodable, Output: Decodable >(path: String,
                                                           body: Input,
                                                           inputDateFormatter: DateFormatter,
                                                           dateFormatters: [DateFormatter],
                                                           keyEncodingStrategy: JSONEncoder.KeyEncodingStrategy = .useDefaultKeys,
                                                           keyDecodingStrategy: JSONDecoder.KeyDecodingStrategy = .useDefaultKeys,
                                                           completion: @escaping (Swift.Result<Output, APIError>) -> ()) {
        
        do {
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .formatted(inputDateFormatter)
            encoder.keyEncodingStrategy = keyEncodingStrategy
            let data = try encoder.encode(body)
            
            self.post(
                path,
                parameterType: .custom("application/json"),
                parameters: data,
                responseType: .json,
                completion: self.handleResponse(dateFormatters: dateFormatters,
                                                keyDecodingStrategy: keyDecodingStrategy,
                                                completion: completion))
        }
        catch {
            completion(.failure(session.apiError(errorType: .encode, error: error, response: nil)))
        }
    }

    public func put<Input: Encodable, Output: Decodable>(path: String,
                                                         body: Input,
                                                         inputDateFormatter: DateFormatter,
                                                         dateFormatters: [DateFormatter],
                                                         keyEncodingStrategy: JSONEncoder.KeyEncodingStrategy = .useDefaultKeys,
                                                         keyDecodingStrategy: JSONDecoder.KeyDecodingStrategy = .useDefaultKeys,
                                                         completion: @escaping (Swift.Result<Output, APIError>) -> ()) {
        
        do {
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .formatted(inputDateFormatter)
            encoder.keyEncodingStrategy = keyEncodingStrategy
            let data = try encoder.encode(body)
            
            self.put(
                path,
                parameterType: .custom("application/json"),
                parameters: data,
                completion: self.handleResponse(dateFormatters: dateFormatters,
                                                keyDecodingStrategy: keyDecodingStrategy,
                                                completion: completion))
        }
        catch {
            completion(.failure(session.apiError(errorType: .encode, error: error, response: nil)))
        }
    }

    public func put<Input: Encodable> (
        path: String,
        body: Input,
        inputDateFormatter: DateFormatter,
        keyEncodingStrategy: JSONEncoder.KeyEncodingStrategy = .useDefaultKeys,
        completion: @escaping (Swift.Result<Void, APIError>) -> ()) {
            
            do {
                let encoder = JSONEncoder()
                encoder.dateEncodingStrategy = .formatted(inputDateFormatter)
                encoder.keyEncodingStrategy = keyEncodingStrategy
                let data = try encoder.encode(body)
                
                self.put(
                    path,
                    parameterType: .custom("application/json"),
                    parameters: data,
                    completion: self.handleVoidResponse(completion: completion))
            }
            catch {
                completion(.failure(session.apiError(errorType: .encode, error: error, response: nil)))
            }
    }
    
    func patch <Input: Encodable, Output: Decodable> (
        path: String,
        body: Input,
        inputDateFormatter: DateFormatter,
        dateFormatters: [DateFormatter],
        keyDecodingStrategy: JSONDecoder.KeyDecodingStrategy = .useDefaultKeys,
        completion: @escaping (Swift.Result<Output, APIError>) -> ()) {
            
            do {
                let encoder = JSONEncoder()
                encoder.dateEncodingStrategy = .formatted(inputDateFormatter)
                let data = try encoder.encode(body)
                
                self.patch(
                    path,
                    parameterType: .custom("application/json"),
                    parameters: data,
                    responseType: .json,
                    completion: self.handleResponse(dateFormatters: dateFormatters,
                                                    keyDecodingStrategy: keyDecodingStrategy,
                                                    completion: completion))
            }
            catch {
                completion(.failure(session.apiError(errorType: .encode, error: error, response: nil)))
            }
    }
    
    public func patch <Output: Decodable> (
        path: String,
        dateFormatters: [DateFormatter],
        keyDecodingStrategy: JSONDecoder.KeyDecodingStrategy = .useDefaultKeys,
        completion: @escaping (Swift.Result<Output, APIError>) -> ()) {

            self.patch(
                path,
                parameterType: .json,
                parameters: nil,
                responseType: .json,
                completion:  self.handleResponse(dateFormatters: dateFormatters, 
                                                 keyDecodingStrategy: keyDecodingStrategy,
                                                 completion: completion))
    }
    
    public func delete<Input: Encodable> (
        path: String,
        body: Input,
        inputDateFormatter: DateFormatter,
        completion: @escaping (Swift.Result<Void, APIError>) -> ()) {
            
        do {
                let encoder = JSONEncoder()
                encoder.dateEncodingStrategy = .formatted(inputDateFormatter)
                let data = try encoder.encode(body)
                
                self.delete(
                    path,
                    parameterType: .custom("application/json"),
                    parameters: data,
                    responseType: .json,
                    completion: self.handleVoidResponse(completion: completion) )
            }
            catch {
                completion(.failure(session.apiError(errorType: .encode, error: error, response: nil)))
            }
    }
    
    public func delete (
        path: String,
        completion: @escaping (Swift.Result<Void, APIError>) -> ()) {
            self.delete(
                    path,
                    parameterType: .none,
                    parameters: nil,
                    responseType: .none,
                    completion: self.handleVoidResponse(completion: completion) )
    }
    
    private func handleVoidResponse (
        completion: @escaping ((Swift.Result<Void, APIError>)) -> () ) -> EndpointCompletion {
        return { [weak self] result in
            switch result {
            case .success( _ ):
                completion(.success(()))
            case .failure(let response, let error):
                print(error as Any)
                completion(.failure(
                    self.normalizedAPIError(errorType: .http, error: error, response: response)))
            }
        }
    }
        
    private func handleResponse<Output: Decodable>(
        dateFormatters: [DateFormatter],
        keyDecodingStrategy: JSONDecoder.KeyDecodingStrategy,
        completion: @escaping ((Swift.Result<Output, APIError>)) -> () ) -> EndpointCompletion {
            
        return { [weak self] result in
               switch result {
               case .success(let response):
                   do {
                       let output = try response.decoded(
                           Output.self,
                           dateFormatters: dateFormatters,
                           keyDecodingStrategy: keyDecodingStrategy)
                       completion(.success(output))
                   }
                   catch(let error) {
                       print(error)
                       completion(.failure(self.normalizedAPIError(errorType: .decode, error: error, response: response)))
                   }
               case .failure(let response, let error ):
                   print (error as Any)
                   completion(.failure(self.normalizedAPIError(errorType: .http, error: error, response: response)))
               }
           }
    }
}

public extension Optional where Wrapped == Endpoint {
    
    func normalizedAPIError(errorType: APIError.ErrorType, error: Error?, response: Response?) -> APIError {
        switch self {
        case .none:
            switch errorType {
            case .http, .encode:
                return APIError(errorType: errorType, message: error?.localizedDescription, error: error, response: response)
            case .decode:
                return APIError(errorType: errorType,
                                message: "An unexpected error occurred. Please try again later.\n\n[parsing error]",
                                error: error,
                                response: response)
            }
        case .some(let value):
            return value.session.apiError(errorType: .http, error: error, response: response)
        }
    }
}
