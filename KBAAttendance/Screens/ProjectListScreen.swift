import SwiftUI

struct ProjectListScreen: View {
    @EnvironmentObject var store: SessionStore

    @State private var projects: [Project] = []
    @State private var memberProjectIds = Set<String>()
    @State private var loading = true
    @State private var searchQuery = ""
    @State private var selectedTab = 0 // 0: Tất cả, 1: Dự án của tôi
    @State private var selectedStatusFilter = "all" // all, in_progress, completed, planning

    @State private var alertMessage: String?
    @State private var showAlert = false

    private var myUserId: String? { store.session.userId }

    private var hasFullProjectPermission: Bool {
        store.session.canEditModules.contains("projects")
    }

    private var hasViewProjectPermission: Bool {
        store.session.allowedModules.contains("projects") || hasFullProjectPermission
    }

    private var filteredProjects: [Project] {
        projects.filter { proj in
            let isMyInvolved = proj.created_by == myUserId || memberProjectIds.contains(proj.id)

            let matchesTab = (selectedTab == 1) ? isMyInvolved : true
            if !matchesTab { return false }

            let status = (proj.status ?? "").lowercased()
            let matchesStatus: Bool
            switch selectedStatusFilter {
            case "in_progress":
                matchesStatus = status == "in_progress" || status == "active"
            case "completed":
                matchesStatus = status == "completed"
            case "planning":
                matchesStatus = status == "planning" || status == "pending"
            default:
                matchesStatus = true
            }
            if !matchesStatus { return false }

            let q = searchQuery.trimmingCharacters(in: .whitespaces).lowercased()
            if q.isEmpty { return true }
            let nameMatch = proj.name.lowercased().contains(q)
            let locMatch = (proj.location ?? "").lowercased().contains(q)
            let descMatch = (proj.description ?? "").lowercased().contains(q)
            return nameMatch || locMatch || descMatch
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            if !loading && !hasViewProjectPermission && !store.session.allowedModules.isEmpty {
                Spacer()
                VStack(spacing: 12) {
                    Image(systemName: "lock.circle.fill")
                        .font(.system(size: 60))
                        .foregroundColor(.red)
                    Text("Không có quyền truy cập").font(.headline).fontWeight(.bold)
                    Text("Bạn chưa được cấp quyền xem Quản lý dự án. Vui lòng liên hệ quản trị viên.")
                        .font(.footnote)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 32)
                }
                Spacer()
            } else {
                // Tabs: Tất cả dự án | Dự án của tôi
                HStack(spacing: 0) {
                    ProjectTabButton(title: "Tất cả (\(projects.count))", isSelected: selectedTab == 0) {
                        selectedTab = 0
                    }
                    let myCount = projects.filter { $0.created_by == myUserId || memberProjectIds.contains($0.id) }.count
                    ProjectTabButton(title: "Dự án của tôi (\(myCount))", isSelected: selectedTab == 1) {
                        selectedTab = 1
                    }
                }
                .padding(.top, 4)
                .background(Color(.secondarySystemBackground))

                // Search & Filter chips
                VStack(spacing: 8) {
                    HStack {
                        Image(systemName: "magnifyingglass").foregroundColor(.secondary)
                        TextField("Tìm kiếm tên dự án, địa điểm…", text: $searchQuery)
                        if !searchQuery.isEmpty {
                            Button(action: { searchQuery = "" }) {
                                Image(systemName: "xmark.circle.fill").foregroundColor(.secondary)
                            }
                        }
                    }
                    .padding(10)
                    .background(Color(.systemGray6))
                    .cornerRadius(10)

                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ProjectChipButton(title: "Tất cả", isSelected: selectedStatusFilter == "all") { selectedStatusFilter = "all" }
                            ProjectChipButton(title: "Đang làm", isSelected: selectedStatusFilter == "in_progress") { selectedStatusFilter = "in_progress" }
                            ProjectChipButton(title: "Hoàn thành", isSelected: selectedStatusFilter == "completed") { selectedStatusFilter = "completed" }
                            ProjectChipButton(title: "Kế hoạch", isSelected: selectedStatusFilter == "planning") { selectedStatusFilter = "planning" }
                        }
                    }
                }
                .padding(.horizontal)
                .padding(.vertical, 8)
                .background(Color(.secondarySystemBackground))

                // Projects List
                if loading && projects.isEmpty {
                    Spacer()
                    ProgressView("Đang tải danh sách dự án…")
                    Spacer()
                } else if filteredProjects.isEmpty {
                    Spacer()
                    VStack(spacing: 12) {
                        Image(systemName: "folder.badge.questionmark").font(.system(size: 50)).foregroundColor(.secondary)
                        Text("Không có dự án nào phù hợp").foregroundColor(.secondary)
                    }
                    Spacer()
                } else {
                    List(filteredProjects) { proj in
                        let isCreator = proj.created_by == myUserId
                        let isMember = memberProjectIds.contains(proj.id)
                        let canViewDetail = hasFullProjectPermission || isCreator || isMember

                        ZStack {
                            if canViewDetail {
                                NavigationLink(destination: ProjectDetailScreen(projectId: proj.id, onUpdated: { reload() })) {
                                    EmptyView()
                                }
                                .opacity(0)
                            }

                            Button(action: {
                                if !canViewDetail {
                                    alertMessage = "Bạn chỉ có quyền xem danh sách tổng quan, không có quyền xem chi tiết do không thuộc đội ngũ dự án này."
                                    showAlert = true
                                }
                            }) {
                                ProjectCardView(
                                    project: proj,
                                    isMember: isMember || isCreator,
                                    canViewDetail: canViewDetail
                                )
                            }
                            .buttonStyle(.plain)
                        }
                        .listRowInsets(EdgeInsets(top: 6, leading: 14, bottom: 6, trailing: 14))
                        .listRowSeparator(.hidden)
                    }
                    .listStyle(.plain)
                    .refreshable {
                        await reloadAsync()
                    }
                }
            }
        }
        .navigationTitle("Quản lý dự án")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button(action: { reload() }) {
                    Image(systemName: "arrow.clockwise")
                }
            }
        }
        .alert(isPresented: $showAlert) {
            Alert(
                title: Text("Thông báo quyền"),
                message: Text(alertMessage ?? ""),
                dismissButton: .default(Text("Đã hiểu"))
            )
        }
        .task {
            reload()
        }
    }

    private func reload() {
        loading = true
        Task {
            await reloadAsync()
        }
    }

    private func reloadAsync() async {
        do {
            let pList = try await SupabaseApi.shared.getAllProjects()
            var mIds = Set<String>()
            if let uid = myUserId {
                let mList = try await SupabaseApi.shared.getMemberProjectIds(userId: uid)
                mIds = Set(mList)
            }
            await MainActor.run {
                self.projects = pList
                self.memberProjectIds = mIds
                self.loading = false
            }
        } catch {
            await MainActor.run { self.loading = false }
        }
    }
}

private struct ProjectTabButton: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 6) {
                Text(title)
                    .font(.subheadline).fontWeight(.bold)
                    .foregroundColor(isSelected ? Color(red: 0.07, green: 0.45, blue: 0.20) : .secondary)
                Rectangle()
                    .fill(isSelected ? Color(red: 0.07, green: 0.45, blue: 0.20) : Color.clear)
                    .frame(height: 3)
            }
            .frame(maxWidth: .infinity)
        }
    }
}

private struct ProjectChipButton: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.footnote).fontWeight(.bold)
                .padding(.horizontal, 12).padding(.vertical, 6)
                .background(isSelected ? Color(red: 0.07, green: 0.45, blue: 0.20) : Color(.systemBackground))
                .foregroundColor(isSelected ? .white : .primary)
                .cornerRadius(16)
                .overlay(RoundedRectangle(cornerRadius: 16).stroke(isSelected ? Color.clear : Color(.systemGray4), lineWidth: 1))
        }
    }
}

private struct ProjectCardView: View {
    let project: Project
    let isMember: Bool
    let canViewDetail: Bool

    private var statusInfo: (String, Color, Color) {
        let s = (project.status ?? "").lowercased()
        switch s {
        case "completed":
            return ("Hoàn thành", Color(red: 0.07, green: 0.55, blue: 0.20), Color(red: 0.88, green: 0.96, blue: 0.88))
        case "in_progress", "active":
            return ("Đang thực hiện", Color(red: 0.1, green: 0.45, blue: 0.85), Color(red: 0.9, green: 0.94, blue: 1.0))
        case "planning", "pending":
            return ("Kế hoạch", Color(red: 0.9, green: 0.45, blue: 0.0), Color(red: 1.0, green: 0.93, blue: 0.85))
        default:
            return ("Đang chạy", Color(red: 0.1, green: 0.45, blue: 0.85), Color(red: 0.9, green: 0.94, blue: 1.0))
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            // Header status and member tag
            HStack {
                let st = statusInfo
                Text(st.0)
                    .font(.caption2).fontWeight(.bold)
                    .padding(.horizontal, 8).padding(.vertical, 3)
                    .background(st.2).foregroundColor(st.1)
                    .cornerRadius(6)

                Spacer()

                if isMember {
                    Text("Tham gia")
                        .font(.caption2).fontWeight(.bold)
                        .padding(.horizontal, 8).padding(.vertical, 3)
                        .background(Color(red: 0.86, green: 0.95, blue: 0.88))
                        .foregroundColor(Color(red: 0.07, green: 0.45, blue: 0.20))
                        .cornerRadius(6)
                }
            }

            // Project name
            Text(project.name)
                .font(.headline)
                .foregroundColor(.primary)

            if let loc = project.location, !loc.isEmpty {
                HStack(spacing: 4) {
                    Image(systemName: "mappin.and.ellipse").font(.caption).foregroundColor(.secondary)
                    Text(loc).font(.caption).foregroundColor(.secondary)
                }
            }

            // Date & Budget row
            HStack(spacing: 12) {
                if let start = project.start_date, !start.isEmpty {
                    let endStr = project.end_date ?? "…"
                    HStack(spacing: 4) {
                        Image(systemName: "calendar").font(.caption).foregroundColor(.secondary)
                        Text("\(start) - \(endStr)").font(.caption).foregroundColor(.secondary)
                    }
                }
                if let bud = project.budget, !bud.isEmpty {
                    Spacer()
                    Text("NS: \(bud)").font(.caption).fontWeight(.bold).foregroundColor(Color(red: 0.07, green: 0.45, blue: 0.20))
                }
            }

            if !canViewDetail {
                Divider()
                HStack(spacing: 4) {
                    Image(systemName: "lock.fill").font(.caption2)
                    Text("Chỉ xem tổng quan").font(.caption2)
                }
                .foregroundColor(.secondary)
            }
        }
        .padding(14)
        .background(Color(.secondarySystemBackground))
        .cornerRadius(14)
    }
}
