//
//  Preferences.swift
//  Hidppgui
//
//  Created by Yoshimasa Niwa on 4/22/24.
//

import Foundation

final actor Settings {
    protocol Setting {
        var settingDictionary: NSDictionary { get }
        init?(settingDictionary dictionary: NSDictionary, forKey key: String)
    }

    private let userDefaults = UserDefaults.standard

    private let rootKey: String

    init(rootKey: String) {
        self.rootKey = rootKey
    }

    var settings: [String : any Setting] {
        userDefaults.dictionary(forKey: rootKey) as? [String : any Setting] ?? [:]
    }

    func setting<T: Setting>(forKey key: String) -> T? {
        guard let settingsDictionary = userDefaults.dictionary(forKey: rootKey) else {
            return nil
        }
        guard let settingDictionary = settingsDictionary[key] as? NSDictionary else {
            return nil
        }
        return .init(settingDictionary: settingDictionary, forKey: key)
    }

    func saveSetting<T: Setting>(_ setting: T, forKey key: String) {
        let settingDictionary = setting.settingDictionary

        var settingsDictionary = userDefaults.dictionary(forKey: rootKey) ?? [:]
        settingsDictionary[key] = settingDictionary

        userDefaults.setValue(settingsDictionary as NSDictionary, forKey: rootKey)
    }

    func saveSetting<T: Setting & Identifiable<String>>(_ setting: T) {
        saveSetting(setting, forKey: setting.id)
    }
}
