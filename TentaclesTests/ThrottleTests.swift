//
//  ThrottleTests.swift
//  TentaclesTests
//
//  Created by Michael Leavy on 7/10/22.
//  Copyright © 2022 Squid Store. All rights reserved.
//

import XCTest
@testable import Tentacles

class ThrottleTests: XCTestCase {
    
    let session = Session()
    var endpoint: Endpoint!

    override func setUpWithError() throws {
        session.host = "httpbin.org"
        endpoint = Endpoint(session: session)
        Session.shared = session
        Tentacles.shared.logLevel = [.warning, .error, .throttle]
    }

    override func tearDownWithError() throws {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
    }
    
    func testURLComposition() throws {
        let expectation = XCTestExpectation(description: "")
        let params = ["a": "first", "z": "last", "m": "middle"]
        
        endpoint = endpoint.get("get", parameters: params, completion: { result in
            expectation.fulfill()
        })
        
        guard let url = endpoint.task?.urlRequest?.url else {
            XCTFail()
            return
        }
        
        guard let sortedParams = url.sortedQueryKeyValuePairs else {
            XCTFail()
            return
        }
        
        guard sortedParams.count == 3 else {
            XCTFail()
            return
        }
        
        guard sortedParams[0].0 == "a", sortedParams[2].0 == "z" else {
            XCTFail()
            return
        }
        
        guard url.throttledName == "httpbin.org/get?a=first&m=middle&z=last" else {
            print(url.throttledName)
            XCTFail()
            return
        }
        
        wait(for: [expectation], timeout: TentaclesTests.timeout)
    }

    func testNoThrottle() throws {
        let expectation = XCTestExpectation(description: "")
        let repetitions = 8
        
        var results = 0
        
        for _ in 0..<repetitions {
            Endpoint().get("get") { result in
                switch result {
                case .success(_):
                    break
                case .failure(_, _):
                    XCTFail()
                }
                results += 1
                if results == repetitions {
                    expectation.fulfill()
                }
            }
        }
        
        wait(for: [expectation], timeout: TentaclesTests.timeout)
    }
    
    func testThrottled() throws {
        let expectation = XCTestExpectation(description: "")
        let fires = 7
        var timesFired = 0
        
        var results = 0
        let throttle = Throttle(count: 1, interval: 1)
                
        Timer.scheduledTimer(withTimeInterval: 0.2, repeats: true) { timer in
            Endpoint().throttle(throttle).get("get") { result in
                switch result {
                case .success(_):
                    break
                case .failure(_, _):
                    XCTFail()
                }
                results += 1
            }
            
            timesFired += 1
            if timesFired == fires {
                timer.invalidate()
                Timer.scheduledTimer(withTimeInterval: 1, repeats: false) { _ in
                    expectation.fulfill()
                }
            }
        }
                
        wait(for: [expectation], timeout: TentaclesTests.timeout)
        
        guard results == 2 else {
            XCTFail()
            return
        }
    }
    
    func testThrottledWithParams() throws {
        let expectation = XCTestExpectation(description: "")
        let fires = 7
        var timesFired = 0
        
        var results = 0
        let throttle = Throttle(count: 1, interval: 1)
        
        let params = ["a": "first", "z": "last", "m": "middle"]
        
        Endpoint().throttle(throttle).get("get", parameters: ["a": "first", "z": "last", "m": "riddle"]) { result in
            switch result {
            case .success(_):
                break
            case .failure(_, _):
                XCTFail()
            }
            results += 1
        }
                
        Timer.scheduledTimer(withTimeInterval: 0.2, repeats: true) { timer in
            Endpoint().throttle(throttle).get("get", parameters: params) { result in
                switch result {
                case .success(_):
                    break
                case .failure(_, _):
                    XCTFail()
                }
                results += 1
            }
            
            timesFired += 1
            if timesFired == fires {
                timer.invalidate()
                Timer.scheduledTimer(withTimeInterval: 1, repeats: false) { _ in
                    expectation.fulfill()
                }
            }
        }
                
        wait(for: [expectation], timeout: TentaclesTests.timeout)
        
        guard results == 3 else {
            print(results)
            XCTFail()
            return
        }
    }
}
