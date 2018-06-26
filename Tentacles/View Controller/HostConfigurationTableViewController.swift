//
//  HostConfigurationTableViewController.swift
//  Tentacles
//
//  Created by Mike Leavy on 8/28/14.
//  Copyright (c) 2018 Squid Store. All rights reserved.
//

import UIKit

open class ConfigurationItem {
    open var protocolHostPair:ProtocolHostPair?
    open let key:String
    open let canonicalHost:String
    open let editable:Bool
    let hostMapManager:HostMapManager!
    open var title:String?
    open var detailTitle:String?
    open var reuseIdentifier:String?
    open var selectBlock:(_ item:ConfigurationItem, _ indexPath:IndexPath, _ actionsTarget:UITableView?) -> () = {(item:ConfigurationItem, indexPath:IndexPath, actionsTarget:UITableView?) -> () in}
    
    public required init(hostMapManager:HostMapManager, protocolHostPair:ProtocolHostPair?, key:String, canonicalHost:String, editable:Bool) {
        self.hostMapManager = hostMapManager
        self.protocolHostPair = protocolHostPair
        self.key = key
        self.canonicalHost = canonicalHost
        self.editable = editable
        self.title = protocolHostPair?.host ?? ""
        
        self.selectBlock = {[unowned self] (item:ConfigurationItem, indexPath:IndexPath, actionsTarget:UITableView?) -> () in
            self.hostMapManager.setConfigurationForCanonicalHost(self.key, mappedHost: nil, canonicalHost: self.canonicalHost)
            if let table = actionsTarget {
                table.deselectRow(at: indexPath, animated: true)
                table.reloadData()
            }
        }
    }
}

open class ConfigurationSection {
    open var items = [ConfigurationItem]()
    open var title:String?
    
    open var count:Int {
        return items.count
    }
    
    open var height:Float? {
        return title == nil ? 0 : nil
    }
    
    public init() {
        
    }
    
    public init(_ title:String) {
        self.title = title
    }
    
    open func append(_ item:ConfigurationItem) {
        self.items.append(item)
    }
    
    open subscript(index:Int) -> ConfigurationItem? {
        if (index < items.count) {
            return items[index]
        }
        
        return nil
    }
    
}


open class HostConfigurationTableViewController: UITableViewController, CustomHostCellDelegate {
    
    open var hostMapManager:HostMapManager?
    open var model = Model()
    open var customHostTextFieldPlaceholder: String?
    
    open class Model {
        fileprivate var sections = [ConfigurationSection]()
        
        fileprivate init() {
            
        }
        
        open func append(_ section:ConfigurationSection) {
            sections.append(section)
        }
        
        open func insert(_ section:ConfigurationSection, atIndex:Int) {
            sections.insert(section, at: atIndex)
        }
        
        open func remove(_ section:ConfigurationSection) {
            if let index = sections.index (where: {$0 === section}) {
                sections.remove(at: index)
            }
        }
        
        open func reset() {
            sections = [ConfigurationSection]()
        }
        
        open func indexForSection(_ section:ConfigurationSection) -> Int? {
            return sections.index{$0 === section}
        }
        
        open func indexPathForItem(_ item:ConfigurationItem) -> IndexPath? {
            for (count, element) in sections.enumerated() {
                if let itemIndex = element.items.index(where: {$0 === item}) {
                    return IndexPath(row: itemIndex, section: count)
                }
            }
            
            return nil
        }
        
        open subscript(indexPath:IndexPath) -> ConfigurationItem? {
            return self[(indexPath as NSIndexPath).section, (indexPath as NSIndexPath).row]
        }
        
        open subscript(section:Int, row:Int) -> ConfigurationItem? {
            if sections.count > section && sections[section].count > row {
                return sections[section][row]
            }
            return nil
        }
        
        
        open subscript(section:Int) -> ConfigurationSection? {
            if sections.count > section {
                return sections[section]
            }
            return nil
        }
    }

    open override func viewDidLoad() {
        super.viewDidLoad()
        
        if let manager = hostMapManager {
            for hostMap in manager.hostMaps {
                let tableSection = ConfigurationSection(hostMap.canonicalHost)
                self.model.append(tableSection)
                for key in hostMap.sortedKeys {
                    let pair = hostMap.pairWithKey(key as String)
                    let configuration = ConfigurationItem(hostMapManager:manager, protocolHostPair:pair, key:key as String, canonicalHost:hostMap.canonicalHost, editable:hostMap.isEditable(key as String))
                    tableSection.append(configuration)
                }
            }
        }
        
        self.tableView.rowHeight = 44
        self.tableView.sectionHeaderHeight = 34

    }

    open override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    fileprivate func isSelected(_ configItem:ConfigurationItem) -> Bool {
        if let runtimePair = EndpointMapper.mappedPairForCanonicalHost(configItem.canonicalHost) {
            if configItem.protocolHostPair != nil && runtimePair == configItem.protocolHostPair! && runtimePair.host != nil {
                return true
            }
        }
        return false
    }

    // MARK: - Table view data source
    
    open override func tableView(_ tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
        if let height = self.model[section]?.height {
            return CGFloat(height)
        }
        return tableView.sectionHeaderHeight
    }
    
    open override func numberOfSections(in tableView: UITableView) -> Int {
        return self.model.sections.count
    }
    
    open override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return self.model[section]!.count
    }
    
    open override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        if let item = self.model[indexPath] {
            item.selectBlock(item, indexPath, tableView)
        }
    }
    
    open override func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        return self.model[section]!.title
    }


    let configItemReuseIdentifier:String = "com.squidkit.hostConfigurationDetailCellReuseIdentifier"
    let userItemReuseIdentifier:String = "com.squidkit.hostConfigurationDetailCellUserReuseIdentifier"
    
    open override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        var cell:UITableViewCell?
        
        let configItem = self.model[indexPath]!
        
        if !configItem.editable {
            cell = tableView.dequeueReusableCell(withIdentifier: configItemReuseIdentifier)
            if cell == nil {
                cell = UITableViewCell(style: .subtitle, reuseIdentifier: configItemReuseIdentifier)
            }
            
            cell?.textLabel!.text = configItem.title
            cell?.detailTextLabel!.text = configItem.key
        }
        else {
            cell = CustomHostCell(style: .default, reuseIdentifier: userItemReuseIdentifier)
            
            let customCell = cell as! CustomHostCell
            customCell.configItem = configItem
            customCell.placeholder = customHostTextFieldPlaceholder
            customCell.delegate = self
        }
        
        cell?.accessoryType = self.isSelected(configItem) ? .checkmark : .none
        
        return cell!
    }
    
    // MARK: - Table CustomHostCellDelegate data source
    
    func hostTextDidChange(_ hostText:String?, configItem:ConfigurationItem) {
        hostMapManager?.setConfigurationForCanonicalHost(configItem.key, mappedHost: hostText, canonicalHost: configItem.canonicalHost)
        let pair = ProtocolHostPair(nil, hostText)
        configItem.protocolHostPair = pair
        self.tableView.reloadData()
    }
}

protocol CustomHostCellDelegate {
    func hostTextDidChange(_ hostText:String?, configItem:ConfigurationItem)
}

open class CustomHostCell: UITableViewCell, UITextFieldDelegate {
    var textField:UITextField?
    var configItem:ConfigurationItem?
    var delegate:CustomHostCellDelegate?
    var placeholder: String?
    
    open override func layoutSubviews() {
        super.layoutSubviews()
        if textField == nil {
            textField = UITextField(frame:self.contentView.bounds.insetBy(dx: 15, dy: 5))
            self.contentView.addSubview(textField!)
            textField?.placeholder = placeholder ?? "Enter custom host (e.g. \"api.host.com\")"
            textField?.font = UIFont(descriptor: UIFontDescriptor.preferredFontDescriptor(withTextStyle: UIFontTextStyle.subheadline), size: 13)
            textField?.keyboardType = .URL
            textField?.returnKeyType = .done
            textField?.autocorrectionType = .no
            textField?.autocapitalizationType = .none
            textField?.clearButtonMode = .whileEditing
            textField?.delegate = self
            textField?.text = configItem!.protocolHostPair?.host
        }
    }
    
    // MARK: - UITextFieldDelegate
    
    open func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        textField.resignFirstResponder()
        return true
    }
    
    open func textFieldDidEndEditing(_ textField: UITextField) {
        delegate?.hostTextDidChange(textField.text, configItem: configItem!)
    }
}

