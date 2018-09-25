//
//  PersistentCacheTests.swift
//  TentaclesTests
//
//  Created by Mike Leavy on 4/2/18.
//  Copyright © 2018 Squid Store. All rights reserved.
//

import XCTest
@testable import Tentacles

class PersistentCacheTests: XCTestCase {
    
    let parameterType: Endpoint.ParameterType = .none
    let requestType: Endpoint.RequestType = .get
    let responseType: Endpoint.ResponseType = .json
    let path = "get"
    
    override func setUp() {
        super.setUp()
        TentaclesPersistantCache.shared.removeAll()
        Session.shared.host = "httpbin.org"
        Session.shared.cachingStore = .tentaclesPersistant
    }
    
    override func tearDown() {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
        super.tearDown()
    }
    
    
    func testCache() {
        guard let folderURL = FileManager.default.tentaclesCachesDirectory else {
            XCTFail()
            return
        }
        
        if FileManager.default.exists(at: folderURL) {
            guard let count = try? FileManager.default.contentsOfDirectory(at: folderURL, includingPropertiesForKeys: nil).count else {
                XCTFail()
                return
            }
            XCTAssertEqual(count, 0, "expected 0 items in cache folder")
        }
        
        print(folderURL.absoluteString)
        
        let dataString = "tentacles test"
        let data = dataString.data(using: .utf8)!
        let now = Date()
        let itemToCache = CachedResponse(code: 0, object: data, timestamp: now)
        
        guard let url = Session.shared.composedURL(path) else {
            XCTFail()
            return
        }
        
        print(url.absoluteString)
        
        guard let request = try? URLRequest(url: url, cachePolicy: URLRequest.CachePolicy.useProtocolCachePolicy, timeoutInterval: Session.shared.timeout, requestType: requestType, parameterType: parameterType, responseType: responseType, parameters: nil, session: Session.shared) else {
            XCTFail()
            return
        }
        
        TentaclesPersistantCache.shared.cache(data: itemToCache, request: request)
        
        guard let count = try? FileManager.default.contentsOfDirectory(at: folderURL, includingPropertiesForKeys: nil).count else {
            XCTFail()
            return
        }
        XCTAssertEqual(count, 1, "expected 1 item in cache folder")
        
        guard let cachedItem = TentaclesPersistantCache.shared.cached(request: request) else {
            XCTFail()
            return
        }
        
        XCTAssertEqual(cachedItem.timestamp, now, "expected timestamp to match stored timestamp")
        guard let s = String(data: cachedItem.data, encoding: .utf8) else {
            XCTFail()
            return
        }
        
        XCTAssertEqual(s, dataString, "expected string data to match stored string data")
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
            let request = try URLRequest(url: url, cachePolicy: URLRequest.CachePolicy.useProtocolCachePolicy, timeoutInterval: Session.shared.timeout, requestType: requestType, parameterType: parameterType, responseType: responseType, parameters: nil, session: Session.shared)
            
            let expectation = XCTestExpectation(description: "")
            
            let parameters = ["foo": "bar"]
            Endpoint().get(path, parameters: parameters) { (result) in
                switch result {
                case .success(_):
                    
                    guard let folderURL = FileManager.default.tentaclesCachesDirectory else {
                        XCTFail()
                        return
                    }
                    
                    guard let cachedItem = TentaclesPersistantCache.shared.cached(request: request) else {
                        XCTFail()
                        return
                    }
                    
                    guard let contents = try? FileManager.default.contentsOfDirectory(at: folderURL, includingPropertiesForKeys: nil) else {
                        XCTFail()
                        return
                    }
                    
                    XCTAssertEqual(contents.count, 1, "expected 1 item in cache directory")
                    
                    guard (contents.first?.absoluteString.contains("foo=bar") ?? false) else {
                        XCTFail("query params expected in cached file name")
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
    
    func testGetCacheNoQueryInCacheName() {
        
        guard let initialURL = Session.shared.composedURL(path) else {
            XCTFail()
            return
        }
        
        TentaclesPersistantCache.shared.includeQueryInCacheNameCallback = { (request) in
            return false
        }
        
        let query = URLQueryItem(name: "foo", value: "bar")
        var component = URLComponents(string: initialURL.absoluteString)
        component?.queryItems = [query]
        
        let expectation = XCTestExpectation(description: "")
        
        let parameters = ["foo": "bar"]
        Endpoint().get(path, parameters: parameters) { (result) in
            switch result {
            case .success(_):
                
                guard let folderURL = FileManager.default.tentaclesCachesDirectory else {
                    XCTFail()
                    return
                }
                
                guard let contents = try? FileManager.default.contentsOfDirectory(at: folderURL, includingPropertiesForKeys: nil) else {
                    XCTFail()
                    return
                }
                
                XCTAssertEqual(contents.count, 1, "expected 1 item in cache directory")
                
                guard !(contents.first?.absoluteString.contains("foo=bar") ?? true) else {
                    XCTFail("query params expected in cached file name")
                    return
                }
                
                
            case .failure(_, _):
                XCTFail()
            }
            expectation.fulfill()
        }
        
        
        wait(for: [expectation], timeout: TentaclesTests.timeout)
        
    }
    
    // there should be no cached items for a POST; check for that
    func testPostCache() {
        
        let postPath = "post"
        guard let url = Session.shared.composedURL(postPath) else {
            XCTFail()
            return
        }
        
        
        let parameters = ["foo": "bar"]
        
        guard let request = try? URLRequest(url: url, cachePolicy: URLRequest.CachePolicy.useProtocolCachePolicy, timeoutInterval: Session.shared.timeout, requestType: .post, parameterType: .formURLEncoded, responseType: responseType, parameters: parameters, session: Session.shared) else {
            XCTFail()
            return
        }
        
        guard let folderURL = FileManager.default.tentaclesCachesDirectory else {
            XCTFail()
            return
        }
        
        let expectation = XCTestExpectation(description: "")
        
        
        Endpoint().post(postPath, parameterType: .formURLEncoded, parameters: parameters) { (result) in
            switch result {
            case .success(_):
                
                if FileManager.default.exists(at: folderURL) {
                    guard let count = try? FileManager.default.contentsOfDirectory(at: folderURL, includingPropertiesForKeys: nil).count else {
                        XCTFail()
                        return
                    }
                    XCTAssertEqual(count, 0, "expected 0 items in cache folder")
                }
                
                let cachedItem = TentaclesPersistantCache.shared.cached(request: request)
                XCTAssertNil(cachedItem, "expected nil cache item")
                
            
            case .failure(_, _):
                XCTFail()
            }
            expectation.fulfill()
        }
            
            
        wait(for: [expectation], timeout: TentaclesTests.timeout)

    }


    func testRemoveFromCacheByURLRequest() {
        
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
        
        guard let folderURL = FileManager.default.tentaclesCachesDirectory else {
            XCTFail()
            return
        }
        
        do {
            let request = try URLRequest(url: url, cachePolicy: URLRequest.CachePolicy.useProtocolCachePolicy, timeoutInterval: Session.shared.timeout, requestType: requestType, parameterType: parameterType, responseType: responseType, parameters: nil, session: Session.shared)
            
            let expectation = XCTestExpectation(description: "")
            
            let parameters = ["foo": "bar"]
            let endpoint = Endpoint().get(path, parameters: parameters) { (result) in
                switch result {
                case .success(_):
                    
                    
                    
                    guard let cachedItem = TentaclesPersistantCache.shared.cached(request: request) else {
                        XCTFail()
                        return
                    }
                    
                    guard let contents = try? FileManager.default.contentsOfDirectory(at: folderURL, includingPropertiesForKeys: nil) else {
                        XCTFail()
                        return
                    }
                    
                    XCTAssertEqual(contents.count, 1, "expected 1 item in cache directory")
                    
                    guard (contents.first?.absoluteString.contains("foo=bar") ?? false) else {
                        XCTFail("query params expected in cached file name")
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
            
            guard let taskURLRequest = endpoint.task?.urlRequest else {
                XCTFail("query params expected in cached file name")
                return
            }
            
            TentaclesPersistantCache.shared.remove(request: taskURLRequest)
            
            guard let contents = try? FileManager.default.contentsOfDirectory(at: folderURL, includingPropertiesForKeys: nil) else {
                XCTFail()
                return
            }
            
            XCTAssertEqual(contents.count, 0, "expected 0 items in cache directory")
            
        }
        catch {
            XCTFail()
            return
        }
        
    }

}















