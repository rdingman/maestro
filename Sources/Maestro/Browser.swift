
import Foundation
import OSLog

protocol EventHandler {
    func handleEvent<E: Browser.Client.Event>(_ event: E) async throws
}

public actor Browser {
    let client: Client
    let defaultBrowserContext: Context
    let logger = Logger(subsystem: "Maestro", category: "Browser")

    public init() async throws {
        client = Client()

        await client.registerEventTypes([
            Target.TargetCreatedEvent.self,
            Target.AttachedToTargetEvent.self,
            Target.TargetInfoChangedEvent.self,
            Target.TargetDestroyedEvent.self
        ])
        try await client.launch()
        let browserContextIds = try await client.sendCommand(Target.GetBrowserContextsCommand())
        print("*** Browser Context Ids: \(browserContextIds)")
        try await client.sendCommand(Target.SetDiscoverTargetsCommand(discover: true))

        let browserContextId = try await client.sendCommand(Target.CreateBrowserContextsCommand()).browserContextId
        print("*** Created Browser Context: \(browserContextId)")
        defaultBrowserContext = Browser.Context(id: browserContextId, client: client)

        Task {
            for try await event in client.channel {
                logger.debug("**** Event: \(String(describing: event))")
            }
        }
    }

    deinit {
        let client = self.client
        Task {
            try await client.close()
        }
        print("*** Done")
    }

    func createBrowserContext() async throws -> Browser.Context {
        let browserContextId = try await client.sendCommand(Target.CreateBrowserContextsCommand()).browserContextId
        print("*** Created Browser Context: \(browserContextId)")
        return Browser.Context(id: browserContextId, client: client)
    }

    public func newPage() async throws -> Page {
        let createTargetResponse = try await client.sendCommand(Target.CreateTargetCommand(url: URL(string: "about:blank")!, browserContextId: defaultBrowserContext.id))
        let sessionId = try await client.sendCommand(Target.AttachToTargetCommand(targetId: createTargetResponse.targetId)).sessionId
        return Page(targetId: createTargetResponse.targetId, sessionId: sessionId, browserContextId: defaultBrowserContext.id, client: client)
    }

    public func close() async throws {
        try await client.sendCommand(CloseCommand())
    }
}

// MARK: - Commands

extension Browser {
    struct CloseCommand: Client.Command {
        let method = "Browser.close"
        let params: Parameters

        init() {
            self.params = .init()
        }

        struct Parameters: Encodable {
        }

        typealias Response = Void
    }

    struct GetVersionCommand: Client.Command {
        let method = "Browser.getVersion"
        let params: Parameters

        init() {
            self.params = .init()
        }

        struct Parameters: Encodable {
        }

        struct Response: Decodable {
            let jsVersion: String
            let product: String
            let protocolVersion: String
            let revision: String
            let userAgent: String
        }
    }
}
