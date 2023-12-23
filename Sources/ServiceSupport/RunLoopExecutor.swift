//
//  RunLoopExecutor.swift
//  ServiceSupport
//
//  Created by Yoshimasa Niwa on 4/13/24.
//

import Foundation

public final class RunLoopExecutor: Sendable, SerialExecutor {
    private class RunLoopThread: Thread, @unchecked Sendable {
        private class Job: NSObject {
            private let job: UnownedJob
            private let executor: UnownedSerialExecutor

            init(_ job: consuming ExecutorJob, on executor: any SerialExecutor) {
                self.job = UnownedJob(job)
                self.executor = executor.asUnownedSerialExecutor()
            }

            func run() {
                job.runSynchronously(on: executor)
            }
        }

        private class Block: NSObject {
            private let block: () -> Void

            init(_ block: @escaping () -> Void) {
                self.block = block
            }

            func run() {
                block()
            }
        }

        private let port = NSMachPort()

        override func main() {
            RunLoop.current.add(port, forMode: .default)

            while !isCancelled {
                autoreleasepool {
                    _ = RunLoop.current.run(mode: .default, before: .distantFuture)
                }
            }
        }

        override func cancel() {
            super.cancel()

            // Signal to the run loop run to exit the current loop.
            let message = PortMessage(send: port, receive: nil, components: nil)
            message.send(before: .distantFuture)
        }

        func enqueue(_ job: consuming ExecutorJob, on executor: any SerialExecutor) {
            let job = Job(job, on: executor)
            perform(#selector(run(job:)), on: self, with: job, waitUntilDone: false)
        }

        @objc
        private func run(job: Job) {
            job.run()
        }

        func enqueue(_ block: @escaping () -> Void) {
            let block = Block(block)
            perform(#selector(run(block:)), on: self, with: block, waitUntilDone: false)
        }

        @objc
        private func run(block: Block) {
            block.run()
        }
    }

    private let thread = RunLoopThread()

    public init() {
        thread.start()
    }

    deinit {
        thread.cancel()
    }

    public func enqueue(_ job: consuming ExecutorJob) {
        thread.enqueue(job, on: self)
    }

    public func enqueue(_ block: @escaping () -> Void) {
        thread.enqueue(block)
    }
}
