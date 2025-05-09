
import Foundation
extension Browser {

    enum Target {
        struct Info: Decodable {
            //    {"targetId":"8BCDA6CEAF141A53692197A27C8B746D","type":"page","title":"about:blank","url":"about:blank","attached":true,"canAccessOpener":false,"browserContextId":"8958D1CAA1B94AC2CEE189C01E006512"}
            let targetId: String
            let type: String
            let title: String
            let url: URL?
            let attached: Bool
            let canAccessOpener: Bool
            let browserContextId: String

            enum CodingKeys: CodingKey {
                case targetId
                case type
                case title
                case url
                case attached
                case canAccessOpener
                case browserContextId
            }

            init(from decoder: any Decoder) throws {
                let container = try decoder.container(keyedBy: CodingKeys.self)
                self.targetId = try container.decode(String.self, forKey: .targetId)
                self.type = try container.decode(String.self, forKey: .type)
                self.title = try container.decode(String.self, forKey: .title)

                do {
                    self.url = try container.decodeIfPresent(URL.self, forKey: .url)
                } catch {
                    let string = try container.decodeIfPresent(String.self, forKey: .url)

                    if let string {
                        if string == "" {
                            self.url = nil
                        } else {
                            throw error
                        }
                    } else {
                        self.url = nil
                    }
                }

                self.attached = try container.decode(Bool.self, forKey: .attached)
                self.canAccessOpener = try container.decode(Bool.self, forKey: .canAccessOpener)
                self.browserContextId = try container.decode(String.self, forKey: .browserContextId)
            }
        }
    }
}

// MARK: - Events

extension Browser.Target {
    struct TargetInfoChangedEvent: Browser.Client.Event {
        let targetInfo: Info
    }

    struct TargetCreatedEvent: Browser.Client.Event {
        let targetInfo: Info
    }

    struct AttachedToTargetEvent: Browser.Client.Event {
        let sessionId: String
        let targetInfo: Info
    }

    struct DetachedFromTargetEvent: Browser.Client.Event {
        let sessionId: String
        let targetId: String?
    }

    struct TargetDestroyedEvent: Browser.Client.Event {
        let targetId: String
    }
}

// MARK: - Commands

extension Browser.Target {
    struct AttachToTargetCommand: Browser.Client.Command {
        let params: Parameters

        init(targetId: String) {
            self.params = .init(targetId: targetId)
        }

        struct Parameters: Encodable {
            let targetId: String
            let flatten: Bool = true
        }
        struct Response: Decodable {
            let sessionId: String
        }
    }

    struct CreateTargetCommand: Browser.Client.Command {
        let params: Parameters

        init(url: URL, browserContextId: String? = nil) {
            self.params = .init(url: url, browserContextId: browserContextId)
        }

        struct Parameters: Encodable {
            let url: URL
            let browserContextId: String?
        }
        struct Response: Decodable {
            let targetId: String
        }
    }

    struct TargetInfoCommand: Browser.Client.Command {
        let params: Parameters

        init(url: URL) {
            self.params = .init(url: url)
        }

        struct Parameters: Encodable {
            let url: URL
        }
        struct Response: Decodable {
            let targetId: String
        }
    }

    struct CloseTargetCommand: Browser.Client.Command {
        let params: Parameters

        init(targetId: String) {
            self.params = .init(targetId: targetId)
        }

        struct Parameters: Encodable {
            let targetId: String
        }
        struct Response: Decodable {
            let success: Bool
        }
    }

    struct CreateBrowserContextCommand: Browser.Client.Command {
        let params: Parameters

        init() {
            self.params = .init()
        }

        struct Parameters: Encodable {
        }

        struct Response: Decodable {
            let browserContextId: String
        }
    }

    struct GetBrowserContextsCommand: Browser.Client.Command {
        let params: Parameters

        init() {
            self.params = .init()
        }

        struct Parameters: Encodable {
        }

        struct Response: Decodable {
            let browserContextIds: [String]
        }
    }

    struct SetDiscoverTargetsCommand: Browser.Client.Command {
        let params: Parameters

        init(discover: Bool) {
            self.params = .init(discover: discover)
        }

        struct Parameters: Encodable {
            let discover: Bool
        }

        typealias Response = Void
    }
}
