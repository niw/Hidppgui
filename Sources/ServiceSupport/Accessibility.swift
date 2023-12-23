//
//  Accessibility.swift
//  ServiceSupport
//
//  Created by Yoshimasa Niwa on 12/16/23.
//

import AppKit
import Foundation

public enum Accessibility {
    private final actor TrustedProcess {
        @MainActor
        private static func isProcessTrusted(promptToUser: Bool = false) -> Bool {
            let options = [
                kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: promptToUser
            ] as CFDictionary

            return AXIsProcessTrustedWithOptions(options)
        }

        private var isPromptedToUser = false

        private var waitingTask: Task<Void, any Error>?
        private var waitingCount = 0

        func wait() async throws {
            let task: Task<Void, any Error>
            if let waitingTask {
                task = waitingTask
            } else {
                let promptToUser = !isPromptedToUser
                isPromptedToUser = true
                guard await !Self.isProcessTrusted(promptToUser: promptToUser) else {
                    return
                }
                // Reentrant.
                if let waitingTask {
                    task = waitingTask
                } else {
                    task = Task.detached {
                        while true {
                            try Task.checkCancellation()
                            try await SuspendingClock().sleep(until: .now + .seconds(3))
                            if await Self.isProcessTrusted() {
                                break
                            }
                        }
                    }
                    waitingTask = task
                }
            }

            defer {
                // Reentrant.
                waitingCount -= 1
                if waitingCount == 0 {
                    task.cancel()
                    waitingTask = nil
                }
            }
            waitingCount += 1
            try await task.value
        }
    }

    private static let trustedProcess = TrustedProcess()

    public static func waitForBeingProcessTrusted() async throws {
        try await trustedProcess.wait()
    }
}
