//
//  URLTests.swift
//  TentaclesTests
//
//  Created by Mike Leavy on 2/20/19.
//  Copyright © 2019 Squid Store. All rights reserved.
//

import XCTest

class URLTests: XCTestCase {

    override func setUp() {
        // Put setup code here. This method is called before the invocation of each test method in the class.
    }

    override func tearDown() {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
    }

    func testQueryDictionary() {
        let url = URL(string: "https://httpbin.org/foo?first=1&second=2&third=3&fourth=4&fifth=five")
        guard let dictionary = url?.queryDictionary else {
            XCTFail("query dictionary is nil")
            return
        }
        XCTAssert(dictionary.count == 5, "expected 5 items in dictionary")
    }

    func testQuerySorting() {
        let url = URL(string: "https://httpbin.org/foo?first=1&second=2&third=3&fourth=4&fifth=five")
        guard let pairs = url?.sortedQueryKeyValuePairs else {
            XCTFail("pairs array is nil")
            return
        }
        XCTAssert(pairs.count == 5, "expected 5 items in array")
        var previous: String?
        pairs.forEach { (pair) in
            if let p = previous {
                XCTAssert(p < pair.0, "sorting is incorrect")
            }
            previous = pair.0
        }
    }

}
