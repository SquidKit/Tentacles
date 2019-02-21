//
//  ClientCacheTests.swift
//  TentaclesTests
//
//  Created by Mike Leavy on 6/9/18.
//  Copyright © 2018 Squid Store. All rights reserved.
//

import XCTest
@testable import Tentacles

class MyCache: TentaclesCaching {
    var expirationCallback: CacheExpirationCallback?
    
    var includeQueryInCacheNameCallback: CacheNameIncludesQueryCallback?
    
    
    var cache = [String: Any]()
    private let cachedName = "cached"
    
    func cache(data: CachedResponse, request: URLRequest) {
        cache[cachedName] = data
    }
    
    func cached(request: URLRequest) -> CachedResponse? {
        return cache[cachedName] as? CachedResponse
    }
    
    func remove(request: URLRequest) {
        cache[cachedName] = nil
    }
    
    func removeAll() {
        cache.removeAll()
    }
    
    var defaultExpiry: CacheExpiry = .never
    
    
}

class ClientCacheTests: XCTestCase {
    
    let cache = MyCache()
    
    override func setUp() {
        super.setUp()
        Session.shared.host = "httpbin.org"
        cache.removeAll()
        Session.shared.cachingStore = .client(cache)
    }
    
    override func tearDown() {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
        super.tearDown()
    }
    
    
    func testNonExpiringCaching() {
        
        let expectation = XCTestExpectation(description: "")
        
        Endpoint().get("get") { [weak self] (result) in
            switch result {
            case .success(_):
                XCTAssert(self!.cache.cache.count == 1, "Expected cache to contain 1 item")
            case .failure(_, let error):
                XCTFail(error?.localizedDescription ?? "unknown failure")
            }
            expectation.fulfill()
        }
        
        wait(for: [expectation], timeout: TentaclesTests.timeout)
    }
    
    
    func testAlwaysExpiringCaching() {
        
        cache.defaultExpiry = .always
        
        // Prime the cache with a successful request
        let expectation = XCTestExpectation(description: "")
        
        Endpoint().get("get") { [weak self] (result) in
            switch result {
            case .success(_):
                XCTAssert(self!.cache.cache.count == 1, "Expected cache to contain 1 item")
            case .failure(_, let error):
                XCTFail(error?.localizedDescription ?? "unknown failure")
            }
            expectation.fulfill()
        }
        
        wait(for: [expectation], timeout: TentaclesTests.timeout)
        
        // Ensure cache isn't used and contains no items after failed request
        let expectation2 = XCTestExpectation(description: "")
        
        Endpoint().get("getzzzzzzzz") { [weak self] (result) in
            switch result {
            case .success(_):
                XCTFail("This request should have failed")
            case .failure(_, _):
                XCTAssert(self!.cache.cache.count == 0, "Expected cache to contain 0 items")
            }
            expectation2.fulfill()
        }
        
        wait(for: [expectation2], timeout: TentaclesTests.timeout)
    }
    
    
    func testCustomExpiringCaching() {
        
        cache.defaultExpiry = .custom(TimeInterval(20))
        
        // Prime the cache with a successful request
        let expectation = XCTestExpectation(description: "")
        
        Endpoint().get("get") { [weak self] (result) in
            switch result {
            case .success(_):
                XCTAssert(self!.cache.cache.count == 1, "Expected cache to contain 1 item")
            case .failure(_, let error):
                XCTFail(error?.localizedDescription ?? "unknown failure")
            }
            expectation.fulfill()
        }
        
        wait(for: [expectation], timeout: TentaclesTests.timeout)
        
        // Ensure cache is used and still contains 1 item after failed request
        let expectation2 = XCTestExpectation(description: "")
        
        Endpoint().get("getzzzzzzzz") { [weak self] (result) in
            switch result {
            case .success(_):
                XCTAssert(self!.cache.cache.count == 1, "Expected cache to contain 1 item")
            case .failure(_, _):
                XCTFail("This request should not have failed")
            }
            expectation2.fulfill()
        }
        
        wait(for: [expectation2], timeout: TentaclesTests.timeout)
        
        // Set cache timeout to one second...
        cache.defaultExpiry = .custom(TimeInterval(1))
        
        // and wait for 2...
        wait(for: 2)
        
        let expectation3 = XCTestExpectation(description: "")
        
        Endpoint().get("getzzzzzzzz") { [weak self] (result) in
            switch result {
            case .success(_):
                XCTFail("This request should have failed")
            case .failure(_, _):
                XCTAssert(self!.cache.cache.count == 0, "Expected cache to contain 0 items")
            }
            expectation3.fulfill()
        }
        
        wait(for: [expectation3], timeout: TentaclesTests.timeout)
    }
    
    
    func testContingentExpiringCaching() {
        
        cache.defaultExpiry = .contingent
        
        // Prime the cache with a successful request
        let expectation = XCTestExpectation(description: "")
        
        Endpoint().get("get") { [weak self] (result) in
            switch result {
            case .success(_):
                XCTAssert(self!.cache.cache.count == 1, "Expected cache to contain 1 item")
            case .failure(_, let error):
                XCTFail(error?.localizedDescription ?? "unknown failure")
            }
            expectation.fulfill()
        }
        
        wait(for: [expectation], timeout: TentaclesTests.timeout)
        
        // Ensure cache is used and still contains 1 item after failed request
        let expectation2 = XCTestExpectation(description: "")
        
        Endpoint().get("getzzzzzzzz") { [weak self] (result) in
            switch result {
            case .success(_):
                XCTAssert(self!.cache.cache.count == 1, "Expected cache to contain 1 item")
            case .failure(_, _):
                XCTFail("This request should not have failed")
            }
            expectation2.fulfill()
        }
        
        wait(for: [expectation2], timeout: TentaclesTests.timeout)
        
        
        // wait for 2 seconds
        wait(for: 2)
        
        let expectation3 = XCTestExpectation(description: "")
        
        Endpoint().get("getzzzzzzzz") { [weak self] (result) in
            switch result {
            case .success(_):
                XCTAssert(self!.cache.cache.count == 1, "Expected cache to contain 1 item")
            case .failure(_, _):
                XCTFail("This request should not have failed")
            }
            expectation3.fulfill()
        }
        
        wait(for: [expectation3], timeout: TentaclesTests.timeout)
    }
    
    func testContingentAfterExpiringCaching() {
        
        cache.defaultExpiry = .contingentAfter(3)
        
        // Prime the cache with a successful request
        let expectation = XCTestExpectation(description: "")
        
        Endpoint().get("get") { [weak self] (result) in
            switch result {
            case .success(_):
                XCTAssert(self!.cache.cache.count == 1, "Expected cache to contain 1 item")
            case .failure(_, let error):
                XCTFail(error?.localizedDescription ?? "unknown failure")
            }
            expectation.fulfill()
        }
        
        wait(for: [expectation], timeout: TentaclesTests.timeout)
        
        // Ensure cache is used and still contains 1 item after failed request
        let expectation2 = XCTestExpectation(description: "")
        
        let endpoint = Endpoint().get("getzzzzzzzz") { [weak self] (result) in
            switch result {
            case .success(_):
                XCTAssert(self!.cache.cache.count == 1, "Expected cache to contain 1 item")
            case .failure(_, _):
                XCTFail("This request should not have failed")
            }
            expectation2.fulfill()
        }
        
        XCTAssert(endpoint.task?.taskResponseType == .cached, "Expected task type to be cached")
        
        wait(for: [expectation2], timeout: TentaclesTests.timeout)
        
        
        // wait for 3 seconds
        wait(for: 3)
        
        let expectation3 = XCTestExpectation(description: "")
        
        let endpoint2 = Endpoint().get("getzzzzzzzz") { [weak self] (result) in
            switch result {
            case .success(_):
                XCTAssert(self!.cache.cache.count == 1, "Expected cache to contain 1 item")
            case .failure(_, _):
                XCTFail("This request should not have failed")
            }
            expectation3.fulfill()
        }
        
        XCTAssert(endpoint2.task?.taskResponseType == .network, "Expected task type to be network, since cache should have expired")
        
        wait(for: [expectation3], timeout: TentaclesTests.timeout)
    }
    
    func testGetCachedOnly() {
        
        cache.defaultExpiry = .custom(TimeInterval(60*60))
        
        // Ensure that there is no cached data for initial get
        let expectation = XCTestExpectation(description: "")
        Endpoint().getCached("get", parameters: nil, responseType: .json) { (result) in
            switch result {
            case .success(_):
                XCTFail("there should be no data in the cache")
            case .failure(let response, let error):
                guard let error = error else {
                    XCTFail("expected a valid error")
                    return
                }
                guard (error as NSError).code == TentaclesErrorCode.cachedNotFoundError.rawValue else {
                    XCTFail("expected a cachedNotFoundError error code")
                    return
                }
                guard response.httpStatus == TentaclesErrorCode.cachedNotFoundError.rawValue else {
                    XCTFail("expected a cachedNotFoundError for httpStatus")
                    return
                }
            }
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: TentaclesTests.timeout)
        
        // Now prime the cache with a successful request
        let expectation2 = XCTestExpectation(description: "")
        
        Endpoint().get("get") { [weak self] (result) in
            switch result {
            case .success(_):
                XCTAssert(self!.cache.cache.count == 1, "Expected cache to contain 1 item")
            case .failure(_, let error):
                XCTFail(error?.localizedDescription ?? "unknown failure")
            }
            expectation2.fulfill()
        }
        
        wait(for: [expectation2], timeout: TentaclesTests.timeout)
        
        // Ensure that there is now a cached item in the response
        let expectation3 = XCTestExpectation(description: "")
        
        Endpoint().getCached("get", parameters: nil, responseType: .json) { (result) in
            switch result {
            case .success(let response):
                XCTAssert(response.data != nil, "expected non-nil data")
            case .failure(_, _):
                XCTFail("unknown failure")
            }
            expectation3.fulfill()
        }
        
        wait(for: [expectation3], timeout: TentaclesTests.timeout)
    }
    
}




extension XCTestCase {
    
    func wait(for duration: TimeInterval) {
        let waitExpectation = expectation(description: "Waiting")
        
        let when = DispatchTime.now() + duration
        DispatchQueue.main.asyncAfter(deadline: when) {
            waitExpectation.fulfill()
        }
        
        // We use a buffer here to avoid flakiness with Timer on CI
        waitForExpectations(timeout: duration + 0.5)
    }
}
