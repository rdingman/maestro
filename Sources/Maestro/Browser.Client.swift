
import AsyncAlgorithms
import Foundation
import OSLog
import RegexBuilder
import Subprocess
import System

extension Browser {
    actor Client {
        enum State {
            case initial
            case launching
            case connecting(URL)
            case connected(Browser.Launcher, URLSessionWebSocketTask, Task<Void, Never>)
            case stopped
        }

        deinit {
            print("*** Deinit")
        }

        let logger = Logger(subsystem: "Maestro", category: "Chrome DevTools Protocol")

        private var state: State = .initial

        func launch() async throws {
            state = .launching
            let browserLauncher = Browser.Launcher()
            let url = try await browserLauncher.launch()

            state = .connecting(url)

            let webSocketTask = URLSession.shared.webSocketTask(with: url)

            let receiveMessagesTask = Task {
                await receiveMessages(from: webSocketTask)
            }

            state = .connected(browserLauncher, webSocketTask, receiveMessagesTask)

            webSocketTask.resume()
        }

        func close() async throws {
            if case .connected(let launcher, let uRLSessionWebSocketTask, let task) = state {
                task.cancel()
                uRLSessionWebSocketTask.cancel()
                try await launcher.close()
                state = .stopped
            }
        }

        private var voidContinuations: [Int: CheckedContinuation<Void, Swift.Error>] = [:]
        private var continuations: [Int: any Continuation] = [:]
        private var nextCommandId: Int = 1

        fileprivate protocol Continuation {
            associatedtype T: Sendable & Decodable

            func resume(returning value: sending T)
            func resume(throwing error: any Swift.Error)
        }

        protocol EventHandler: Sendable {
            func handleEvent<E: Browser.Client.Event>(_ event: E) async
        }

        struct EventRegistration {
            let eventType: any Event.Type
            var handlers: [any EventHandler] = []
        }

        private var eventRegistrations: [String: EventRegistration] = [:]

        func registerEventType<E: Event>(_ eventType: E.Type) {
            let name = eventType.name

            if let registeredEventType = eventRegistrations[name] {
                logger.error("Event already registered for: \(name), type: \(String(reflecting: registeredEventType))")
            } else {
                logger.debug("Registering event: \(name), type: \(String(reflecting: eventType))")
                eventRegistrations[name] = EventRegistration(eventType: eventType)
            }
        }

        func registerEventTypes(_ eventTypes: any Sequence<any Event.Type>) {
            for eventType in eventTypes {
                self.registerEventType(eventType)
            }
        }

        func registerHandler<H: EventHandler>(_ handler: H, for eventType: any Event.Type) {
            let name = eventType.name

            var eventRegistration: EventRegistration

            if let registration = eventRegistrations[name] {
                eventRegistration = registration
                eventRegistration.handlers.append(handler)
            } else {
                eventRegistration = EventRegistration(eventType: eventType, handlers: [handler])
            }

            eventRegistrations[name] = eventRegistration
        }

        func registerHandler<H: EventHandler>(_ handler: H, for eventTypes: [any Event.Type]) {
            for eventType in eventTypes {
                registerHandler(handler, for: eventType)
            }
        }
    }
}

extension Browser.Client {
    protocol Command<Response, Parameters> {
        associatedtype Parameters: Encodable
        associatedtype Response //: Decodable
        var method: String { get }
        var params: Parameters { get }

    }

    enum Response {
        struct Empty: Decodable {}
    }

    private struct CommandEnvelope<C: Command>: Encodable {
        let id: Int
        let sessionId: String?
        let command: C

        enum CodingKeys: CodingKey {
            case id
            case sessionId
            case method
            case params
        }

        func encode(to encoder: any Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            try container.encode(id, forKey: .id)
            try container.encodeIfPresent(sessionId, forKey: .sessionId)
            try container.encode(command.method, forKey: .method)
            try container.encode(command.params, forKey: .params)
        }
    }

    func sendCommand<C: Command>(_ command: C, to sessionId: String? = nil) async throws -> C.Response where C.Response == Void {
        let commandId = try await sendMessage(command, to: sessionId)
        return try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Swift.Error>) in
            voidContinuations[commandId] = continuation
        }
    }

    func sendCommand<C: Command>(_ command: C, to sessionId: String? = nil) async throws -> C.Response where C.Response: Decodable {
        let commandId = try await sendMessage(command, to: sessionId)
        return try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<C.Response, Swift.Error>) in
            continuations[commandId] = continuation
        }
    }

    private func sendMessage<C: Command>(_ command: C, to sessionId: String?) async throws -> Int {
        guard case .connected(_, let task, _) = state else {
            fatalError("Not connected")
        }

        let encoder = JSONEncoder()
        encoder.outputFormatting = [.withoutEscapingSlashes, .sortedKeys]

        let commandId = nextCommandId
        let commentEnvelope = CommandEnvelope(id: commandId, sessionId: sessionId, command: command)

        let messageData = try encoder.encode(commentEnvelope)
        let string = String(decoding: messageData, as: UTF8.self)
        logger.debug("⬅︎ \(string)")
        //        try await task.send(.data(Data(string.utf8)))
        try await task.send(.string(string))

        nextCommandId += 1
        return commandId
    }
}

private func canonicalName<T>(_ type: T.Type, suffix: String) -> String {
    let typeName = String(reflecting: type)

    let domain = Reference(Substring.self)
    let name = Reference(Substring.self)
    let regex = Regex {
        Capture(as: domain) {
            OneOrMore(CharacterClass.anyOf(".").inverted)
        }
        "."
        Capture(as: name) {
            OneOrMore(CharacterClass.anyOf(".").inverted)
        }
        Capture {
            suffix
        }
        /$/
    }

    if let result = try? regex.firstMatch(in: typeName) {
        let domain = result[domain]
        let name = result[name].replacing(/^(.)/, with: { $0.output.1.lowercased() })

        return "\(domain).\(name)"
    } else {
        return typeName
    }
}

extension Browser.Client.Command {
    var method: String {
        return canonicalName(Self.self, suffix: "Command")
    }
}

extension Browser.Client.Event {
    static var name: String {
        return canonicalName(Self.self, suffix: "Event")
    }
}

extension Browser.Client {
    protocol Event: Decodable, Sendable {
        static var name: String { get }
    }

    private struct ResponseEnvelope<Response: Decodable>: Decodable {
        let id: Int
        let sessionId: String?
        let result: Response?
        let error: Error?
    }

    struct Error: Decodable, Swift.Error {
        let code: Int
        let message: String
    }

    private func receiveMessages(from task: URLSessionWebSocketTask) async {
        while Task.isCancelled == false {
            do {
                let result = try await task.receive()

                guard Task.isCancelled == false else { return }

                let resultData: Data
                switch result {
                case .data(let data):
                    resultData = data

                case .string(let string):
                    resultData = Data(string.utf8)

                @unknown default:
                    resultData = Data()
                }

                let decoder = JSONDecoder()
                struct Envelope: Decodable {
                    let id: Int?
                    let method: String?
                }
                // TODO: Find a better way to peek at the 'id' property in the response
                // to figure out the real type to decode
                let envelope = try decoder.decode(Envelope.self, from: resultData)

                if let responseId = envelope.id {
                    logger.debug("⮕ \(String(decoding: resultData, as: UTF8.self))")

                    if let continuation = voidContinuations[responseId] {
                        voidContinuations[responseId] = nil
                        continuation.resume(returning: ())
                    } else if let continuation = continuations[responseId] {
                        continuations[responseId] = nil
                        self.decodeMessage(resultData, resumingWith: continuation)
                    } else {
                        print("*** Could not find continuation for id \(responseId)")
                        continue
                    }

                } else if let method = envelope.method {
                    logger.debug("⚠️ \(String(decoding: resultData, as: UTF8.self))")

                    if let eventRegistration = eventRegistrations[method] {
                        let event = try decodeEvent(eventRegistration.eventType, from: resultData)

                        for handler in eventRegistration.handlers {
                            Task.detached {
                                await handler.handleEvent(event)
                            }
                        }
                    } else {
                        logger.error("**** No event type found for method: \(method)")
                    }
                } else {
                    logger.error("Unknown message received: \(String(decoding: resultData, as: UTF8.self))")
                }

            } catch {
                if (error as NSError).domain == NSPOSIXErrorDomain && (error as NSError).code == Errno.socketNotConnected.rawValue {
                    return
                }
                // TODO: ignore errors for now
                logger.error("Error: \(error)")
            }
        }
    }

    private struct EventEnvelope<T: Event>: Decodable {
        let method: String
        let params: T
    }

    private func decodeEvent<T: Event>(_ type: T.Type, from data: Data) throws -> T {
        let decoder = JSONDecoder()
        return try decoder.decode(EventEnvelope<T>.self, from: data).params
    }

    private func decodeMessage<C: Continuation>(_ data: Data, resumingWith continuation: C) where C.T: Decodable {
        do {
            let decoder = JSONDecoder()
            decoder.dataDecodingStrategy = .base64
            let response = try decoder.decode(ResponseEnvelope<C.T>.self, from: data)

            if let result = response.result {
                continuation.resume(returning: result)
            } else if let error = response.error {
                continuation.resume(throwing: error)
            } else {
                let error = Error(code: 0, message: "Missing result or error in response")
                continuation.resume(throwing: error)
            }
        } catch {
            continuation.resume(throwing: error)
        }
    }

}

extension CheckedContinuation: Browser.Client.Continuation where T: Decodable, E == Swift.Error {

}
