
import Foundation
import OSLog

extension Browser {
    actor TargetManager: Client.EventHandler {
        let client: Client

        var targets: [String: Browser.Target.Info] = [:]
        let logger = Logger(subsystem: "Maestro", category: "Target Manager")

        init(client: Client) async {
            self.client = client

            await client.registerHandler(self, for: [
                Target.TargetCreatedEvent.self,
                Target.AttachedToTargetEvent.self,
                Target.DetachedFromTargetEvent.self,
                Target.TargetInfoChangedEvent.self,
                Target.TargetDestroyedEvent.self
            ])
        }

        func handleEvent<E>(_ event: E) async where E : Browser.Client.Event {
            logger.debug("**** Target Event: \(String(describing: event))")

//            if let event = event as? Target.TargetCreatedEvent {
//                targets[event.targetInfo.targetId] = event.targetInfo
//            } else if let event = event as? Target.AttachedToTargetEvent {
//                // TODO: Manage session
//            } else if let event = event as? Target.DetachedFromTargetEvent {
//                // TODO: Manage session
//            } else if let event = event as? Target.TargetInfoChangedEvent {
//                targets[event.targetInfo.targetId] = event.targetInfo
//            } else if let event = event as? Target.TargetDestroyedEvent {
//                targets[event.targetId] = nil
//            }
        }
    }
}
