//
//  EndpointViewController.swift
//  TentaclesExample
//
//  Created by Mike Leavy on 6/26/18.
//  Copyright © 2018 Squid Store. All rights reserved.
//

import UIKit
import Tentacles

class EndpointViewController: UIViewController {

    @IBOutlet weak var activityIndicator: UIActivityIndicatorView!
    @IBOutlet weak var textView: UITextView!
    
    var session: Session!
    var endpoint: Endpoint?
    var environmentManager: EnvironmentManager?
    var mockPaginationHeaders: [String: String]? = ["page": "0"]
    
    override func viewDidLoad() {
        super.viewDidLoad()

        var systemCacheConfiguration = Session.SystemCacheConfiguration.default
        systemCacheConfiguration.requestCachePolicy = .returnCacheDataElseLoad
        
        // a couple of caching stores to choose from
        //let cachingStore = Session.CachingStore.system(systemCacheConfiguration)
        let cachingStore = Session.CachingStore.tentaclesEphemeral
        
        let tentaclesCachingStore = cachingStore
        session = Session(cachingStore: tentaclesCachingStore)
//        session.environmentManager = environmentManager
//        session.environment = environmentManager?.environment(named: "httpbin")
        session.queryParameterPlusEncodingBehavior = .encode
        Session.shared = session!
        
        // uncomment if you want to start out with no cached responses
        //session.removeAllCachedResponses()
        
        session.host = "httpbin.org"
        session.requestStartedAction = { [weak self] (endpoint) in
            self?.activityIndicator.startAnimating()
        }
        session.requestCompletedAction = { [weak self] (endpoint, response) in
            self?.activityIndicator.stopAnimating()
        }
        
        endpoint = Endpoint(session: session)
        
        textView.text = nil
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        
        
        refreshData()
        
    }
    
    
    @IBAction func didTapRefresh(_ sender: Any) {
        refreshData()
    }
    
    private func refreshData() {
        // uncomment to watch mocking in action
        // mock()
        
        let customParameterType: Endpoint.ParameterType = .customKeys("application/json", ["custom"]) { key, value in
            guard let array = value as? [String] else {return nil}
            var result = [String]()
            for element in array {
                let s = "myRepeatingKey=\(String(describing: element.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed)))"
                result.append(s)
            }
            return result
        }
        let stringValues = ["abc", "123", "this has spaces"]
        let intValues = [7,88,2]
        let boolValues = [true, true, false]
        
        let date = Date()
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss.SSSZZZZZ"
        let dateString = dateFormatter.string(from: date)
        
        let parameters: [String: Any] = ["strings": stringValues, "ints": intValues, "bools": boolValues, "single": 42, "date": dateString]
        
        let myBehaviors: Endpoint.ParameterArrayBehaviors = [.list(","): ["foo"], .list("--"): ["bar"], .repeat: []]
        
        endpoint?.get("get", parameterType: .json, parameterArrayBehaviors: myBehaviors, parameters: parameters) { [weak self] (result) in
            switch result {
            case .success(let response):
                if let s = String.fromJSON(response.jsonDictionary, pretty: true) {
                    print(s)
                }
                if let h = response.headers {
                    self?.mockPaginationHeaders = h as? [String: String] ?? self?.mockPaginationHeaders
                    print(h["Connection"] ?? "no Connection in headers")
                    print(h["page"] ?? "no Page in headers")
                }
                let httpStatus = response.httpStatus ?? -1
                print("http status = \(httpStatus)")
                self?.textView.text = response.description
                
                
            case .failure(let response, let error):
                print("failed")
                print("\(response.httpStatus ?? -1)")
                print(error?.localizedDescription ?? "")
            }
        }
        
        print(endpoint?.task ?? "")
    }
    
    private func mock() {
        let mockData = """
                        {
                          "url" : "https://httpbin.org/get",
                          "headers" : {
                            "User-Agent" : "TentaclesExample/1 CFNetwork/1120 Darwin/19.0.0",
                            "Accept-Encoding" : "gzip, deflate, br",
                            "Host" : "httpbin.org",
                            "Accept-Language" : "en-us",
                            "Accept" : "application/json"
                          },
                          "origin" : "71.198.189.35, 71.198.189.35",
                          "args" : {

                          }
                        }
                        """
        
        endpoint?.mock(jsonString: mockData)
        
        endpoint?.mock(headers: mockPaginationHeaders)
        endpoint?.mock(paginationHeaderKeys: ["page"])
    }
    
}
