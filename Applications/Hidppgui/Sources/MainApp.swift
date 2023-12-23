//
//  MainApp.swift
//  Hidppgui
//
//  Created by Yoshimasa Niwa on 12/16/23.
//

import Foundation
import SwiftUI

@main
struct MainApp: App {
    @NSApplicationDelegateAdaptor
    private var appDelegate: AppDelegate

    var body: some Scene {
        MenuBarExtra(appDelegate.localizedName, systemImage: "computermouse") {
            MainMenu()
                // `@NSApplicationDelegateAdaptor` supposed to put the object in the Environment
                // as its documentation said, however, in reality, it only works for `WindowGroup` views.
                // Therefore we need to manually put it here for `MenuBarExtra` views.
                .environment(appDelegate)
        }
    }
}
