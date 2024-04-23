//
//  Device.swift
//  Hidppgui
//
//  Created by Yoshimasa Niwa on 4/13/24.
//

import Foundation

struct Battery: Sendable, Equatable {
    enum State: Sendable, Equatable {
        case discharging
        case charging
        case unknown
    }

    var state: State
    var percentage: Int
}

struct Device: Sendable, Equatable {
    var name: String
    var serialNumber: String
    var eventServiceEntryID: UInt64
    var battery: Battery
    var supportedDPIs: [UInt16]

    var preferredDPI: UInt16
    var isLinearScrollWheelEnabled: Bool
    var isSwapScrollWheelEventAxisWithCommandKeyEnabled: Bool
}

extension Device: Identifiable {
    var id: UInt64 {
        eventServiceEntryID
    }
}
