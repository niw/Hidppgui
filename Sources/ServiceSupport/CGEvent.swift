//
//  CGEvent.swift
//  ServiceSupport
//
//  Created by Yoshimasa Niwa on 12/18/23.
//

import AppKit
import Foundation

private extension Int64 {
    var direction: Int64 {
        (self > 0) ? 1 : (self < 0) ? -1 : 0
    }
}

private extension RunLoop.Mode {
    var CFRunLoopMode: CFRunLoopMode {
        CoreFoundation.CFRunLoopMode(rawValue as CFString)
    }
}

private extension CFRunLoopSource {
    func schedule(on runLoop: RunLoop, mode: RunLoop.Mode) {
        CFRunLoopAddSource(runLoop.getCFRunLoop(), self, mode.CFRunLoopMode)
    }

    func unschedule(from runLoop: RunLoop, mode: RunLoop.Mode) {
        CFRunLoopRemoveSource(runLoop.getCFRunLoop(), self, mode.CFRunLoopMode)
    }
}

private extension CFMachPort {
    func createCFRunLoopSource(order: CFIndex = 0) -> CFRunLoopSource {
        CFMachPortCreateRunLoopSource(kCFAllocatorDefault, self, order)
    }
}

public extension CGEvent {
    var deviceRegistryEntryID: UInt64 {
        // This is undocumented CGEventField for the IORegistry entry ID of the event source device.
        guard let field = CGEventField(rawValue: 87) else {
            // Should not reach here.
            return 0
        }
        return UInt64(getIntegerValueField(field))
    }

    var isMouseScrollWheelEvent: Bool {
        // If the device is a trackpad, deviceID may be non-nil non-zero.
        NSEvent(cgEvent: self)?.deviceID == 0
    }

    func updateAsLinearScrollWheelEvent() {
        let verticalDelta = getIntegerValueField(.scrollWheelEventDeltaAxis1)
        setIntegerValueField(.scrollWheelEventDeltaAxis1, value: verticalDelta.direction * 3)
        let horizontalDelta = getIntegerValueField(.scrollWheelEventDeltaAxis2)
        setIntegerValueField(.scrollWheelEventDeltaAxis2, value: horizontalDelta.direction * 6)
    }

    func swapScrollWheelEventAxisWithCommandKey() {
        guard self.flags.contains(.maskCommand) else {
            return
        }

        let verticalDelta = getIntegerValueField(.scrollWheelEventDeltaAxis1)
        let horizontalDelta = getIntegerValueField(.scrollWheelEventDeltaAxis2)
        setIntegerValueField(.scrollWheelEventDeltaAxis2, value: verticalDelta)
        setIntegerValueField(.scrollWheelEventDeltaAxis1, value: horizontalDelta)
    }

    final class Tap {
        private let callback: (CGEvent) -> Void
        private var tap: CFMachPort?

        public init(
            location: CGEventTapLocation,
            place: CGEventTapPlacement,
            options: CGEventTapOptions,
            eventsOfInterest: CGEventMask,
            callback: @escaping (CGEvent) -> Void
        ) {
            self.callback = callback
            self.tap = CGEvent.tapCreate(
                tap: location,
                place: place,
                options: options,
                eventsOfInterest: eventsOfInterest,
                callback: { (
                    proxy: CGEventTapProxy,
                    type: CGEventType,
                    event: CGEvent,
                    refcon: UnsafeMutableRawPointer?
                ) -> Unmanaged<CGEvent>? in
                    // TODO: Handle the event that tap is being disabled.
                    if type != .tapDisabledByTimeout,
                       type != .tapDisabledByUserInput,
                       let refcon
                    {
                        let this = Unmanaged<CGEvent.Tap>.fromOpaque(refcon).takeUnretainedValue()
                        this.callback(event)
                    }
                    return Unmanaged.passUnretained(event)
                },
                userInfo: Unmanaged.passUnretained(self).toOpaque()
            )
        }

        deinit {
            disable()
        }

        private struct Source {
            var runLoopSource: CFRunLoopSource
            var runLoop: RunLoop
            var runLoopMode: RunLoop.Mode

            func schedule() {
                runLoopSource.schedule(on: runLoop, mode: runLoopMode)
            }

            func unschedule() {
                runLoopSource.unschedule(from: runLoop, mode: runLoopMode)
            }
        }

        private var currentSource: Source?

        public var isEnabled: Bool {
            currentSource != nil
        }

        public func enable(on runLoop: RunLoop, mode: RunLoop.Mode) {
            guard currentSource == nil, let tap else {
                return
            }

            let runLoopSource = tap.createCFRunLoopSource()
            let source = Source(runLoopSource: runLoopSource, runLoop: runLoop, runLoopMode: mode)
            source.schedule()
            CGEvent.tapEnable(tap: tap, enable: true)

            self.currentSource = source
        }

        public func disable() {
            guard let currentSource, let tap else {
                return
            }

            CGEvent.tapEnable(tap: tap, enable: false)
            currentSource.unschedule()

            self.currentSource = nil
        }
    }
}
