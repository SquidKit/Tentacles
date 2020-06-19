//
//  DownloadTests.swift
//  TentaclesTests
//
//  Created by Mike Leavy on 9/22/18.
//  Copyright © 2018 Squid Store. All rights reserved.
//

import XCTest

class DownloadTests: XCTestCase {
    
    let downloader = ImageDownloader()

    override func setUp() {
        super.setUp()
        Session.shared.host = "httpbin.org"
        Tentacles.shared.logger = Logger()
        Tentacles.shared.logLevel = .all
    }

    override func tearDown() {
        Session.shared = Session()
    }

    func testProgressDownload() {
        let expectation = XCTestExpectation(description: "")
        
        let path = "/image/jpeg"
        let _ = Endpoint().download(path, parameters: nil, progress: { (written, totalWritten, totalExpected, percentComplete) in
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
                guard let _ = UIImage(data: data) else {
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
    
    func testImageDownloader() {
        let expectation = XCTestExpectation(description: "")
        
        let url = URL(string: "https://s3.amazonaws.com/haulhub/dot_employees/signatures/000/000/006/regular/data?1589396180")
        
        
        downloader.get(url: url!) { (result) in
            switch result {
            case .success(let response):
                guard let _ = response.image else {
                    XCTFail()
                    return
                }
            case .failure(_, let error):
                print(error?.localizedDescription ?? "no error description")
                XCTFail()
            }
            
            expectation.fulfill()
        }
        
        wait(for: [expectation], timeout: TentaclesTests.timeout)
    }
    
    func testSharedImageDownloader() {
        let expectation = XCTestExpectation(description: "")
        let expectation2 = XCTestExpectation(description: "")
        
        let url = URL(string: "https://s3.amazonaws.com/haulhub/dot_employees/signatures/000/000/006/regular/data?1589396180")
        ImageDownloader.shared.get(url: url!) { (result) in
            switch result {
            case .success(let response):
                guard let _ = response.image else {
                    XCTFail()
                    return
                }
            case .failure(_, let error):
                print(error?.localizedDescription ?? "no error description")
                XCTFail()
            }
            
            expectation.fulfill()
        }
        
        let otherURL = URL(string: "https://httpbin.org/image/jpeg")
        ImageDownloader.shared.get(url: otherURL!) { (result) in
            switch result {
            case .success(let response):
                guard let _ = response.image else {
                    XCTFail()
                    return
                }
            case .failure(_, let error):
                print(error?.localizedDescription ?? "no error description")
                XCTFail()
            }
            
            expectation2.fulfill()
        }
        
        wait(for: [expectation, expectation2], timeout: TentaclesTests.timeout)
    }
    
    func testCancelImageDownloader() {
        let expectation = XCTestExpectation(description: "")
        
        let url = URL(string: "https://s3.amazonaws.com/haulhub/dot_employees/signatures/000/000/006/regular/data?1589396180")
        
        
        downloader.get(url: url!) { (result) in
            switch result {
            case .success(let response):
                XCTFail()
            case .failure(_, let error):
                print(error?.localizedDescription ?? "no error description")
                guard error?.localizedDescription == "cancelled" else {
                    XCTFail()
                    return
                }
            }
            
            expectation.fulfill()
        }
        
        downloader.cancel(url: url!)
        
        wait(for: [expectation], timeout: TentaclesTests.timeout)
    }
}
