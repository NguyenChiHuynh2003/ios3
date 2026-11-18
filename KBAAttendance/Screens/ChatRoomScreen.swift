import SwiftUI

struct ChatRoomScreen: View {
    let conversationId: String
    let title: String
    @EnvironmentObject var store: SessionStore

    @State private var messages: [ChatMessage] = []
    @State private var input = ""
    @State private var isSending = false
    @State private var knownMessageIds = Set<String>()
    @State private var isFirstLoad = true
    @State private var isPolling = true

    var body: some View {
        VStack(spacing: 0) {
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(spacing: 8) {
                        ForEach(messages) { msg in
                            let isMine = msg.sender_id == (store.session.userId ?? "")
                            MessageBubble(message: msg, isMine: isMine)
                                .id(msg.id)
                        }
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 10)
                }
                .onChange(of: messages.count) { _ in
                    if let last = messages.last {
                        withAnimation {
                            proxy.scrollTo(last.id, anchor: .bottom)
                        }
                    }
                }
            }

            Divider()

            // Bottom input bar
            HStack(spacing: 8) {
                TextField("Nhập tin nhắn…", text: $input)
                    .textFieldStyle(.roundedBorder)
                    .frame(minHeight: 36)

                Button(action: sendMessage) {
                    if isSending {
                        ProgressView()
                            .tint(Color(red: 0.07, green: 0.45, blue: 0.20))
                            .frame(width: 32, height: 32)
                    } else {
                        Image(systemName: "paperplane.fill")
                            .font(.system(size: 18))
                            .foregroundColor(input.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? .gray : Color(red: 0.07, green: 0.45, blue: 0.20))
                            .frame(width: 32, height: 32)
                    }
                }
                .disabled(isSending || input.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(Color(.systemBackground))
        }
        .navigationTitle(title)
        .navigationBarTitleDisplayMode(.inline)
        .task {
            await pollMessages()
        }
        .onAppear {
            ChatSyncService.shared.currentActiveRoomId = conversationId
        }
        .onDisappear {
            isPolling = false
            ChatSyncService.shared.currentActiveRoomId = nil
        }
    }

    private func pollMessages() async {
        isPolling = true
        while isPolling {
            do {
                let fresh = try await SupabaseApi.shared.getMessages(conversationId: conversationId)
                await MainActor.run {
                    handleFreshMessages(fresh)
                }
                try? await SupabaseApi.shared.markAsRead(conversationId: conversationId)
            } catch {
                // Ignore network glitch
            }
            try? await Task.sleep(nanoseconds: 2_500_000_000) // 2.5s poll
        }
    }

    private func handleFreshMessages(_ fresh: [ChatMessage]) {
        let myId = store.session.userId ?? ""

        if !isFirstLoad {
            // Check for new incoming message from others
            var hasNewIncoming = false
            for m in fresh {
                if !knownMessageIds.contains(m.id) && m.sender_id != myId {
                    hasNewIncoming = true
                    break
                }
            }
            if hasNewIncoming {
                SoundManager.shared.playMessageSound()
            }
        }

        messages = fresh
        knownMessageIds = Set(fresh.map { $0.id })
        isFirstLoad = false
    }

    private func sendMessage() {
        let text = input.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty, let myId = store.session.userId else { return }

        isSending = true
        let payload = ChatSendPayload(
            conversation_id: conversationId,
            sender_id: myId,
            content: text
        )

        Task {
            do {
                _ = try await SupabaseApi.shared.sendMessage(payload: payload)
                await MainActor.run {
                    input = ""
                }
                let fresh = try await SupabaseApi.shared.getMessages(conversationId: conversationId)
                await MainActor.run {
                    handleFreshMessages(fresh)
                    isSending = false
                }
            } catch {
                await MainActor.run {
                    isSending = false
                }
            }
        }
    }
}

private struct MessageBubble: View {
    let message: ChatMessage
    let isMine: Bool

    var body: some View {
        HStack {
            if isMine { Spacer(minLength: 40) }

            VStack(alignment: isMine ? .trailing : .leading, spacing: 2) {
                if message.deleted_at != nil {
                    Text("Tin nhắn đã được thu hồi")
                        .font(.subheadline)
                        .italic()
                        .foregroundColor(isMine ? Color.white.opacity(0.8) : Color.secondary)
                } else if let content = message.content, !content.isEmpty {
                    Text(content)
                        .font(.body)
                        .foregroundColor(isMine ? .white : .primary)
                } else if let att = message.attachment_name, !att.isEmpty {
                    HStack(spacing: 4) {
                        Image(systemName: "paperclip")
                        Text("[Tệp] \(att)")
                    }
                    .font(.subheadline)
                    .foregroundColor(isMine ? .white : .primary)
                }

                if message.edited_at != nil && message.deleted_at == nil {
                    Text("(đã chỉnh sửa)")
                        .font(.caption2)
                        .foregroundColor(isMine ? Color.white.opacity(0.7) : Color.secondary)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(isMine ? Color(red: 0.07, green: 0.45, blue: 0.20) : Color(.secondarySystemBackground))
            .cornerRadius(14)

            if !isMine { Spacer(minLength: 40) }
        }
    }
}
