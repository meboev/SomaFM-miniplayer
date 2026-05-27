//
//  Log.swift
//
//  Copyright © 2026 Milen Boev. All rights reserved.

import Foundation
import os.log

public struct Log {
    static let log = OSLog(subsystem: Bundle.main.bundleIdentifier ?? "unknown", category: "App")

    // (off by default, never saved to disk)
    static public func debug(_ message: Any) {
        os_log("◾️ %@", log: log, type: .debug, "\(message)")
    }

    // (defaults to memory, saved to disk if there is error or fault)
    static public func info(_ message: Any) {
        os_log("🔷 %@", log: log, type: .info, "\(message)")
    }

    // (always saved to disk)
    static public func warning(_ message: Any) {
        os_log("🔶 %@", log: log, type: .default, "\(message)")
    }

    // (always saved  to disk)
    static public func error(_ message: Any) {
        os_log("❌ %@", log: log, type: .error, "\(message)")
    }
}
