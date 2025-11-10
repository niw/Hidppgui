//
//  MouseService.swift
//  Hidppgui
//
//  Created by Yoshimasa Niwa on 4/15/24.
//

import CoreGraphics
import Foundation
import HIDPP
import ServiceSupport

// See the inline comments on `MouseService.deinit`.
extension CGEvent.Tap: @retroactive @unchecked Sendable {
}

// See the inline comments on `MouseService.start()`.
private final class UncheckedBox<T>: @unchecked Sendable {
    var didChange: ((T) -> Void)?

    var value: T {
        didSet {
            didChange?(value)
        }
    }

    init(_ value: T) {
        self.value = value
    }
}

private extension HIDPPDevice.Battery {
    var battery: Battery {
        let state: Battery.State = if let status {
            switch status {
            case .discharging, .charged:
                .discharging
            case .almostFull, .charging, .slowRecharge:
                .charging
            case .invalidBattery, .terminalError, .otherError:
                .unknown
            }
        } else {
            .unknown
        }
        return Battery(state: state, percentage: Int(percentage))
    }
}

// NOTE: This is intentionally `class` which thread safety is managed by the caller.
// Since some properties (such as `isRegularScrollWheelEnabled`) need to be accessed synchronously,
// This is implemented as `class`.
// `@unchecked Sendable` is specified due to Swift compiler bug.
// See the inline comments on `init(hidppDevice:)`.
private final class MouseDevice: @unchecked Sendable {
    let hidppDevice: HIDPPDevice

    let name: String
    let serialNumber: String
    let eventServiceEntryID: UInt64
    let supportedDPIs: [UInt16]

    private(set) var battery: HIDPPDevice.Battery

    func updateBattery(on _: isolated any Actor) async throws {
        battery = try await hidppDevice.battery
    }

    private(set) var preferredDPI: UInt16

    private func setPreferredDPI(_ value: UInt16, on _: isolated any Actor) async throws {
        // Called on the given actor executor.
        if preferredDPI != value {
            // Optimistically update the current value.
            let oldValue = preferredDPI
            preferredDPI = value
            do {
                try await hidppDevice.setDPI(value)
            } catch {
                preferredDPI = oldValue
                throw error
            }
        }
    }

    private(set) var isLinearScrollWheelEnabled: Bool = false
    private(set) var isSwapScrollWheelEventAxisWithCommandKeyEnabled: Bool = false

    // TODO: Remove `@unchecked Sendable` and give `isolated any Actor` argument here.
    // Use `isolated any Actor` argument here instead to provide actor context to the initializer.
    // It's not possible for now due to Swift compiler bug which crashes if `isolated` is used
    // on `async` initializer.
    // See <https://github.com/apple/swift/issues/71174>.
    init(hidppDevice: HIDPPDevice) async throws {
        // Called on arbitrary executor.
        self.hidppDevice = hidppDevice

        name = try await hidppDevice.name
        serialNumber = try await hidppDevice.serialNumber
        eventServiceEntryID = try await hidppDevice.eventServiceEntryID
        battery = try await hidppDevice.battery
        switch try await hidppDevice.DPIList() {
        case .values(let values):
            supportedDPIs = values
        case .stride(let stride):
            supportedDPIs = Array(stride)
        }

        preferredDPI = try await hidppDevice.DPI()
    }

    func set(device: Device, on actor: isolated any Actor) async throws {
        // Called on the given actor executor.
        isLinearScrollWheelEnabled = device.isLinearScrollWheelEnabled
        isSwapScrollWheelEventAxisWithCommandKeyEnabled = device.isSwapScrollWheelEventAxisWithCommandKeyEnabled
        try await setPreferredDPI(device.preferredDPI, on: actor)
    }

    var device: Device {
        Device(
            name: name,
            serialNumber: serialNumber,
            eventServiceEntryID: eventServiceEntryID,
            battery: battery.battery,
            supportedDPIs: supportedDPIs,
            preferredDPI: preferredDPI,
            isLinearScrollWheelEnabled: isLinearScrollWheelEnabled,
            isSwapScrollWheelEventAxisWithCommandKeyEnabled: isSwapScrollWheelEventAxisWithCommandKeyEnabled
        )
    }

    func set(setting: DeviceSetting, on actor: isolated any Actor) async throws {
        // Called on the given actor executor.
        if let isLinearScrollWheelEnabled = setting.isLinearScrollWheelEnabled {
            self.isLinearScrollWheelEnabled = isLinearScrollWheelEnabled
        }
        if let isSwapScrollWheelEventAxisWithCommandKeyEnabled = setting.isSwapScrollWheelEventAxisWithCommandKeyEnabled {
            self.isSwapScrollWheelEventAxisWithCommandKeyEnabled = isSwapScrollWheelEventAxisWithCommandKeyEnabled
        }
        if let preferredDPI = setting.preferredDPI {
            try await setPreferredDPI(preferredDPI, on: actor)
        }
    }

    var setting: DeviceSetting {
        DeviceSetting(
            serialNumber: serialNumber,
            preferredDPI: preferredDPI,
            isLinearScrollWheelEnabled: isLinearScrollWheelEnabled,
            isSwapScrollWheelEventAxisWithCommandKeyEnabled: isSwapScrollWheelEventAxisWithCommandKeyEnabled
        )
    }
}

final actor MouseService {
    private let settings: Settings

    private let executor = RunLoopExecutor()

    nonisolated var unownedExecutor: UnownedSerialExecutor {
        executor.asUnownedSerialExecutor()
    }

    var lastError: (any Error)? {
        didSet {
            didChangeLastError?(lastError)
        }
    }

    private func setLastError(_ error: (any Error)?) {
        lastError = error
    }

    private var didChangeLastError: (((any Error)?) -> Void)?

    func didChangeLastError(_ handler: (@Sendable ((any Error)?) -> Void)?) {
        didChangeLastError = handler
    }

    private var mouseDevices = UncheckedBox([UInt64 : MouseDevice]())

    var devices: [Device] {
        mouseDevices.value.values.map(\.device)
    }

    func didChangeDevices(_ handler: (@Sendable ([Device]) -> Void)?) {
        if let handler {
            mouseDevices.didChange = { devices in
                handler(devices.values.map(\.device))
            }
        } else {
            mouseDevices.didChange = nil
        }
    }

    func updateDevices(with devices: [Device]) async {
        let mouseDevices = mouseDevices.value
        for device in devices {
            guard let mouseDevice = mouseDevices[device.eventServiceEntryID] else {
                continue
            }
            do {
                try await mouseDevice.set(device: device, on: self)
                await settings.saveSetting(mouseDevice.setting)
            } catch {
                lastError = error
            }
        }
        // Trigger callback.
        // This is always needed because the update is reentrant.
        self.mouseDevices.value = mouseDevices
    }

    private func addHIDPPDevice(_ hidppDevice: HIDPPDevice) async throws {
        // See inline comments on `MouseDevice.init(hidppDevice:)` about the executor.
        let mouseDevice = try await MouseDevice(hidppDevice: hidppDevice)
        let key = mouseDevice.eventServiceEntryID

        await mouseDevice.hidppDevice.useRemovalHandler { [weak self] _ in
            // Called on arbitrary executor.
            Task { [weak self] in
                guard let self else {
                    return
                }
                await self.removeMouseDevice(forKey: key)
            }
        }

        if let deviceSetting: DeviceSetting = await settings.setting(forKey: mouseDevice.serialNumber) {
            do {
                try await mouseDevice.set(setting: deviceSetting, on: self)
            } catch {
                lastError = error
            }
        }

        mouseDevices.value[key] = mouseDevice
    }

    private func removeMouseDevice(forKey key: UInt64) {
        mouseDevices.value.removeValue(forKey: key)
    }

    private var eventTap: CGEvent.Tap?
    private var task: Task<Void, Never>?

    init(settings: Settings) {
        self.settings = settings
    }

    deinit {
        // Called on arbitrary executor.
        task?.cancel()

        // `CGEvent.Tap` added `@unchecked Sendable` to avoid a warning here.
        if let eventTap {
            executor.enqueue {
                // Called on the run loop thread, which is this actor's executor.
                eventTap.disable()
            }
        }
    }

    func start() {
        guard eventTap == nil, task == nil else {
            return
        }

        // This is to capture `@unchecked Sendable` wrapped value for accessing it bypass
        // the actor boundary check in the following `CGEvent.Tap` handler.
        let mouseDevices = mouseDevices

        let eventTap = CGEvent.Tap(
            location: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .defaultTap,
            eventsOfInterest: CGEventMask(1 << CGEventType.scrollWheel.rawValue)
        ) { event in
            // Called on the run loop thread, which is this actor's executor.
            guard event.isMouseScrollWheelEvent else {
                return
            }
            guard let device = mouseDevices.value[event.deviceRegistryEntryID] else {
                return
            }
            if device.isLinearScrollWheelEnabled == true {
                event.updateAsLinearScrollWheelEvent()
            }
            if device.isSwapScrollWheelEventAxisWithCommandKeyEnabled == true {
                event.swapScrollWheelEventAxisWithCommandKey()
            }
        }

        eventTap.enable(on: .current, mode: .common)
        self.eventTap = eventTap

        let stream = HIDPPDevice.enumerateDevices(on: .current, mode: .default)
        let task = Task { [weak self] in
            // Called on arbitrary executor. Actor context is not inherited.
            do {
                for try await hidppDevice in stream {
                    guard let self else {
                        continue
                    }
                    do {
                        try await self.addHIDPPDevice(hidppDevice)
                    } catch {
                        await self.setLastError(error)
                    }
                }
            } catch {
                guard let self else {
                    return
                }
                await self.setLastError(error)
            }
        }
        self.task = task
    }

    func updateDevices() async {
        let mouseDevices = mouseDevices.value
        for mouseDevice in mouseDevices.values {
            do {
                try await mouseDevice.updateBattery(on: self)
            } catch {
                self.lastError = error
            }
        }
        // Trigger callback.
        // This is always needed because the update is reentrant.
        self.mouseDevices.value = mouseDevices
    }
}
