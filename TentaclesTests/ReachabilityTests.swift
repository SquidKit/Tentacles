//
//  ReachabilityTests.swift
//  TentaclesTests
//
//  Created by Mike Leavy on 4/5/18.
//  Copyright © 2018 Squid Store. All rights reserved.
//

import XCTest
@testable import Tentacles

class ReachabilityTests: XCTestCase {
    
    let reachability = Tentacles.Reachability()
    
    override func setUp() {
        super.setUp()
    }
    
    override func tearDown() {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
        super.tearDown()
    }
    
    func testCallback() {
        let error = reachability?.startNotifier(reachabilityCallback: { (connection) in
            print(connection.description)
        })
        
        XCTAssertNil(error, error!.localizedDescription)
    }
    
    
}
