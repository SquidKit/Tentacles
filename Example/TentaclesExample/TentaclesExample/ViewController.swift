//
//  ViewController.swift
//  TentaclesExample
//
//  Created by Mike Leavy on 3/28/18.
//  Copyright © 2018 Squid Store. All rights reserved.
//

import UIKit
import Tentacles



class ViewController: UIViewController {
    
    @IBOutlet weak var reachabilityLabel: UILabel!
    
    var session: Session!
    var endpoint: Endpoint?
    var reachability: Reachability?

    override func viewDidLoad() {
        super.viewDidLoad()
        
        // .returnCacheDataElseLoad
        // .reloadIgnoringLocalCacheData
        

        var systemCacheConfiguration = Session.SystemCacheConfiguration.default
        systemCacheConfiguration.requestCachePolicy = .returnCacheDataElseLoad
        let systemCachingStore = Session.CachingStore.system(systemCacheConfiguration)
        //let tentaclesCachingStore = Session.CachingStore.tentaclesPersistant
        let tentaclesCachingStore = systemCachingStore
        session = Session(cachingStore: tentaclesCachingStore)
        Session.shared = session!
        
        session.removeAllCachedResponses()
        
        session.host = "httpbin.org"
        
        reachability = Reachability()
        reachability?.startNotifier(reachabilityCallback: { [weak self] (connectionType) in
            self?.reachabilityLabel.text = connectionType.description
        })
        
        reachabilityLabel.text = "Reachability unknown"
        
        
    }
    
    @IBAction func didTapGo(_ sender: Any) {
        
        let id = Endpoint(session: session).get("get", completion: { (result) in
            switch result {
            case .success(let response):
                if let s = String.fromJSON(response.jsonDictionary, pretty: true) {
                    print(s)
                }
                let httpStatus = response.httpStatus ?? -1
                print("http status = \(httpStatus)")
                
            case .failure(_):
                print("failed")
            }
        })
        
        print(id)
        
    }
    
    @IBAction func didTapDelete(_ sender: Any) {
        endpoint = nil
    }
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }


}

