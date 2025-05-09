
import Foundation
import OSLog
import Subprocess

extension Browser {
    actor Launcher {
        enum State {
            case initial
            case launching(CheckedContinuation<URL, Swift.Error>)
            case launched(CheckedContinuation<URL, Swift.Error>, Execution<DiscardedOutput, SequenceOutput>)
            case running(URL, Execution<DiscardedOutput, SequenceOutput>)
            case stopped
        }

        enum Error: Swift.Error {
            case timeout
        }

        let logger = Logger(subsystem: "Maestro", category: "Browser Launcher")

        deinit {
            print("*** Deinit")
        }

        private var state: State = .initial

        var webSocketUrl: URL? {
            if case .running(let url, _) = state {
                return url
            } else {
                return nil
            }
        }

        func launch(timeout: ContinuousClock.Duration? = .milliseconds(250)) async throws -> URL {
            let url = try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<URL, Swift.Error>) in
                state = .launching(continuation)
                Task {
                    await _launch(timeout: timeout, continuation: continuation)
                }
            }

            logger.debug("Browser launched and listening on: \(url)")

            return url
        }

        private func _launch(timeout: ContinuousClock.Duration?, continuation: CheckedContinuation<URL, Swift.Error>) async {
            do {
                let result = try await run(
                    .path("/Users/rdingman/Downloads/chrome-headless-shell-mac-arm64/chrome-headless-shell"),
                    arguments: ["--headless=new", "--remote-debugging-port=0"],
                    output: .discarded,
                    error: .sequence(lowWater: 0),
                    body: { execution in
                        state = .launched(continuation, execution)

                        logger.debug("Launched Chrome with process identifier \(execution.processIdentifier)")

                        let timeoutTask: Task<Void, Never>?

                        if let timeout {
                            timeoutTask = Task {
                                do {
                                    try await Task.sleep(for: timeout)
                                    guard !Task.isCancelled else { return }
                                    didReceiveLaunchError(Error.timeout)
                                } catch {
                                    // Do nothing. We are expecting the CancellationError
                                }
                            }
                        } else {
                            timeoutTask = nil
                        }

                        var contents = " "

                        for try await chunk in execution.standardError {
                            let string = chunk.withUnsafeBytes { String(decoding: $0, as: UTF8.self) }
                            contents += string

                            let regex = /DevTools listening on (.+)/
                            if let result = try? regex.firstMatch(in: contents), let url = URL(string: String(result.1)) {
                                timeoutTask?.cancel()

                                guard case .launched(let continuation, _) = state else {
                                    continue
                                }
                                state = .running(url, execution)
                                continuation.resume(returning: url)
                            }
                        }
                    })

                // TODO: Handle abnormal termination status
                logger.debug("Browser exited with status: \(result.terminationStatus)")
            } catch {
                didReceiveLaunchError(error)
            }
        }

        func close() async throws {
            switch state {
            case .initial, .launching, .stopped:
                break

            case .launched(_, let execution), .running(_, let execution):
                await execution.teardown(using: [
                    .gracefulShutDown(allowedDurationToNextStep: .seconds(0.5))
                ])
            }

        }

        private func didReceiveLaunchError(_ error: Swift.Error) {
            switch state {

            case .launching(let continuation), .launched(let continuation, _):
                state = .stopped
                continuation.resume(throwing: error)

            case .initial, .running, .stopped:
                break
            }
        }
    }
}
