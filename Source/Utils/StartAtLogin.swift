//
//  StartAtLogin.swift
//
//  Copyright © 2017 Evgeny Aleksandrov. All rights reserved.

import Foundation
import ServiceManagement

struct StartAtLogin {
    static var isEnabled: Bool {
        set {
            if newValue {
                try? SMAppService.mainApp.register()
            } else {
                try? SMAppService.mainApp.unregister()
            }
        }
        get {
            return SMAppService.mainApp.status == .enabled
        }
    }
}
