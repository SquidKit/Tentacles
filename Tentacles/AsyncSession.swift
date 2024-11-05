//
//  AsyncSession.swift
//  Tentacles
//
//  Created by Donald Largen on 1/6/23.
//  Copyright © 2023 Squid Store. All rights reserved.
//

import Foundation

open class AsyncSession: NSObject {
    
    private let sessionConfiguration: Session.SessionConfiguration
    private lazy var urlSession: URLSession = {
        return URLSession(configuration: urlSessionConfiguration,
                          delegate: self,
                          delegateQueue: nil)
    }()
    
    private var progressHandler: EndpointProgress?
    
    public var unauthorizedStatusCodes: [HTTPStatusCode] = [.unauthorized, .forbidden]
    public var disabledRequestTypes = Set<Endpoint.RequestType>()
    public var throttle: Throttle?
    public var environmentManager: EnvironmentManager?
    public var environment: Environment?
    public var urlSessionConfiguration: URLSessionConfiguration
    
    public var host: String? {
        get {
            if let manager = environmentManager, let env = environment {
                return manager.host(for: env) ?? sessionConfiguration.host
            }
            return sessionConfiguration.host
        }
    }
    
    public  var scheme: String {
        get {
            if let manager = environmentManager, let env = environment {
                return manager.scheme(for: env) 
            }
            return sessionConfiguration.scheme
        }
    
    }
    
    init (sessionConfiguration: Session.SessionConfiguration ) {
        self.sessionConfiguration = sessionConfiguration
        self.urlSessionConfiguration = URLSessionConfiguration.default
        super.init()
    }
    
    open func get<Output: Codable> (
        path: String,
        parameterType: Endpoint.ParameterType = .json,
        parameterArrayBehaviors: Endpoint.ParameterArrayBehaviors = [.repeat: []],
        parameters: [String: Any]?,
        dateFormatters: [DateFormatter] ) async throws -> Output {
            
            let request = try self.setupRequest(
                path: path,
                requestType: .get,
                responseType: .json,
                parameterType: parameterType,
                parameterArrayBehaviors: parameterArrayBehaviors,
                parameters: parameters)
            
            let (data, urlResponse)  = try await self.urlSession.data(for: request, delegate: self)
            
            return try handleResponse(
                data: data,
                urlResponse: urlResponse,
                dateFormatters: dateFormatters)
    }
            
    open func put<Input: Encodable, Output: Decodable>(
        path: String,
        body: Input,
        inputDateFormatter: DateFormatter,
        dateFormatters: [DateFormatter] ) async throws -> Output {
            
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .formatted(inputDateFormatter)
            let putData = try encoder.encode(body)
            
            let request = try self.setupRequest(
                path: path,
                requestType: .put,
                responseType: .json,
                parameterType: .custom("application/json"),
                parameterArrayBehaviors: [:],
                parameters: putData)
            
            do {
                let (data, urlResponse)  = try await self.urlSession.data(for: request, delegate: self)
                return try handleResponse(
                    data: data,
                    urlResponse: urlResponse,
                    dateFormatters: dateFormatters)
            }
            catch {
                print (error)
                throw error
            }
            
    }
    
    open func post<Input: Encodable, Output: Decodable>(path: String,
                                                        body: Input,
                                                        inputDateFormatter: DateFormatter,
                                                        dateFormatters: [DateFormatter] ) async throws -> Output {
            
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .formatted(inputDateFormatter)
        let postData = try encoder.encode(body)
        
        let request = try self.setupRequest(path: path,
                                            requestType: .post,
                                            responseType: .json,
                                            parameterType: .custom("application/json"),
                                            parameterArrayBehaviors: [:],
                                            parameters: postData)
        
        do {
            let (data, urlResponse)  = try await self.urlSession.data(for: request, delegate: self)
            return try handleResponse(data: data,
                                      urlResponse: urlResponse,
                                      dateFormatters: dateFormatters)
        }
        catch {
            print (error)
            throw error
        }
    }
    
    open func download (_ path: String,
                        parameters: Any?,
                        progress: EndpointProgress?) async throws -> Data {
        progressHandler = progress
            
        let parameterType: Endpoint.ParameterType = parameters != nil ? .formURLEncoded : .none
        let requestType = Endpoint.RequestType.get
        let responseType = Endpoint.ResponseType.data
        
        let request = try self.setupRequest(path: path,
                                            requestType: requestType,
                                            responseType: responseType,
                                            parameterType: parameterType,
                                            parameters: nil)
         
        let (asyncBytes, urlResponse) = try await self.urlSession.bytes(for: request)
        
        let httpResponse = try validateResponse(urlResponse: urlResponse)
        let expectedLength = (httpResponse.expectedContentLength)
        var bytesWritten: Int64 = 0
        var data = Data()
        data.reserveCapacity(Int(expectedLength))

        for try await byte in asyncBytes {
            data.append(byte)
            if let progress = self.progressHandler {
                bytesWritten += 1
                let percentComplete = Double(bytesWritten) / Double(expectedLength)
                self.notifyProgress(
                    progressHandler: progress,
                    bytesWritten: bytesWritten,
                    totalBytesExpectedToWrite: expectedLength,
                    percentComplete: percentComplete )
            }
        }

        progressHandler = nil
        return data
    }
    
   
}

//Mark Private Methods
extension AsyncSession {
    
    private func composedURL(_ path: String) -> URL? {
        let composedPath = path.environmentalized(manager: environmentManager, environment: environment)
        // path may be a fully qualified URL string - check for that
        if let precomposed = URL(string: composedPath) {
            if precomposed.scheme != nil && precomposed.host != nil {
                return precomposed
            }
        }
        
        let urlString = sessionConfiguration.scheme + "://" + sessionConfiguration.host
        guard let url = URL(string: urlString) else {return nil}
        return url.appendingPathComponent(composedPath)
    }
    
    private func urlError() -> Error {
        let error = NSError.tentaclesError(code: URLError.badURL.rawValue, localizedDescription: "Bad URL")
        return error
    }
    
    private func setupRequest(path: String,
                              requestType: Endpoint.RequestType,
                              responseType: Endpoint.ResponseType,
                              parameterType: Endpoint.ParameterType,
                              parameterArrayBehaviors: Endpoint.ParameterArrayBehaviors = [:],
                              parameters: Any?) throws ->  URLRequest {
        
        // check for simulated offline mode
        if Tentacles.shared.networkingMode == .simulatedOffline {
            throw URLError(.notConnectedToInternet)
        }
        
        guard let url = composedURL(path) else {
            throw URLError(
                .badURL,
                userInfo: [NSURLErrorFailingURLStringErrorKey: path])
        }
        
        if disabledRequestTypes.contains(requestType) {
            throw NSError.tentaclesError(
                code: .requestTypeDisabledError,
                localizedDescription: "The \(requestType.rawValue) request type has been disabled by the client" )
        }

        let request  = try URLRequest(url: url,
                                      cachePolicy: URLRequest.CachePolicy.useProtocolCachePolicy,
                                      timeoutInterval: sessionConfiguration.timeout ?? 60.0,
                                      authorizationHeaderKey: sessionConfiguration.authorizationHeaderKey,
                                      authorizationHeaderValue: sessionConfiguration.authorizationHeaderValue,
                                      authorizationBearerToken: sessionConfiguration.authorizationBearerToken,
                                      headers: sessionConfiguration.headers,
                                      requestType: requestType,
                                      parameterType: parameterType,
                                      parameterArrayBehaviors: parameterArrayBehaviors,
                                      responseType: Endpoint.ResponseType.data,
                                      parameters: parameters,
                                      cachingStore: nil )
        
        // check for throttled
        if let throttle = throttle,
               let url = request.url,
                   Throttler.shared.throttled(url: url, throttle: throttle) {
                   
            throw NSError.tentaclesError(code: .throttled,
                                         localizedDescription: "The \(url.absoluteString) is being throttled by the client" )
       }
        
        return request
    }
    
    @discardableResult
    private func validateResponse(urlResponse: URLResponse) throws -> HTTPURLResponse {
        
        guard let httpResponse = urlResponse as? HTTPURLResponse else {
            throw NSError.tentaclesError(code: .failedToProcess,
                                         localizedDescription: "The response is not of type HTTPURLResponse.  Can't continue to process")
        }
        
        guard let statusCode = HTTPStatusCode(rawValue: httpResponse.statusCode) else {
            throw NSError.tentaclesError(code: .failedToProcess,
                                         localizedDescription: "The http status is code not recognized.  Can't continue to process")
        }
        
        if statusCode.responseType != .success {
            if unauthorizedStatusCodes.contains(statusCode) {
                throw NSError.tentaclesError(code: .unauthorized,
                                             localizedDescription: "Server responsed with an unauthorized status code \(statusCode)")
            }
            //HttpStatusCode is an error, thus it can be thrown.
            throw statusCode
        }
        
        return httpResponse
    }
    
    private func handleResponse<Output: Decodable>(data: Data,
                                                   urlResponse: URLResponse,
                                                   dateFormatters: [DateFormatter] )  throws -> Output {
            try validateResponse(urlResponse: urlResponse)
            
            let response = Response(data: data,
                                    urlResponse: urlResponse)
            
            let decoded = try response.decoded(Output.self,
                                               dateFormatters: dateFormatters )
            
            return decoded
    }
    
    private func notifyProgress(progressHandler: EndpointProgress,
                                bytesWritten: Int64,
                                totalBytesExpectedToWrite: Int64,
                                percentComplete: Double) {
    
        guard let progressHandler = self.progressHandler else { return }
        DispatchQueue.main.async {
            progressHandler(bytesWritten,
                            bytesWritten,
                            totalBytesExpectedToWrite,
                            percentComplete)
        }
    }
}


extension AsyncSession : URLSessionDelegate {}

extension AsyncSession: URLSessionDataDelegate {}

extension AsyncSession:  URLSessionTaskDelegate {}

extension AsyncSession: URLSessionDownloadDelegate {
    public func urlSession(_ session: URLSession,
                           downloadTask: URLSessionDownloadTask,
                           didFinishDownloadingTo location: URL) {
            //no op.  Async methods handle this
    }
    
    public func urlSession(_ session: URLSession,
                           downloadTask: URLSessionDownloadTask,
                           didWriteData bytesWritten: Int64,
                           totalBytesWritten: Int64,
                           totalBytesExpectedToWrite: Int64) {
            
        if let progressHandler = self.progressHandler {
            var percentComplete: Double?
            if totalBytesExpectedToWrite != NSURLSessionTransferSizeUnknown {
                percentComplete = Double(totalBytesWritten) / Double(totalBytesExpectedToWrite)
            }
            
            DispatchQueue.main.async {
                progressHandler(bytesWritten,
                                totalBytesWritten,
                                totalBytesExpectedToWrite,
                                percentComplete)
            }
        }
    }
}
