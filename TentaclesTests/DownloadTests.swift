//
//  DownloadTests.swift
//  TentaclesTests
//
//  Created by Mike Leavy on 9/22/18.
//  Copyright © 2018 Squid Store. All rights reserved.
//

import XCTest

class DownloadTests: XCTestCase {

    override func setUp() {
        super.setUp()
        Session.shared.host = "httpbin.org"
        Tentacles.shared.logger = Logger()
        Tentacles.shared.logLevel = .all
    }

    override func tearDown() {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
    }

    func testExample() {
        let expectation = XCTestExpectation(description: "")
        
        let path = "/image/jpeg"
        Endpoint().download(path, parameters: nil, progress: { (written, totalWritten, totalExpected, percentComplete) in
            if let percent = percentComplete {
                print("percent complete: \(percent)")
            }
            else {
                print("progress with unknown duration: \(totalWritten) bytes written")
            }
        }) { (result) in
            switch result {
            case .success(let response):
                guard let data = response.data else {
                    XCTFail()
                    return
                }
                guard let image = UIImage(data: data) else {
                    XCTFail()
                    return
                }
                break
            case .failure(_, let error):
                print(error?.localizedDescription ?? "no error description")
                XCTFail()
            }
            expectation.fulfill()
        }
        
        wait(for: [expectation], timeout: TentaclesTests.timeout)
    }

    func testPerformanceExample() {
        // This is an example of a performance test case.
        self.measure {
            // Put the code you want to measure the time of here.
        }
    }

}
