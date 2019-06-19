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
        Session.shared = session!
        
        // uncomment if you want to start out with no cached responses
        //session.removeAllCachedResponses()
        
        session.host = "api-testing.haulhub.com"
        session.authorizationHeaderKey = "x-hh-api-token"
        session.authorizationHeaderValue = "A4fh8AjsVga7fs6mbUqujFym"
        session.requestStartedAction = { [weak self] (endpoint) in
            self?.activityIndicator.startAnimating()
        }
        session.requestCompletedAction = { [weak self] (endpoint) in
            self?.activityIndicator.stopAnimating()
        }
        
        textView.text = nil
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        
        //PATCH https://api-testing.haulhub.com/driver/api/v4/shifts/7999/finish
        
        let params = ["finished_at": "2018-12-10T10:55:18.790-08:00", "guid": "B88E0D99-80AF-403E-904F-AAF6D439E764"]
        //let params = ["finished_at": "2018-11-27T11:04:40.290-08:00"]
        
        
        let endpoint = Endpoint(session: session).patch("driver/api/v4/shifts/8000/finish", parameterType: .json, parameters: params, completion: { [weak self] (result) in
            switch result {
            case .success(let response):
                if let s = String.fromJSON(response.jsonDictionary, pretty: true) {
                    print(s)
                }
                let httpStatus = response.httpStatus ?? -1
                print("http status = \(httpStatus)")
                self?.textView.text = response.description
                
                
            case .failure(let response, let error):
                print("failed")
                print("\(String(describing: response.httpStatus))")
                print(error?.localizedDescription ?? "unknown error")
            }
        })
        
        print(endpoint.task ?? "")
        
    }
    
}
