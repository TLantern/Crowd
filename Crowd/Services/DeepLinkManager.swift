import Foundation
import SwiftUI
import Combine

final class DeepLinkManager: ObservableObject {
    static let shared = DeepLinkManager()

    @Published var pendingEventId: String?

    private init() {}

    func handle(url: URL) {
        guard url.path.contains("/event/") else { return }
        let eventId = url.lastPathComponent

        DispatchQueue.main.async {
            self.pendingEventId = eventId
        }
    }
}
