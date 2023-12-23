//
//  MainMenu.swift
//  Hidppgui
//
//  Created by Yoshimasa Niwa on 12/16/23.
//

import Foundation
import SwiftUI

private extension NSPasteboard {
    func copy(string: String) {
        clearContents()
        setString(string, forType: .string)
    }
}

struct ServiceStatusView: View {
    // TODO: Change this to @Binding
    @Bindable
    var service: Service

    var body: some View {
        switch service.state {
        case .error:
            Text(
                "Unknown Error",
                tableName: "MainMenu",
                comment: "A main menu item appears when there is an unknown error."
            )
        case .waitingProcessTrusted:
            Text(
                "Waiting Accessibility Access…",
                tableName: "MainMenu",
                comment: "A main menu item appears when the application is waiting Accessibility Access."
            )
        case .none, .ready:
            Toggle(isOn: $service.isEnabled) {
                Text(
                    "Enabled",
                    tableName: "MainMenu",
                    comment: "A main menu item to toggle enable or disable service."
                )
            }
            if let lastError = service.lastError {
                Section(String(
                    localized: "Error",
                    table: "MainMenu",
                    comment: "A main menu section title appears with the last error message."
                )) {
                    Text(lastError.localizedDescription)
                }
            }
        }
    }
}

struct LoginItemView: View {
    // TODO: Change this to @Binding
    @Bindable
    var loginItem: LoginItem

    var body: some View {
        Toggle(isOn: $loginItem.isEnabled) {
            Text(
                "Start on Login",
                tableName: "MainMenu",
                comment: "A main menu item to start the application on login."
            )
        }
    }
}

struct DeviceView: View {
    @Binding
    var device: Device

    var body: some View {
        Menu {
            Section(String(
                localized: "Serial Number",
                table: "MainMenu",
                comment: "A menu section title appears with the serial number for each device."
            )) {
                Button {
                    NSPasteboard.general.copy(string: device.serialNumber)
                } label: {
                    Text(device.serialNumber)
                }
            }
            Picker(selection: $device.preferredDPI) {
                ForEach(device.supportedDPIs, id: \.self) { dpi in
                    Text("\(dpi)")
                        .tag(dpi as UInt16)
                }
            } label: {
                Text(
                    "DPI Sensitivity",
                    tableName: "MainMenu",
                    comment: "A menu item for each device to select one of supported DPIs in child menu items."
                )
            }
            Toggle(isOn: $device.isLinearScrollWheelEnabled) {
                Text(
                    "Linear wheel scroll",
                    tableName: "MainMenu",
                    comment: "A menu item for each device to toggle enable or disable linear wheel scroll."
                )
            }
            Toggle(isOn: $device.isSwapScrollWheelEventAxisWithCommandKeyEnabled) {
                Text(
                    "Swap wheel axis with Command key",
                    tableName: "MainMenu",
                    comment: "A menu item for each device to toggle enable or disable swapping scroll wheel event axis with command key."
                )
            }
        } label: {
            Text(device.name)
        }
    }
}

struct MainMenu: View {
    @Environment(AppDelegate.self)
    private var appDelegate

    var body: some View {
        if let service = appDelegate.service {
            Section {
                ServiceStatusView(service: service)
            }
            if !service.devices.isEmpty {
                Section {
                    ForEach(Bindable(service).devices) { $device in
                        DeviceView(device: $device)
                    }
                }
            }
        }

        Section {
            if let loginItem = appDelegate.loginItem {
                LoginItemView(loginItem: loginItem)
            }
            Button {
                appDelegate.presentAboutPanel()
            } label: {
                Text(
                    "About \(appDelegate.localizedName)",
                    tableName: "MainMenu",
                    comment: "A main menu item to present a window about the application."
                )
            }
            Button {
                appDelegate.terminate()
            } label: {
                Text(
                    "Quit \(appDelegate.localizedName)",
                    tableName: "MainMenu",
                    comment: "A main menu item to terminate the application."
                )
            }
            .keyboardShortcut("Q")
        }
    }
}
