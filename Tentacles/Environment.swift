//
//  Environment.swift
//  Tentacles
//
//  Created by Mike Leavy on 6/27/18.
//  Copyright © 2018 Squid Store. All rights reserved.
//

import Foundation

public struct Environment: Codable {
    /**
    This notification is emitted when the configuration of an environemnt changes.
     Typically, this happens when a configuration is changed via a trip to the EnvironmentTableViewController.
     The emitted notification will contain a user info dictionary with the following keys/values:
     "configuration" the new Configuration (if not nil)
     "environment" the Environment fow which the configuration has changed
     */
    public static let environmentConfigurationChangedNotification = NSNotification.Name(rawValue: "com.squidstore.tentacles.notification.environment.configuration.changed")
    
    public let name: String
    public let defaultConfigurationName: String
    public let productionConfigurationName: String?
    public let testingConfigurationName: String?
    public var configurations: [Configuration]?
    
    enum CodingKeys: String, CodingKey {
        case name
        case defaultConfigurationName = "default_configuration_name"
        case productionConfigurationName = "production_configuration_name"
        case testingConfigurationName = "testing_configuration_name"
        case configurations
    }
    
    public mutating func setHost(_ host: String?, index: Int) -> Bool {
        var result = false
        if var mutableConfiguration = configurations?[index] {
            result = mutableConfiguration.setHost(host, environment: self)
            if result {
                configurations?.replaceSubrange(index...index, with: [mutableConfiguration])
            }
        }
        return result
    }
    
    public mutating func setHost(_ host: String?, forConfiguration: Configuration) -> Bool {
        guard let configurationIndex = configurations?.firstIndex(where: { (configuration) -> Bool in
            return configuration.name == forConfiguration.name
        }) else {return false}
        return setHost(host, index: configurationIndex)
    }
}

public struct Configuration: Codable {
    public let name: String
    private var host: String?
    private var editedHost: String?
    public let scheme: String?
    public let variables: [Variable]?
    
    private static let editedHostKeyPrefix = "com.squidkit.tentacles."
    
    public var isHostMutable: Bool {
        return host == nil
    }
    
    public var hostName: String? {
        return editedHost ?? host
    }
    
    enum CodingKeys: String, CodingKey {
        case name
        case host
        case editedHost
        case scheme
        case variables
    }
    
    public struct Variable: Codable {
        public let key: String
        public let value: String
        
        enum CodingKeys: String, CodingKey {
            case key
            case value
        }
    }
    
    public mutating func setHost(_ host: String?, environment: Environment) -> Bool {
        guard isHostMutable else {return false}
        self.editedHost = (host?.isEmpty ?? false) ? nil : host
        let key = Configuration.editedHostKey(configuration: self, environment: environment)
        UserDefaults.standard.set(self.editedHost, forKey: key)
        return true
    }
    
    fileprivate static func editedHost(configuration: Configuration, environment: Environment) -> String? {
        let key = Configuration.editedHostKey(configuration: configuration, environment: environment)
        return UserDefaults.standard.string(forKey: key)
    }
    
    private static func editedHostKey(configuration: Configuration, environment: Environment) -> String {
        return editedHostKeyPrefix + environment.name + "." + configuration.name
    }
}

public struct EnvironmentCollection: Codable {
    public var environments: [Environment]?
    
    enum CodingKeys: String, CodingKey {
        case environments
    }
    
    mutating func setHost(_ host: String?, forEnvironment: Environment, forConfiguration: Configuration) -> Bool {
        var result = false
        guard let environmentIndex = environments?.firstIndex(where: { (environment) -> Bool in
            return environment.name == forEnvironment.name
        }) else {return false}
        
        if var mutatableEnvironment = environments?[environmentIndex] {
            result = mutatableEnvironment.setHost(host, forConfiguration: forConfiguration)
            if result {
                environments?.replaceSubrange(environmentIndex...environmentIndex, with: [mutatableEnvironment])
            }
        }
        return result
    }
}

public protocol EnvironmentCachable {
    func set(configuration: Configuration?, forEnvironment: Environment)
    func get(environment: Environment) -> Configuration?
}

public class EnvironmentManager {
    
    public enum ConfigurationType {
        case production
        case testing
        case custom(String)
    }
    
    public var environments: EnvironmentCollection?
    public var cache: EnvironmentCachable = TentaclesEnvironmentCache()
    public var defaultScheme = "https"
    
    public static let shared = EnvironmentManager()
    
    public var allHosts: [String] {
        var all = [String]()
        environments?.environments?.forEach({ (environment) in
            environment.configurations?.forEach({ (configuration) in
                if let host = configuration.hostName {
                    all.append(host)
                }
            })
        })
        return all
    }
    
    public var allActiveHosts: [String] {
        var all = [String]()
        environments?.environments?.forEach({ (environment) in
            if let h = host(for: environment) {
                all.append(h)
            }
        })
        return all
    }
    
    public init() {
        
    }
    
    public convenience init(cache: EnvironmentCachable) {
        self.init()
        self.cache = cache
    }
    
    public func host(named: String, forEnvironment: Environment) -> String? {
        return forEnvironment.configurations?.first(where: { (configuration) -> Bool in
            return configuration.name.caseInsensitiveCompare(named) == .orderedSame
        })?.hostName
    }
    
    public func scheme(named: String, forEnvironment: Environment) -> String {
        return forEnvironment.configurations?.first(where: { (configuration) -> Bool in
            return configuration.name.caseInsensitiveCompare(named) == .orderedSame
        })?.scheme ?? defaultScheme
    }
    
    public func url(named: String, forEnvironment: Environment) -> URL? {
        guard let config = forEnvironment.configurations?.first(where: { (configuration) -> Bool in
            return configuration.name.caseInsensitiveCompare(named) == .orderedSame
        }) else {return nil}
        return url(with: config.scheme, host: config.hostName)
    }
    
    public func use(configuration: Configuration?, forEnvironment: Environment) {
        cache.set(configuration: configuration, forEnvironment: forEnvironment)
        let configName = configuration?.name ?? "nil"
        Tentacles.shared.log("Setting configuration named \"\(configName)\" for environment named \"\(forEnvironment.name)\"", level: .info)
        var userInfo: [AnyHashable: Any] = ["environment": forEnvironment]
        if let config = configuration {
            userInfo["configuration"] = config
        }
        NotificationCenter.default.post(name: Environment.environmentConfigurationChangedNotification, object: nil, userInfo: userInfo)
    }
    
    public func use(_ configurationType: ConfigurationType, forEnvironment: Environment) {
        switch configurationType {
        case .production:
            if let productionName = forEnvironment.productionConfigurationName {
                use(configuration: configuration(named: productionName, forEnviornment: forEnvironment), forEnvironment: forEnvironment)
            }
            else {
                Tentacles.shared.log("Could not set production configuration for environment named \"\(forEnvironment.name)\" because environment does not contain a \"production_configuration_name\" key", level: .warning)
            }
        case .testing:
            if let testingName = forEnvironment.testingConfigurationName {
                use(configuration: configuration(named: testingName, forEnviornment: forEnvironment), forEnvironment: forEnvironment)
            }
            else {
                Tentacles.shared.log("Could not set testing configuration for environment named \"\(forEnvironment.name)\" because environment does not contain a \"testing_configuration_name\" key", level: .warning)
            }
        case .custom(let name):
            use(configuration: configuration(named: name, forEnviornment: forEnvironment), forEnvironment: forEnvironment)
        }
    }
    
    public func host(for environment: Environment) -> String? {
        if let e = cache.get(environment: environment) {
            return e.hostName ?? defaultConfiguration(for: environment)?.hostName
        }
        return defaultConfiguration(for: environment)?.hostName
    }
    
    public func host(for environmentNamed: String) -> String? {
        if let environment = environment(named: environmentNamed) {
            return host(for: environment)
        }
        return nil
    }
    
    public func scheme(for environment: Environment) -> String {
        if let e = cache.get(environment: environment) {
            return e.scheme ?? (defaultConfiguration(for: environment)?.scheme ?? defaultScheme)
        }
        return defaultConfiguration(for: environment)?.scheme ?? defaultScheme
    }
    
    public func scheme(for environmentNamed: String) -> String {
        if let environment = environment(named: environmentNamed) {
            return scheme(for: environment)
        }
        return defaultScheme
    }
    
    public func url(for environment: Environment) -> URL? {
        return url(with: scheme(for: environment), host: host(for: environment))
    }
    
    @discardableResult
    public func setHost(_ host: String?, forEnvironment: Environment, forConfiguration: Configuration) -> Bool {
        return environments?.setHost(host, forEnvironment: forEnvironment, forConfiguration: forConfiguration) ?? false
    }
    
    private func defaultConfiguration(for environment: Environment) -> Configuration? {
        let first = environment.configurations?.first(where: { (configuration) -> Bool in
            return configuration.name.caseInsensitiveCompare(environment.defaultConfigurationName) == .orderedSame
        })
        return first
    }
    
    public func environment(named: String) -> Environment? {
        return environments?.environments?.first(where: { (environment) -> Bool in
            return environment.name.caseInsensitiveCompare(named) == .orderedSame
        })
    }
    
    internal func configuration(named: String, forEnviornment: Environment) -> Configuration? {
        return forEnviornment.configurations?.first(where: { (configuration) -> Bool in
            return configuration.name.caseInsensitiveCompare(named) == .orderedSame
        })
    }
    
    private func url(with scheme: String?, host: String?) -> URL? {
        let urlString = (scheme ?? defaultScheme) + "://" + (host ?? "")
        return URL(string: urlString)
    }
    
}

//MARK: - Environment loading
public extension EnvironmentManager {
    
    func loadEnvironments(resourceFileName: String) throws {
        guard var url = Bundle.main.resourceURL else {
            let error = NSError.tentaclesError(code: .fileNotFoundError, localizedDescription: NSLocalizedString("Could not find URL for application's main bundle", comment: "main bundle not found error"))
            Tentacles.shared.log(error.localizedDescription, level: .error)
            throw error
        }
        url = url.appendingPathComponent(resourceFileName, isDirectory: false)
        guard let data = try? Data(contentsOf: url) else {
            let error = NSError.tentaclesError(code: .invalidData, localizedDescription: NSLocalizedString("Could not get data from resource file", comment: "data from resource file error"))
            Tentacles.shared.log(error.localizedDescription, level: .error)
            throw error
        }
        
        try loadEnvironments(from: data)
    }
    
    func loadEnvironments(jsonString: String) throws {
        guard let jsonData = jsonString.data(using: .utf8) else {
            let error = NSError.tentaclesError(code: .invalidData, localizedDescription: NSLocalizedString("Could not get data from json string", comment: "data from json string error"))
            Tentacles.shared.log(error.localizedDescription, level: .error)
            throw error
        }
        try loadEnvironments(from: jsonData)
    }
    
    func loadEnvironments(dictionary: [String: Any]) throws {
        
        do {
            let jsonData = try JSONSerialization.data(withJSONObject: dictionary, options: [])
            try loadEnvironments(from: jsonData)
        }
        catch(let error) {
            Tentacles.shared.log(error.localizedDescription, level: .error)
            throw(error)
        }
    }
    
    private func loadEnvironments(from data: Data) throws {
        let decoder = JSONDecoder()
        do {
            environments = try decoder.decode(EnvironmentCollection.self, from: data)
            if let envs = environments?.environments {
                for environment in envs {
                    guard let config = environment.configurations else {continue}
                    for configuation in config {
                        if configuation.isHostMutable, let hostName = Configuration.editedHost(configuration: configuation, environment: environment)  {
                            setHost(hostName, forEnvironment: environment, forConfiguration: configuation)
                        }
                    }
                }
            }
        }
        catch(let error) {
            Tentacles.shared.log(error.localizedDescription, level: .error)
            throw(error)
        }
    }
}

//MARK: - Variable Replacement
extension EnvironmentManager {
    
    private func variables(for environment: Environment) -> [Configuration.Variable]? {
        if let e = cache.get(environment: environment) {
            return e.variables
        }
        return defaultConfiguration(for: environment)?.variables
    }
    
    private func variables(for patterns: [String], environment: Environment) -> [String] {
        guard let variables = variables(for: environment) else {return patterns}
        var result = [String]()
        patterns.forEach { (string) in
            let candidate = string.replacingOccurrences(of: "{", with: "").replacingOccurrences(of: "}", with: "")
            if let replacement = variables.first(where: { (variable) -> Bool in
                return variable.key == candidate
            }) {
                result.append(replacement.value)
            }
            else {
                result.append(string)
            }
        }
        return result
    }
    
    public func replaceVariables(in text: String, for environment: Environment) -> String {
        let expression = "\\{(.*?)\\}"
        let patterns = matches(for: expression, in: text)
        guard patterns.count > 0 else {return text}
        let replacements = variables(for: patterns, environment: environment)
        guard replacements.count == patterns.count else {return text}
        guard replacements != patterns else {return text}
        var result = text
        for i in 0..<patterns.count {
            result = result.replacingOccurrences(of: patterns[i], with: replacements[i])
        }
        return result
    }
    
    func matches(for regex: String, in text: String) -> [String] {
        
        do {
            let regex = try NSRegularExpression(pattern: regex)
            let results = regex.matches(in: text,
                                        range: NSRange(text.startIndex..., in: text))
            let strings = results.map {
                String(text[Range($0.range, in: text)!])
            }
            return strings
            
        } catch let error {
            Tentacles.shared.logger?.log("invalid regex: \(error.localizedDescription)", level: .error)
            return []
        }
    }
}

private struct TentaclesEnvironmentCache: EnvironmentCachable {
    func set(configuration: Configuration?, forEnvironment: Environment) {
        if let config = configuration {
            UserDefaults.standard.set(try? PropertyListEncoder().encode(config), forKey: forEnvironment.name)
        }
        else {
            UserDefaults.standard.set(nil, forKey: forEnvironment.name)
        }
        UserDefaults.standard.synchronize()
    }
    
    func get(environment: Environment) -> Configuration? {
        guard let data = UserDefaults.standard.value(forKey: environment.name) as? Data else {
            return nil
        }
        return try? PropertyListDecoder().decode(Configuration.self, from: data)
    }
}





