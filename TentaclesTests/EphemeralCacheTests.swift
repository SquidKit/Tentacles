//
//  EphemeralCacheTests.swift
//  TentaclesTests
//
//  Created by Mike Leavy on 4/3/18.
//  Copyright © 2018 Squid Store. All rights reserved.
//

import XCTest
@testable import Tentacles

class EphemeralCacheTests: XCTestCase {
    
    let parameterType: Endpoint.ParameterType = .none
    let requestType: Endpoint.RequestType = .get
    let responseType: Endpoint.ResponseType = .json
    let path = "get"
    
    override func setUp() {
        super.setUp()
        Session.shared.host = "httpbin.org"
        Session.shared.cachingStore = .tentaclesEphemeral
    }
    
    override func tearDown() {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
        super.tearDown()
    }
    
    func testCache() {
        let dataString = "tentacles test"
        let data = dataString.data(using: .utf8)!
        let now = Date()
        let itemToCache = CachedResponse(code: 0, object: data, timestamp: now)
        
        guard let url = Session.shared.composedURL(path) else {
            XCTFail()
            return
        }
        
        print(url.absoluteString)
        
        guard let request = try? URLRequest(url: url, cachePolicy: URLRequest.CachePolicy.useProtocolCachePolicy, timeoutInterval: Session.shared.timeout, requestType: requestType, parameterType: parameterType, parameterArrayBehaviors: [:], responseType: responseType, parameters: nil, session: Session.shared) else {
            XCTFail()
            return
        }
        
        TentaclesEphemeralCache.shared.cache(data: itemToCache, request: request)
        
        guard let cachedItem = TentaclesEphemeralCache.shared.cached(request: request) else {
            XCTFail()
            return
        }
        
        XCTAssertEqual(cachedItem.timestamp, now, "expected timestamp to match stored timestamp")
        
        let key = url.cacheName(includeQuery: true)
        let object = TentaclesEphemeralCache.shared.cache.object(forKey: key as NSString)
        XCTAssertNotNil(object)
    }
    
    func testGetCache() {
        
        guard let initialURL = Session.shared.composedURL(path) else {
            XCTFail()
            return
        }
        
        let query = URLQueryItem(name: "foo", value: "bar")
        var component = URLComponents(string: initialURL.absoluteString)
        component?.queryItems = [query]
        guard let url = component?.url else {
            XCTFail()
            return
        }
        
        do {
            let request = try URLRequest(url: url, cachePolicy: URLRequest.CachePolicy.useProtocolCachePolicy, timeoutInterval: Session.shared.timeout, requestType: requestType, parameterType: parameterType, parameterArrayBehaviors: [:], responseType: responseType, parameters: nil, session: Session.shared)
            
            let expectation = XCTestExpectation(description: "")
            
            let parameters = ["foo": "bar"]
            Endpoint().get(path, parameters: parameters) { (result) in
                switch result {
                case .success(_):
                    
                    guard let cachedItem = TentaclesEphemeralCache.shared.cached(request: request) else {
                        XCTFail()
                        return
                    }
                    
                    let json = JSON(cachedItem.data)
                    switch json {
                    case .dictionary(_, let dictionary):
                        guard let bar = (dictionary["args"] as? [String: Any])?["foo"] as? String else {
                            XCTFail()
                            return
                        }
                        XCTAssertEqual(bar, "bar", "expected arguments in cached response")
                    default:
                        XCTFail()
                    }
                    
                case .failure(_, _):
                    XCTFail()
                }
                
                expectation.fulfill()
            }
            
            wait(for: [expectation], timeout: TentaclesTests.timeout)
        }
        catch {
            XCTFail()
            return
        }
    }
    
    func testGetCacheWithNeverExpiryViaCallback() {
        TentaclesEphemeralCache.shared.expirationCallback = { (request) in
            return .never
        }
        doGetCacheWithCustomExpiry(expectingNilCachedResponse: false)
    }
    
    func testGetCacheWithAlwaysExpiryViaCallback() {
        TentaclesEphemeralCache.shared.expirationCallback = { (request) in
            return .always
        }
        doGetCacheWithCustomExpiry(expectingNilCachedResponse: true)
    }
    
    func testGetCacheWithCustomExpiryViaCallback() {
        TentaclesEphemeralCache.shared.expirationCallback = { (request) in
            return .custom(20)
        }
        doGetCacheWithCustomExpiry(expectingNilCachedResponse: false)
    }
    
    func testGetCacheWithShortCustomExpiryViaCallback() {
        TentaclesEphemeralCache.shared.expirationCallback = { (request) in
            return .custom(0.0000001)
        }
        doGetCacheWithCustomExpiry(expectingNilCachedResponse: true)
    }
    
    func testGetCacheWithCustomExpiryAndCancelViaCallback() {
        TentaclesEphemeralCache.shared.expirationCallback = { (request) in
            return .custom(60)
        }
        doGetCacheWithCustomExpiry(expectingNilCachedResponse: true, cancelRequest: true)
    }
    
    func doGetCacheWithCustomExpiry(expectingNilCachedResponse: Bool, cancelRequest: Bool = false) {
        
        guard let initialURL = Session.shared.composedURL(path) else {
            XCTFail()
            return
        }
        
        let query = URLQueryItem(name: "foo", value: "bar")
        var component = URLComponents(string: initialURL.absoluteString)
        component?.queryItems = [query]
        guard let url = component?.url else {
            XCTFail()
            return
        }
        
        do {
            let request = try URLRequest(url: url, cachePolicy: URLRequest.CachePolicy.useProtocolCachePolicy, timeoutInterval: Session.shared.timeout, requestType: requestType, parameterType: parameterType, parameterArrayBehaviors: [:], responseType: responseType, parameters: nil, session: Session.shared)
            
            let expectation = XCTestExpectation(description: "")
            
            let parameters = ["foo": "bar"]
            Endpoint().get(path, parameters: parameters) { (result) in
                switch result {
                case .success(_):
                    let cachedItem = CachedResponse.cached(from: TentaclesEphemeralCache.shared, request: request)
                    
                    switch cachedItem.0 {
                    case .none:
                        XCTAssertEqual(expectingNilCachedResponse, true, "expected non-nil CachedResponse object")
                    case .some(_):
                        XCTAssertEqual(expectingNilCachedResponse, false, "expected nil CachedResponse object (it should have been expired)")
                    }
                    
                case .failure(_, let error):
                    guard let error = error else {
                        XCTFail()
                        return
                    }
                    if (error as NSError).code != URLError.cancelled.rawValue {
                        XCTFail()
                    }
                }
                
                expectation.fulfill()
            }
            
            if cancelRequest {
                Session.shared.cancelAllRequests()
            }
            
            wait(for: [expectation], timeout: TentaclesTests.timeout)
        }
        catch {
            XCTFail()
            return
        }
    }
    
}
