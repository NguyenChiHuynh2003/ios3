import SwiftUI

struct NewChatScreen: View {
    @Environment(\.presentationMode) var presentationMode
    @EnvironmentObject var store: SessionStore

    @State private var users: [ProfileLite] = []
    @State private var loading = true
    @State private var query = ""
    @State private var isGroupMode = false
    @State private var groupName = ""
    @State private var selectedUserIds = Set<String>()
    @State private var isBusy = false
    @State private var errorMessage: String?

    // Navigation state to newly created chat
    @State private var activeConversationId: String?
    @State private var activeConversationTitle: String = ""
    @State private var navigateToRoom = false

    var filteredUsers: [ProfileLite] {
        if query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return users
        }
        return users.filter { ($0.full_name ?? "").localizedCaseInsensitiveContains(query) }
    }

    var body: some View {
        VStack(spacing: 12) {
            // Mode selector (1-1 vs Nhóm)
            Picker("Chế độ", selection: $isGroupMode) {
                Text("1-1").tag(false)
                Text("Nhóm").tag(true)
            }
            .pickerStyle(.segmented)
            .padding(.horizontal)
            .onChange(of: isGroupMode) { _ in
                selectedUserIds.removeAll()
            }

            if isGroupMode {
                VStack(alignment: .leading, spacing: 4) {
                    TextField("Tên nhóm", text: $groupName)
                        .textFieldStyle(.roundedBorder)
                    Text("Đã chọn \(selectedUserIds.count) thành viên (tối thiểu 2)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding(.horizontal)
            }

            // Search bar
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.secondary)
                TextField("Tìm nhân viên…", text: $query)
                if !query.isEmpty {
                    Button(action: { query = "" }) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.secondary)
                    }
                }
            }
            .padding(8)
            .background(Color(.secondarySystemBackground))
            .cornerRadius(10)
            .padding(.horizontal)

            if let err = errorMessage {
                Text(err)
                    .font(.caption)
                    .foregroundColor(.red)
                    .padding(.horizontal)
            }

            // User list
            if loading {
                Spacer()
                ProgressView()
                Spacer()
            } else {
                List(filteredUsers) { u in
                    let isSelected = selectedUserIds.contains(u.id)
                    HStack {
                        // Avatar initial
                        ZStack {
                            Circle()
                                .fill(Color(red: 0.07, green: 0.45, blue: 0.20).opacity(0.15))
                                .frame(width: 40, height: 40)
                            Text(String((u.full_name ?? "?").prefix(1)).uppercased())
                                .font(.headline)
                                .foregroundColor(Color(red: 0.07, green: 0.45, blue: 0.20))
                        }

                        Text(u.full_name ?? "Nhân viên")
                            .font(.body)

                        Spacer()

                        if isGroupMode {
                            Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                                .foregroundColor(isSelected ? Color(red: 0.07, green: 0.45, blue: 0.20) : .secondary)
                                .font(.title3)
                        }
                    }
                    .contentShape(Rectangle())
                    .onTapGesture {
                        handleUserTap(u)
                    }
                }
                .listStyle(.plain)
            }

            // Hidden navigation link to newly created conversation
            NavigationLink(
                destination: ChatRoomScreen(
                    conversationId: activeConversationId ?? "",
                    title: activeConversationTitle
                ),
                isActive: $navigateToRoom
            ) {
                EmptyView()
            }
        }
        .navigationTitle(isGroupMode ? "Tạo nhóm chat" : "Cuộc trò chuyện mới")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            if isGroupMode {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: createGroup) {
                        if isBusy {
                            ProgressView()
                        } else {
                            Image(systemName: "checkmark")
                                .font(.body.weight(.bold))
                        }
                    }
                    .disabled(isBusy || selectedUserIds.count < 2 || groupName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
        .task {
            await fetchUsers()
        }
    }

    private func fetchUsers() async {
        let myId = store.session.userId
        do {
            let list = try await SupabaseApi.shared.getActiveUsers(excludeUserId: myId)
            await MainActor.run {
                self.users = list
                self.loading = false
            }
        } catch {
            await MainActor.run {
                self.errorMessage = error.localizedDescription
                self.loading = false
            }
        }
    }

    private func handleUserTap(_ user: ProfileLite) {
        guard !isBusy else { return }

        if isGroupMode {
            if selectedUserIds.contains(user.id) {
                selectedUserIds.remove(user.id)
            } else {
                selectedUserIds.insert(user.id)
            }
        } else {
            // 1-1 direct chat
            isBusy = true
            errorMessage = nil
            Task {
                do {
                    if let cid = try await SupabaseApi.shared.createDirect(otherUserId: user.id) {
                        await MainActor.run {
                            activeConversationId = cid
                            activeConversationTitle = user.full_name ?? "Chat"
                            isBusy = false
                            navigateToRoom = true
                        }
                    } else {
                        await MainActor.run {
                            errorMessage = "Không tạo được hội thoại"
                            isBusy = false
                        }
                    }
                } catch {
                    await MainActor.run {
                        errorMessage = error.localizedDescription
                        isBusy = false
                    }
                }
            }
        }
    }

    private func createGroup() {
        let name = groupName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard name.count > 0, selectedUserIds.count >= 2 else { return }

        isBusy = true
        errorMessage = nil
        Task {
            do {
                if let cid = try await SupabaseApi.shared.createGroup(name: name, members: Array(selectedUserIds)) {
                    await MainActor.run {
                        activeConversationId = cid
                        activeConversationTitle = name
                        isBusy = false
                        navigateToRoom = true
                    }
                } else {
                    await MainActor.run {
                        errorMessage = "Không tạo được nhóm"
                        isBusy = false
                    }
                }
            } catch {
                await MainActor.run {
                    errorMessage = error.localizedDescription
                    isBusy = false
                }
            }
        }
    }
}
