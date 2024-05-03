//
//  AppDelegate.swift
//  Hidppgui
//
//  Created by Yoshimasa Niwa on 12/16/23.
//

import AppKit
import Foundation
import Observation

@MainActor
@Observable
final class AppDelegate: NSObject {
    var localizedName: String {
        for case let infoDictionary? in [
            Bundle.main.localizedInfoDictionary,
            Bundle.main.infoDictionary
        ] {
            for key in [
                "CFBundleDisplayName",
                "CFBundleName"
            ] {
                if let localizedName = infoDictionary[key] as? String {
                    return localizedName
                }
            }
        }

        // Should not reach here.
        return ""
    }

    func presentAboutPanel() {
        if (NSApp.activationPolicy() == .accessory) {
            NSApp.activate(ignoringOtherApps: true)
        }
        NSApp.orderFrontStandardAboutPanel()
    }

    func terminate() {
        NSApp.terminate(nil)
    }

    private(set) var loginItem: LoginItem?

    private(set) var service: Service?

    private func startService() {
        let service = Service()
        self.service = service

        Task {
            try await service.start()
        }
    }
}

extension AppDelegate: NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        loginItem = LoginItem()
        startService()
    }
}
