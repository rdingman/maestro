
import Foundation

extension Browser {

    public final class Page: Sendable {
        private let client: Browser.Client
        private let targetId: String
        private let sessionId: String
        private let browserContextId: String
        internal init(targetId: String, sessionId: String, browserContextId: String, client: Browser.Client) {
            self.targetId = targetId
            self.sessionId = sessionId
            self.browserContextId = browserContextId
            self.client = client
        }

        public func printToPDF() async throws -> Data {
            let response = try await self.client.sendCommand(Page.PrintToPDFCommand(), to: sessionId)
            return response.data
        }

        public func navigation(to url: URL) async throws -> Void {
            // TODO: Deal with failure to load
            //
            // ⮕ {"id":6,"result":{"frameId":"8BCDA6CEAF141A53692197A27C8B746D","loaderId":"7AC17E254B99923DEFBB4F2F76CD5CDB","errorText":"net::ERR_NAME_NOT_RESOLVED"},"sessionId":"DA9B8249DBB4122535696AFCAE143BB4"}

            let response = try await self.client.sendCommand(Page.NavigateCommand(url: url), to: sessionId)
        }

        public func reload() async throws -> Void {
            try await self.client.sendCommand(Page.ReloadCommand(), to: sessionId)
        }

    }
}

extension Browser.Page {

    struct EnableCommand: Browser.Client.Command {
        let method = "Page.enable"
        let params: Parameters

        init(targetId: String, sessionId: String, browserContextId: String) {
            self.params = .init(targetId: targetId, sessionId: sessionId, browserContextId: browserContextId)
        }

        struct Parameters: Encodable {
            let targetId: String
            let sessionId: String
            let browserContextId: String
        }

        typealias Response = Void
    }

    struct PrintToPDFCommand: Browser.Client.Command {
        let method = "Page.printToPDF"
        let params: Parameters

        init() {
            self.params = .init()
        }

        struct Parameters: Encodable {
            let returnAsStream: Bool = true
        }

        struct Response: Decodable {
            let data: Data
        }
    }

    struct ReloadCommand: Browser.Client.Command {
        let method = "Page.reload"
        let params: Parameters

        init() {
            self.params = .init()
        }

        struct Parameters: Encodable {
        }

        typealias Response = Void
    }

    struct NavigateCommand: Browser.Client.Command {
        let method = "Page.navigate"
        let params: Parameters

        init(url: URL) {
            self.params = .init(url: url)
        }

        struct Parameters: Encodable {
            let url: URL
        }

        struct Response: Decodable {
            let frameId: String
        }
    }
}
