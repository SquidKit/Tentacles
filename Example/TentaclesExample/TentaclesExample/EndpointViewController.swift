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
        
        session.host = "httpbin.org"
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
        
        
        let endpoint = Endpoint(session: session).get("get") { [weak self] (result) in
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
                print("\(response.httpStatus ?? -1)")
                print(error?.localizedDescription ?? "")
            }
        }
        
        print(endpoint.task ?? "")
        
    }
    
}
