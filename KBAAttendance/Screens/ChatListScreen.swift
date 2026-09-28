import SwiftUI

struct ChatListScreen: View {
    @EnvironmentObject var store: SessionStore
    @State private var conversations: [ChatConversation] = []
    @State private var loading = true
    @State private var isPolling = true
    @State private var previousTotalUnread = 0
    @State private var isFirstLoad = true

    var body: some View {
        Group {
            if loading && conversations.isEmpty {
                ProgressView()
            } else if conversations.isEmpty {
                VStack(spacing: 16) {
                    Image(systemName: "bubble.left.and.bubble.right")
                        .font(.system(size: 48))
                        .foregroundColor(.secondary)
                    Text("Chưa có cuộc trò chuyện nào.\nNhấn nút + để bắt đầu.")
                        .multilineTextAlignment(.center)
                        .foregroundColor(.secondary)
                    NavigationLink(destination: NewChatScreen()) {
                        Label("Cuộc trò chuyện mới", systemImage: "plus")
                            .font(.headline)
                            .foregroundColor(.white)
                            .padding(.horizontal, 20)
                            .padding(.vertical, 10)
                            .background(Color(red: 0.07, green: 0.45, blue: 0.20))
                            .cornerRadius(10)
                    }
                }
                .padding()
            } else {
                List(conversations) { c in
                    let myUserId = store.session.userId ?? ""
                    let title = c.resolvedTitle(myUserId: myUserId)
                    let preview = messagePreview(c.last_message)

                    NavigationLink(destination: ChatRoomScreen(conversationId: c.id, title: title)) {
                        HStack(spacing: 12) {
                            // Avatar
                            ZStack {
                                Circle()
                                    .fill(Color(red: 0.07, green: 0.45, blue: 0.20).opacity(0.15))
                                    .frame(width: 48, height: 48)
                                Text(String(title.prefix(1)).uppercased())
                                    .font(.headline)
                                    .bold()
                                    .foregroundColor(Color(red: 0.07, green: 0.45, blue: 0.20))
                            }

                            // Info
                            VStack(alignment: .leading, spacing: 4) {
                                Text(title)
                                    .font(.headline)
                                    .lineLimit(1)
                                if !preview.isEmpty {
                                    Text(preview)
                                        .font(.subheadline)
                                        .foregroundColor(.secondary)
                                        .lineLimit(1)
                                }
                            }

                            Spacer()

                            // Unread badge
                            if let unread = c.unread_count, unread > 0 {
                                Text("\(unread)")
                                    .font(.caption2)
                                    .bold()
                                    .foregroundColor(.white)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 4)
                                    .background(Color(red: 0.07, green: 0.45, blue: 0.20))
                                    .clipShape(Capsule())
                            }
                        }
                        .padding(.vertical, 4)
                    }
                }
                .listStyle(.insetGrouped)
            }
        }
        .navigationTitle("Chat nội bộ")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                NavigationLink(destination: NewChatScreen()) {
                    Image(systemName: "plus")
                        .font(.body.weight(.bold))
                }
            }
        }
        .task {
            await pollConversations()
        }
        .onDisappear {
            isPolling = false
        }
    }

    private func messagePreview(_ lm: ChatLastMessage?) -> String {
        guard let m = lm else { return "" }
        if let c = m.content, !c.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return c
        }
        if let a = m.attachment_name, !a.isEmpty {
            return "[Tệp] \(a)"
        }
        return ""
    }

    private func pollConversations() async {
        isPolling = true
        while isPolling {
            do {
                let fresh = try await SupabaseApi.shared.getConversations()
                await MainActor.run {
                    handleFreshConversations(fresh)
                }
            } catch {
                // Ignore network glitch
            }
            try? await Task.sleep(nanoseconds: 4_000_000_000) // 4s
        }
    }

    private func handleFreshConversations(_ fresh: [ChatConversation]) {
        let totalUnread = fresh.reduce(0) { $0 + ($1.unread_count ?? 0) }

        if !isFirstLoad {
            if totalUnread > previousTotalUnread {
                // Play notification sound on new unread message
                SoundManager.shared.playMessageSound()
            }
        }

        previousTotalUnread = totalUnread
        conversations = fresh
        loading = false
        isFirstLoad = false
    }
}
