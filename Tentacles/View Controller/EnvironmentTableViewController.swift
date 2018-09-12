//
//  EnvironmentTableViewController.swift
//  Tentacles
//
//  Created by Mike Leavy on 6/27/18.
//  Copyright © 2018 Squid Store. All rights reserved.
//

import UIKit

open class ConfigurationRowItem {
    public var configuration: Configuration!
    public var environment: Environment!
    let manager: EnvironmentManager!
    public var title:String {
        return configuration.name
    }
    public var detailTitle:String? {
        if isEditable {
            return manager.host(named: configuration.name, forEnvironment: environment)
        }
        return manager.url(named: configuration.name, forEnvironment: environment)?.absoluteString
    }
    public let isEditable:Bool!
    open var selectBlock:(_ item: ConfigurationRowItem, _ indexPath: IndexPath, _ actionsTarget: EnvironmentTableViewController?) -> () = {(item: ConfigurationRowItem, indexPath: IndexPath, actionsTarget: EnvironmentTableViewController?) -> () in}
    
    public var isSelected: Bool {
        return manager.host(for: environment) == configuration.hostName
    }
    
    public required init(manager: EnvironmentManager, configuration: Configuration, environment: Environment) {
        self.configuration = configuration
        self.environment = environment
        self.manager = manager
        self.isEditable = configuration.isHostMutable
        
        self.selectBlock = {[unowned self] (item: ConfigurationRowItem, indexPath: IndexPath, actionsTarget: EnvironmentTableViewController?) -> () in
            self.manager.use(configuration: self.configuration, forEnvironment: self.environment)
            if let controller = actionsTarget {
                controller.tableView.deselectRow(at: indexPath, animated: true)
                controller.updateModel(reloadData: true)
            }
        }
    }
    
    fileprivate func setHost(_ host: String?) {
        manager.setHost(host, forEnvironment: environment, forConfiguration: configuration)
        environment = manager.environment(named: environment.name)!
        configuration = manager.configuration(named: configuration.name, forEnviornment: environment)!
        manager.use(configuration: configuration, forEnvironment: environment)
    }
}

open class EnvironmentSectionItem {
    open var rows = [ConfigurationRowItem]()
    open var title: String
    let manager: EnvironmentManager!
    var count: Int {
        return rows.count
    }
    
    public required init(manager: EnvironmentManager, environment: Environment) {
        self.manager = manager
        self.title = environment.name
        
        environment.configurations?.forEach({ (configuration) in
            let rowItem = ConfigurationRowItem(manager: manager, configuration: configuration, environment: environment)
            self.rows.append(rowItem)
        })
    }
    
    open func append(_ item: ConfigurationRowItem) {
        rows.append(item)
    }
    
    open subscript(index: Int) -> ConfigurationRowItem? {
        if (index < rows.count) {
            return rows[index]
        }
        return nil
    }
}

open class EnvironmentTableViewController: UITableViewController {
    
    public let manager: EnvironmentManager!
    open var customHostTextFieldPlaceholder: String?
    
    private var model = Model()
    
    private class Model {
        var sections = [EnvironmentSectionItem]()
        
        func append(_ section: EnvironmentSectionItem) {
            sections.append(section)
        }
        
        subscript(indexPath: IndexPath) -> ConfigurationRowItem? {
            return self[indexPath.section, indexPath.row]
        }
        
        subscript(section:Int, row:Int) -> ConfigurationRowItem? {
            if sections.count > section && sections[section].count > row {
                return sections[section][row]
            }
            return nil
        }
        
        
        subscript(section: Int) -> EnvironmentSectionItem? {
            if sections.count > section {
                return sections[section]
            }
            return nil
        }
    }
    
    public required init(manager: EnvironmentManager, style: UITableView.Style = .grouped) {
        self.manager = manager
        super.init(style: style)
    }
    
    public required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    open override func viewDidLoad() {
        super.viewDidLoad()

        updateModel(reloadData: false)
        
        tableView.rowHeight = 44
        tableView.sectionHeaderHeight = 34
    }

    open override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    fileprivate func updateModel(reloadData: Bool) {
        model = Model()
        if let environments = manager.environments?.environments {
            environments.forEach { (environment) in
                let section = EnvironmentSectionItem(manager: manager, environment: environment)
                model.append(section)
            }
        }
        if reloadData {
            tableView.reloadData()
        }
    }
    
    fileprivate func isSelected(_ item: ConfigurationRowItem) -> Bool {
        return item.isSelected
    }

    // MARK: - Table view data source
    
    open override func tableView(_ tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
        return tableView.sectionHeaderHeight
    }

    open override func numberOfSections(in tableView: UITableView) -> Int {
        return self.model.sections.count
    }

    open override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return self.model[section]!.count
    }

    let configItemReuseIdentifier:String = "com.squidkit.hostConfigurationDetailCellReuseIdentifier"
    let userItemReuseIdentifier:String = "com.squidkit.hostConfigurationDetailCellUserReuseIdentifier"
    open override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        var cell: UITableViewCell?
        
        let configItem = self.model[indexPath]!
        
        if !configItem.isEditable {
            cell = tableView.dequeueReusableCell(withIdentifier: configItemReuseIdentifier)
            if cell == nil {
                cell = UITableViewCell(style: .subtitle, reuseIdentifier: configItemReuseIdentifier)
            }
            
            cell?.textLabel!.text = configItem.title
            cell?.detailTextLabel!.text = configItem.detailTitle
        }
        else {
            cell = EditableHostCell(style: .default, reuseIdentifier: userItemReuseIdentifier)
            
            let customCell = cell as! EditableHostCell
            customCell.configItem = configItem
            customCell.placeholder = customHostTextFieldPlaceholder
            customCell.delegate = self
        }
        
        cell?.accessoryType = self.isSelected(configItem) ? .checkmark : .none
        
        return cell!
    }
    
    open override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        if let item = self.model[indexPath] {
            item.selectBlock(item, indexPath, self)
        }
    }
}

//MARK: - EditableHostCellDelegate
extension EnvironmentTableViewController: EditableHostCellDelegate {
    func hostTextDidChange(_ hostText: String?, configItem: ConfigurationRowItem) {
        configItem.setHost(hostText)
        updateModel(reloadData: true)
    }
}

protocol EditableHostCellDelegate {
    func hostTextDidChange(_ hostText: String?, configItem: ConfigurationRowItem)
}

open class EditableHostCell: UITableViewCell, UITextFieldDelegate {
    var textField: UITextField?
    var configItem: ConfigurationRowItem?
    var delegate: EditableHostCellDelegate?
    var placeholder: String?
    
    open override func layoutSubviews() {
        super.layoutSubviews()
        if textField == nil {
            textField = UITextField(frame:self.contentView.bounds.insetBy(dx: 15, dy: 5))
            self.contentView.addSubview(textField!)
            textField?.placeholder = placeholder ?? "Enter custom host (e.g. \"api.host.com\")"
            textField?.font = UIFont(descriptor: UIFontDescriptor.preferredFontDescriptor(withTextStyle: UIFont.TextStyle.subheadline), size: 13)
            textField?.keyboardType = .URL
            textField?.returnKeyType = .done
            textField?.autocorrectionType = .no
            textField?.autocapitalizationType = .none
            textField?.clearButtonMode = .whileEditing
            textField?.delegate = self
            textField?.text = configItem!.detailTitle
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











