
import Foundation

extension URLSessionWebSocketTask {
    func sendPing() async throws {
        return try await withCheckedThrowingContinuation { continuation in
            sendPing { error in
                if let error {
                    continuation.resume(throwing: error)
                } else {
                    continuation.resume(returning: ())
                }
            }
        }
    }
}
