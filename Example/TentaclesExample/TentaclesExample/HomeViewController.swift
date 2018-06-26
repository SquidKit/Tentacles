//
//  HomeViewController.swift
//  TentaclesExample
//
//  Created by Mike Leavy on 6/26/18.
//  Copyright © 2018 Squid Store. All rights reserved.
//

import UIKit
import Tentacles

class HomeViewController: UITableViewController {
    
    @IBOutlet weak var reachabilityLabel: UILabel!
    
    let model = HomeViewModel()
    
    var reachability: Reachability?

    override func viewDidLoad() {
        super.viewDidLoad()

        reachability = Reachability()
        reachability?.startNotifier(reachabilityCallback: { [weak self] (connectionType) in
            self?.reachabilityLabel.text = connectionType.description
        })
        
        reachabilityLabel.text = "Reachability unknown"
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        printHosts()
    }

    // MARK: - Table view data source

    override func numberOfSections(in tableView: UITableView) -> Int {
        return model.sections
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return model.rows(for: section)
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "subtitleCell", for: indexPath)

        cell.textLabel?.text = model.title(for: indexPath)
        cell.detailTextLabel?.text = model.detailTitle(for: indexPath)

        return cell
    }
    
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        guard let row = HomeViewModel.Rows(rawValue: indexPath.row) else {return}
        switch row {
        case .hosts:
            let configurationViewController:HostConfigurationTableViewController = HostConfigurationTableViewController(style: .grouped)
            configurationViewController.hostMapManager = model.hostMapManager
            configurationViewController.navigationItem.title = model.title(for: indexPath)
            navigationController?.pushViewController(configurationViewController, animated: true)
        case .count:
            break
        }
        
    }
    
    //MARK: - HostMap
    func printHosts() {
        print("---Mapped Hosts---")
        for host in model.endpointHosts {
            print("   \(host)")
        }
        
        print("---Canonical Hosts---")
        for host in model.canonicalHosts {
            print("   \(host)")
        }
        
        print("Host for \"httpbin.org\" = \(model.host(for: "httpbin.org"))")
    }

}
