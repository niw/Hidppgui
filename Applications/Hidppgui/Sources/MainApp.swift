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

                // `didEndTrackingNotification` is posted when any `NSMenu` stops tracking when closed for example.
                // In this application with current implementation, it must be only happening when the main menu is dismissed,
                // and use it as an arbitrary event to refresh devices for now.
                // Can't use `didBeginTrackingNotification`, which likely change menu items while it is tracking,
                // which causes menu items disappearing probably due to SwiftUI implementation issue.
                .onReceive(NotificationCenter.default.publisher(for: NSMenu.didEndTrackingNotification)) { notification in
                    // TODO: Ensure it is for `MainMenu()` as well.
                    guard let _ = notification.object as? NSMenu else {
                        return
                    }
                    Task {
                        await appDelegate.service?.updateDevices()
                    }
                }
        }
    }
}
