//
//  DeviceSetting.swift
//  Hidppgui
//
//  Created by Yoshimasa Niwa on 4/22/24.
//

import Foundation

struct DeviceSetting: Sendable {
    enum CodingKeys: String, CodingKey {
        case serialNumber = "SerialNumber"

        case preferredDPI = "PreferredDPI"
        case isLinearScrollWheelEnabled = "IsLinearScrollWheelEnabled"
        case isSwapScrollWheelEventAxisWithCommandKeyEnabled = "IsSwapScrollWheelEventAxisWithCommandKeyEnabled"
    }

    var serialNumber: String

    var preferredDPI: UInt16?
    var isLinearScrollWheelEnabled: Bool?
    var isSwapScrollWheelEventAxisWithCommandKeyEnabled: Bool?
}

extension DeviceSetting: Identifiable {
    var id: String {
        serialNumber
    }
}

extension DeviceSetting: Settings.Setting {
    var settingDictionary: NSDictionary {
        var dictionary = [String : Any]()
        if let preferredDPI {
            dictionary[CodingKeys.preferredDPI.stringValue] = preferredDPI
        }
        if let isLinearScrollWheelEnabled {
            dictionary[CodingKeys.isLinearScrollWheelEnabled.stringValue] = isLinearScrollWheelEnabled
        }
        if let isSwapScrollWheelEventAxisWithCommandKeyEnabled {
            dictionary[CodingKeys.isSwapScrollWheelEventAxisWithCommandKeyEnabled.stringValue] = isSwapScrollWheelEventAxisWithCommandKeyEnabled
        }
        return dictionary as NSDictionary
    }

    init?(settingDictionary dictionary: NSDictionary, forKey key: String) {
        let serialNumber = key

        let preferredDPI = dictionary[CodingKeys.preferredDPI.stringValue] as? UInt16
        let isLinearScrollWheelEnabled = dictionary[CodingKeys.isLinearScrollWheelEnabled.stringValue] as? Bool
        let isSwapScrollWheelEventAxisWithCommandKeyEnabled = dictionary[CodingKeys.isSwapScrollWheelEventAxisWithCommandKeyEnabled] as? Bool

        self.init(
            serialNumber: serialNumber,
            preferredDPI: preferredDPI,
            isLinearScrollWheelEnabled: isLinearScrollWheelEnabled,
            isSwapScrollWheelEventAxisWithCommandKeyEnabled: isSwapScrollWheelEventAxisWithCommandKeyEnabled
        )
    }
}
