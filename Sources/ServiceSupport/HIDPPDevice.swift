//
//  HIDPPDevice.swift
//  ServiceSupport
//
//  Created by Yoshimasa Niwa on 1/7/24.
//

import Foundation
import HIDPP

public extension HIDPPDevice {
    var eventServiceEntryID: UInt64 {
        get async throws {
            let entryID = try await registryEntryID
            let service = IOServiceGetMatchingService(kIOMainPortDefault, IORegistryEntryIDMatching(entryID))

            var iterator = io_iterator_t()
            let result = IORegistryEntryCreateIterator(service, kIOServicePlane, IOOptionBits(kIORegistryIterateRecursively), &iterator)
            guard result == KERN_SUCCESS else {
                throw HIDError.IOReturn(result)
            }
            defer {
                IOObjectRelease(iterator)
            }

            var entry: io_service_t
            while true {
                entry = IOIteratorNext(iterator)
                guard entry != .zero else {
                    break
                }
                // `io_name_t` is `char[128]`.j
                var buffer = [CChar](repeating: .zero, count: 128)
                guard IORegistryEntryGetName(entry, &buffer) == KERN_SUCCESS else {
                    break
                }
                let name = String(cString: buffer)
                if name == "AppleUserHIDEventDriver" {
                    var entryID = UInt64()
                    let result = IORegistryEntryGetRegistryEntryID(entry, &entryID)
                    guard result == KERN_SUCCESS else {
                        throw HIDError.IOReturn(result)
                    }
                    return entryID
                }
            }

            return .zero
        }
    }
}
