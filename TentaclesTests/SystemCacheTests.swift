//
//  SystemCacheTests.swift
//  TentaclesTests
//
//  Created by Mike Leavy on 3/31/18.
//  Copyright © 2018 Squid Store. All rights reserved.
//

import XCTest
@testable import Tentacles

class SystemCacheTests: XCTestCase {
    
    let parameterType: Endpoint.ParameterType = .none
    let requestType: Endpoint.RequestType = .get
    let responseType: Endpoint.ResponseType = .json
    let path = "get"
    
    override func setUp() {
        super.setUp()
        
        Session.shared.host = "httpbin.org"
    }
    
    override func tearDown() {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
        super.tearDown()
    }
    
    private func configSession(for systemPolicy: URLRequest.CachePolicy)  {
        var systemCacheConfiguration = Session.SystemCacheConfiguration.default
        systemCacheConfiguration.requestCachePolicy = systemPolicy
        let systemCachingStore = Session.CachingStore.system(systemCacheConfiguration)
        
        Session.shared = Session(cachingStore: systemCachingStore)
        Session.shared.host = "httpbin.org"
    }

    
    func testIgnoringLocalCacheData() {
        configSession(for: .reloadIgnoringLocalAndRemoteCacheData)
        Session.shared.urlCache?.removeAllCachedResponses()
        
        guard let url = Session.shared.composedURL(path) else {
            XCTFail()
            return
        }
        
        do {
            let request = try URLRequest(
                url: url,
                cachePolicy: URLRequest.CachePolicy.useProtocolCachePolicy,
                timeoutInterval: Session.shared.timeout,
                authorizationHeaderKey: nil,
                authorizationHeaderValue: nil,
                authorizationBearerToken: nil,
                headers: nil,
                requestType: requestType,
                parameterType: parameterType,
                parameterArrayBehaviors: [:],
                responseType: responseType,
                parameters: nil,
                cachingStore: Session.shared.cachingStore )
            
            let expectation = XCTestExpectation(description: "")
            
            Endpoint().get(path) { [weak self] (result) in
                switch result {
                case .success(let response):
                    let postRequest = Session.shared.urlCache?.cachedResponse(for: request)
                    XCTAssertNotNil(postRequest, "Expected a valid cached response")
                    
                    print(response.jsonDictionary)
                    
                    self?.doPostResponseHandler(request: request, equivalenceExpected: false, completion: { (testMet) in
                        XCTAssertTrue(testMet, "Equivalnce test failed")
                        expectation.fulfill()
                    })
                    
                    
                case .failure(_, _):
                    XCTFail()
                }
            }
            
            
            wait(for: [expectation], timeout: TentaclesTests.timeout * 2)
        }
        catch {
            XCTFail()
            return
        }
    }
    
    func testCacheElseLoad() {
        configSession(for: .returnCacheDataElseLoad)
        Session.shared.urlCache?.removeAllCachedResponses()
        
        guard let url = Session.shared.composedURL(path) else {
            XCTFail()
            return
        }
        
        do {
            
            let request = try  URLRequest(
                url: url,
                cachePolicy: URLRequest.CachePolicy.useProtocolCachePolicy,
                timeoutInterval: Session.shared.timeout,
                authorizationHeaderKey: nil,
                authorizationHeaderValue: nil,
                authorizationBearerToken: nil,
                headers: nil,
                requestType: requestType,
                parameterType: parameterType,
                parameterArrayBehaviors: [:],
                responseType: responseType,
                parameters: nil,
                cachingStore: Session.shared.cachingStore )
            
           let expectation = XCTestExpectation(description: "")
            
            Endpoint().get(self.path) { [weak self] (result) in
                switch result {
                case .success(let response):
                    let postRequest = Session.shared.urlCache?.cachedResponse(for: request)
                    XCTAssertNotNil(postRequest, "Expected a valid cached response")
                    
                    print(response.jsonDictionary)
                    
                    self?.doPostResponseHandler(request: request, equivalenceExpected: true, completion: { (testMet) in
                        XCTAssertTrue(testMet, "Equivalnce test failed")
                        expectation.fulfill()
                    })
                    
                    
                case .failure(_, _):
                    XCTFail()
                }
                
            }
            
            
            self.wait(for: [expectation], timeout: TentaclesTests.timeout * 2)
        }
        catch {
            XCTFail()
            return
        }
    }
    
    typealias PostResponseCompletion = (_ testMet: Bool) -> Void
    func doPostResponseHandler(request: URLRequest, equivalenceExpected: Bool, completion: @escaping PostResponseCompletion) {
        let preRequest = Session.shared.urlCache?.cachedResponse(for: request)
        print("\n\n\n")
        preRequest?.printResponse()
        print("\n\n\n")
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            
            var equivalncyTestMet = false
            
            Endpoint().get(self.path) { (result) in
                switch result {
                case .success(let response):
                    let postRequest = Session.shared.urlCache?.cachedResponse(for: request)
                    
                    print("\n\n\n")
                    postRequest?.printResponse()
                    print("\n\n\n")
                    
                    if let pre = preRequest {
                        let equal = pre.isEquivelant(postRequest!)
                        equivalncyTestMet = (equal == equivalenceExpected)
                    }
                    print(response.jsonDictionary)
                case .failure(_, _):
                    break
                }
                completion(equivalncyTestMet)
            }
            
        }
    }
    
}

extension CachedURLResponse {
    
    func printResponse() {
        print(data)
        switch storagePolicy {
        case .allowed:
            print("storage policy: allowed")
        case .allowedInMemoryOnly:
            print("storage policy: allowedInMemoryOnly")
        case .notAllowed:
            print("storage policy: notAllowed")
        @unknown default:
            fatalError()
        }
        print(response)
    }
    
    func isEquivelant(_ other: CachedURLResponse) -> Bool {
        guard let httpResponse = response as? HTTPURLResponse else {return false}
        guard let otherHttpResponse = other.response as? HTTPURLResponse else {return false}
        guard data == other.data else {return false}
        
        var equal = true
        for (key, value) in httpResponse.allHeaderFields {
            if let object = value as? NSObject {
                if let otherObject = otherHttpResponse.allHeaderFields[key] as? NSObject {
                    if object != otherObject {
                        equal = false
                        break
                    }
                }
            }
        }
        
        return equal
    }
    
}

