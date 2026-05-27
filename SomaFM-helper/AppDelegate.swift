//
//  AppDelegate.swift
//
//  Copyright © 2026 Milen Boev. All rights reserved.

import Cocoa
import os.log

@main
final class AppDelegate: NSObject, NSApplicationDelegate {

    private let logger = Logger(subsystem: "com.milenboev.somafm-helper", category: "launch")

    func applicationWillFinishLaunching(_ notification: Notification) {
        // Get helper bundle id
        guard let helperBundleId = Bundle.main.bundleIdentifier, helperBundleId.hasSuffix("-helper")
            else { NSApp.terminate(nil); return }

        // Get main bundle id
        let mainAppBundleId = helperBundleId.replacingOccurrences(of: "-helper", with: "")

        // Ensure the app is not already running
        if !NSRunningApplication.runningApplications(withBundleIdentifier: mainAppBundleId).isEmpty {
            NSApp.terminate(nil); return
        }

        // Get path to main app
        let helperBundleURL = URL(fileURLWithPath: Bundle.main.bundlePath)
        let mainAppBundleURL = helperBundleURL.deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()

        // Launch main app
        NSWorkspace.shared.openApplication(at: mainAppBundleURL,
                                           configuration: NSWorkspace.OpenConfiguration()) { _, error in
            if let error = error {
                self.logger.error("Failed to launch main app: \(error.localizedDescription)")
            }
            DispatchQueue.main.async {
                NSApp.terminate(nil)
            }
        }
    }
}
