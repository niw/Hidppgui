//
//  Service.swift
//  Hidppgui
//
//  Created by Yoshimasa Niwa on 12/16/23.
//

import AppKit
import Foundation
import ServiceSupport
import SwiftUI

@MainActor
@Observable
final class Service {
    enum State: String, Equatable, Sendable {
        case none
        case error
        case waitingProcessTrusted
        case ready
    }

    private(set) var state: State = .none

    var devices: [Device] = [] {
        didSet {
            guard oldValue != devices else {
                return
            }
            guard let mouseService else {
                return
            }
            // Apply changes on the main executor to the service executor.
            Task {
                await mouseService.updateDevices(with: devices)
            }
        }
    }

    var lastError: (any Error)?

    private let mouseServiceSettings: Settings = Settings(rootKey: "devices")

    private var mouseService: MouseService?

    var isEnabled: Bool {
        get {
            mouseService != nil
        }
        set {
            guard state == .ready else {
                return
            }

            guard newValue != isEnabled else {
                return
            }

            if newValue {
                let mouseService = MouseService(settings: mouseServiceSettings)
                self.mouseService = mouseService
                Task {
                    await mouseService.didChangeDevices { [weak self] devices in
                        // Take changes on the service executor to the main executor.
                        Task { @MainActor [weak self] in
                            self?.devices = devices
                        }
                    }
                    await mouseService.didChangeLastError { [weak self] error in
                        // Take changes on the service executor to the main executor.
                        Task { @MainActor [weak self] in
                            self?.lastError = error
                        }
                    }
                    await mouseService.start()
                }
            } else {
                mouseService = nil
                devices = []
                lastError = nil
            }
        }
    }

    func start() async throws {
        guard state == .none else {
            return
        }

        state = .waitingProcessTrusted
        do {
            try await Accessibility.waitForBeingProcessTrusted()
        } catch {
            state = .error
            throw error
        }

        state = .ready

        isEnabled = true
    }

    func updateDevices() async {
        guard let mouseService else {
            return
        }
        await mouseService.updateDevices()
    }
}
