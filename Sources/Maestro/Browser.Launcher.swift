
import Foundation
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

        // ./chrome-headless-shell --headless  --remote-debugging-port=0      ~/Downloads/chrome-headless-shell-mac-arm64

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

        func launch() async throws -> URL {

            let url = try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<URL, Swift.Error>) in
                state = .launching(continuation)
                Task {
                    await _launch(continuation: continuation)
                }
            }

            print("*** Done launching: \(url)")

            return url
        }

        private func _launch(continuation: CheckedContinuation<URL, Swift.Error>) async {
            do {
                let result = try await run(
                    .path("/Users/rdingman/Downloads/chrome-headless-shell-mac-arm64/chrome-headless-shell"),
                    arguments: ["--headless=new", "--remote-debugging-port=0", ""],
                    output: .discarded,
                    error: .sequence(lowWater: 0),
                    body: { execution in
                        state = .launched(continuation, execution)
                        //                    continuation.resume()

                        print("Status: \(execution.processIdentifier)")
                        var contents = ""

                        for try await chunk in execution.standardError {
                            let string = chunk.withUnsafeBytes { String(decoding: $0, as: UTF8.self) }
                            print(string)
                            contents += string

                            let regex = /DevTools listening on (.+)/
                            if let result = try? regex.firstMatch(in: contents), let url = URL(string: String(result.1)) {
                                print("Whole match: \(result.0)")
                                print("Capture group: \(result.1)")
                                guard case .launched(let continuation, _) = state else {
                                    continue
                                }
                                state = .running(url, execution)
                                continuation.resume(returning: url)
                            }

                            // TODO: Implement a timeout for receiving the web socket url

                            //
                            //                        if string == "Done" {
                            //                            // Stop execution
                            //                            await execution.teardown(
                            //                                using: [
                            //                                    .gracefulShutDown(
                            //                                        allowedDurationToNextStep: .seconds(0.5)
                            //                                    )
                            //                                ]
                            //                            )
                            //                            return contents
                            //                        }
                        }
                    })

                print("Status: \(result.terminationStatus)")
                // TODO: Handle abnormal termination status
            } catch {
                // TODO: Handle error
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
