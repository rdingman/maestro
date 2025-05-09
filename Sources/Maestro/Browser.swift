
import Foundation
import OSLog

public actor Browser {
    let client: Client
    let defaultBrowserContext: Context
    let logger = Logger(subsystem: "Maestro", category: "Browser")
    let targetManager: TargetManager

    public init() async throws {
        client = Client()

        await client.registerEventTypes([
            Target.TargetCreatedEvent.self,
            Target.AttachedToTargetEvent.self,
            Target.DetachedFromTargetEvent.self,
            Target.TargetInfoChangedEvent.self,
            Target.TargetDestroyedEvent.self,
            Page.LifecycleEvent.self
        ])
        try await client.launch()
        let browserContextIds = try await client.sendCommand(Target.GetBrowserContextsCommand())
        print("*** Browser Context Ids: \(browserContextIds)")
        try await client.sendCommand(Target.SetDiscoverTargetsCommand(discover: true))

        let browserContextId = try await client.sendCommand(Target.CreateBrowserContextCommand()).browserContextId
        print("*** Created Browser Context: \(browserContextId)")
        defaultBrowserContext = Browser.Context(id: browserContextId, client: client)

        targetManager = await TargetManager(client: client)

        print("*** Done creating browser")
    }

    deinit {
        let client = self.client
        Task {
            try await client.close()
        }
        print("*** Done")
    }

    func createBrowserContext() async throws -> Browser.Context {
        let browserContextId = try await client.sendCommand(Target.CreateBrowserContextCommand()).browserContextId
        print("*** Created Browser Context: \(browserContextId)")
        return Browser.Context(id: browserContextId, client: client)
    }

    public func newPage() async throws -> Page {
        let createTargetResponse = try await client.sendCommand(Target.CreateTargetCommand(url: URL(string: "about:blank")!, browserContextId: defaultBrowserContext.id))
        let sessionId = try await client.sendCommand(Target.AttachToTargetCommand(targetId: createTargetResponse.targetId)).sessionId
        try await client.sendCommand(Page.SetLifecycleEventsEnabledCommand(enabled: true), to: sessionId)
        try await client.sendCommand(Page.EnableCommand(), to: sessionId)
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
