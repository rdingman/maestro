
import Foundation

extension Browser {
    final class Context: Sendable {
        let id: String
        let client: Client

        init(id: String, client: Client) {
            self.id = id
            self.client = client
        }
    }
}
