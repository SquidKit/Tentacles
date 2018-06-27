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
        let systemCachingStore = Session.CachingStore.system(systemCacheConfiguration)
        let tentaclesCachingStore = systemCachingStore
        session = Session(cachingStore: tentaclesCachingStore)
        session.environmentManager = environmentManager
        session.environment = environmentManager?.environment(named: "httpbin")
        Session.shared = session!
        
        session.removeAllCachedResponses()
        
        session.host = "httpbin.org"
        
        activityIndicator.startAnimating()
        textView.text = nil
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        
        let task = Endpoint(session: session).get("{myKey}", completion: { [weak self] (result) in
            self?.activityIndicator.stopAnimating()
            switch result {
            case .success(let response):
                if let s = String.fromJSON(response.jsonDictionary, pretty: true) {
                    print(s)
                }
                let httpStatus = response.httpStatus ?? -1
                print("http status = \(httpStatus)")
                self?.textView.text = response.description
                
                
            case .failure(_):
                print("failed")
            }
        })
        
        print(task)
        
    }
    
}
