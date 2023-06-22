//
//  Logger.swift
//  TentaclesExample
//
//  Created by Mike Leavy on 6/26/18.
//  Copyright © 2018 Squid Store. All rights reserved.
//

import Tentacles

class Logger: Logable {
    func log(_ message: String, level: TentaclesLogLevel) {
        print(message)
    }
}

