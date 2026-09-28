import Foundation
import SwiftUI
import UIKit

@MainActor
final class ChatSyncService: ObservableObject {
    static let shared = ChatSyncService()

    @Published var totalUnread: Int = 0
    @Published var conversations: [ChatConversation] = []
    @Published var currentActiveRoomId: String? = nil

    private var syncTask: Task<Void, Never>? = nil
    private var isFirstSync = true
    private var lastMessageTimestamps: [String: String] = [:]
    private var backgroundTaskId: UIBackgroundTaskIdentifier = .invalid

    init() {
        setupLifecycleObservers()
    }

    private func setupLifecycleObservers() {
        NotificationCenter.default.addObserver(
            forName: UIApplication.didEnterBackgroundNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.handleDidEnterBackground()
        }

        NotificationCenter.default.addObserver(
            forName: UIApplication.willEnterForegroundNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.handleWillEnterForeground()
        }
    }

    func start(userId: String) {
        stop()
        isFirstSync = true
        syncTask = Task { [weak self] in
            while !Task.isCancelled {
                await self?.performSync(userId: userId)
                try? await Task.sleep(nanoseconds: 3_000_000_000) // 3s
            }
        }
    }

    func stop() {
        syncTask?.cancel()
        syncTask = nil
    }

    func performSync(userId: String) async {
        do {
            let fresh = try await SupabaseApi.shared.getConversations()
            await MainActor.run {
                self.processFreshConversations(fresh, userId: userId)
            }
        } catch {
            // Ignore network drop
        }
    }

    private func processFreshConversations(_ fresh: [ChatConversation], userId: String) {
        let unreadSum = fresh.reduce(0) { $0 + ($1.unread_count ?? 0) }
        self.totalUnread = unreadSum
        self.conversations = fresh

        // Update iOS application icon badge
        UIApplication.shared.applicationIconBadgeNumber = unreadSum

        for c in fresh {
            let lastCreatedAt = c.last_message?.created_at ?? ""
            let prevCreatedAt = lastMessageTimestamps[c.id]

            if !isFirstSync && !lastCreatedAt.isEmpty && lastCreatedAt != prevCreatedAt {
                let senderId = c.last_message?.sender_id ?? ""
                // Only alert if the message was sent by someone else
                if senderId != userId {
                    let title = c.resolvedTitle(myUserId: userId)
                    let preview: String
                    if let content = c.last_message?.content, !content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        preview = content
                    } else if let att = c.last_message?.attachment_name, !att.isEmpty {
                        preview = "[Tệp] \(att)"
                    } else {
                        preview = "Đã gửi một tin nhắn mới"
                    }

                    // If user is currently looking at this exact room, let ChatRoomScreen handle sound,
                    // otherwise deliver full banner notification with sound
                    if currentActiveRoomId != c.id {
                        NotificationManager.shared.triggerMessageNotification(
                            title: title,
                            body: preview,
                            conversationId: c.id
                        )
                    }
                }
            }

            if !lastCreatedAt.isEmpty {
                lastMessageTimestamps[c.id] = lastCreatedAt
            }
        }

        isFirstSync = false
    }

    private func handleDidEnterBackground() {
        // Request background task to keep checking messages for a period
        backgroundTaskId = UIApplication.shared.beginBackgroundTask(withName: "ChatSyncTask") { [weak self] in
            if let bgId = self?.backgroundTaskId, bgId != .invalid {
                UIApplication.shared.endBackgroundTask(bgId)
                self?.backgroundTaskId = .invalid
            }
        }
    }

    private func handleWillEnterForeground() {
        if backgroundTaskId != .invalid {
            UIApplication.shared.endBackgroundTask(backgroundTaskId)
            backgroundTaskId = .invalid
        }
        // Immediately refresh badge and sound readiness
        SoundManager.shared.prepareAudio()
    }
}
