//
//  Log.swift
//  Odysee
//
//  Created by Adlai on 5/18/21.
//

import Foundation
import os

struct Log {
    // Uncomment to print all JSON responses in debug mode.
//    static let verboseJSON = OSLog(subsystem: "com.lbry.odysee", category: "json")
    static let verboseJSON = OSLog.disabled
}
