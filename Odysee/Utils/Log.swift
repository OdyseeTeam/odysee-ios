//
//  Log.swift
//  Odysee
//
//  Created by Adlai Holler on 5/18/21.
//

import Foundation
import os

struct Log {
    // Uncomment to print all JSON responses in debug mode.
//    static let verboseJSON = OSLog(subsystem: "com.lbry.odysee", category: "json")
    static let verboseJSON = OSLog.disabled
}

extension OSLog {
    // If the specified log type is enabled, create and log a string.
    // Otherwise do nothing at all.
    //
    // In iOS 14+, we can replace with built-in version:
    //    os_log(.debug, log: myLog, "Thing: \(myThing.makeExpensiveString())")
    func logIfEnabled(_ type: OSLogType, _ msg: @autoclosure () -> String) {
        if isEnabled(type: type) {
            let str = msg()
            os_log(type, log: self, "%@", str)
        }
    }
}
