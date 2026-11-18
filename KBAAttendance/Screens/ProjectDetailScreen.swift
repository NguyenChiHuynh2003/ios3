import SwiftUI

struct ProjectDetailScreen: View {
    let projectId: String
    var onUpdated: (() -> Void)? = nil

    @EnvironmentObject var store: SessionStore
    @Environment(\.presentationMode) var presentationMode

    @State private var project: Project?
    @State private var subProjects: [Project] = []
    @State private var members: [ProjectTeamMember] = []
    @State private var memberNames: [String: String] = [:]
    @State private var tasks: [HrTask] = []
    @State private var loading = true

    // Add sub-project dialog
    @State private var showAddSubDialog = false
    @State private var newSubName = ""
    @State private var newSubDesc = ""
    @State private var isSubmittingSub = false

    // Delete sub-project dialog
    @State private var subProjectToDelete: Project?
    @State private var showDeleteSubAlert = false

    private var myUserId: String? { store.session.userId }
    private var hasFullProjectPermission: Bool { store.session.canEditModules.contains("projects") }
    private var isCreator: Bool { project?.created_by == myUserId }
    private var canManageSubProjects: Bool { hasFullProjectPermission || isCreator }

    var body: some View {
        ScrollView {
            VStack(spacing: 14) {
                if loading && project == nil {
                    ProgressView("Đang tải dữ liệu dự án…")
                        .padding(.top, 40)
                } else if let p = project {
                    // Card 1: Overview
                    VStack(alignment: .leading, spacing: 10) {
                        HStack {
                            statusBadge(p.status)
                            Spacer()
                            if let bud = p.budget, !bud.isEmpty {
                                Text("NS: \(bud)")
                                    .bold()
                                    .font(.caption)
                                    .foregroundColor(Color(red: 0.07, green: 0.45, blue: 0.20))
                            }
                        }

                        Text(p.name).bold().font(.title3)

                        if let loc = p.location, !loc.isEmpty {
                            HStack(spacing: 6) {
                                Image(systemName: "mappin.and.ellipse")
                                Text(loc)
                            }
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        }

                        if let start = p.start_date, !start.isEmpty {
                            HStack(spacing: 6) {
                                Image(systemName: "calendar")
                                Text("\(start)  đến  \(p.end_date ?? "…")")
                            }
                            .font(.caption)
                            .foregroundColor(.secondary)
                        }

                        if let desc = p.description, !desc.isEmpty {
                            Divider()
                            Text(desc).font(.body)
                        }
                    }
                    .padding(16)
                    .background(Color(.secondarySystemBackground))
                    .cornerRadius(14)

                    // Card 2: Sub-projects (Dự án con)
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Text("Dự án con / Hạng mục (\(subProjects.count))")
                                .font(.headline)
                            Spacer()
                            if canManageSubProjects {
                                Button(action: { showAddSubDialog = true }) {
                                    HStack(spacing: 4) {
                                        Image(systemName: "plus.circle.fill")
                                        Text("Thêm").bold()
                                    }
                                    .font(.caption)
                                    .foregroundColor(Color(red: 0.07, green: 0.45, blue: 0.20))
                                }
                            }
                        }

                        if subProjects.isEmpty {
                            Text("Chưa có dự án con nào.")
                                .font(.caption).foregroundColor(.secondary)
                                .padding(.vertical, 4)
                        } else {
                            VStack(spacing: 8) {
                                ForEach(subProjects) { sub in
                                    HStack(alignment: .top) {
                                        VStack(alignment: .leading, spacing: 2) {
                                            Text(sub.name).bold().font(.subheadline)
                                            if let d = sub.description, !d.isEmpty {
                                                Text(d).font(.caption).foregroundColor(.secondary)
                                            }
                                        }
                                        Spacer()
                                        if canManageSubProjects {
                                            Button(action: {
                                                subProjectToDelete = sub
                                                showDeleteSubAlert = true
                                            }) {
                                                Image(systemName: "trash")
                                                    .font(.caption)
                                                    .foregroundColor(.red)
                                                    .padding(6)
                                            }
                                        }
                                    }
                                    .padding(10)
                                    .background(Color(.systemBackground))
                                    .cornerRadius(8)
                                }
                            }
                        }
                    }
                    .padding(16)
                    .background(Color(.secondarySystemBackground))
                    .cornerRadius(14)

                    // Card 3: Team Members
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Thành viên đội ngũ (\(members.count))")
                            .font(.headline)

                        if members.isEmpty {
                            Text("Chưa có danh sách thành viên cụ thể.")
                                .font(.caption).foregroundColor(.secondary)
                                .padding(.vertical, 4)
                        } else {
                            VStack(spacing: 8) {
                                ForEach(members) { m in
                                    HStack(spacing: 10) {
                                        Image(systemName: "person.circle.fill")
                                            .font(.title2)
                                            .foregroundColor(Color(red: 0.07, green: 0.45, blue: 0.20))
                                        VStack(alignment: .leading, spacing: 2) {
                                            let name = m.manual_name ?? (m.user_id.flatMap { memberNames[$0] }) ?? "Thành viên"
                                            Text(name).bold().font(.subheadline)
                                            let roleStr = [m.role, m.position, m.department].compactMap { $0 }.filter { !$0.isEmpty }.joined(separator: " • ")
                                            if !roleStr.isEmpty {
                                                Text(roleStr).font(.caption).foregroundColor(.secondary)
                                            }
                                        }
                                        Spacer()
                                    }
                                    .padding(8)
                                    .background(Color(.systemBackground))
                                    .cornerRadius(8)
                                }
                            }
                        }
                    }
                    .padding(16)
                    .background(Color(.secondarySystemBackground))
                    .cornerRadius(14)

                    // Card 4: Project Tasks
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Nhiệm vụ thuộc dự án (\(tasks.count))")
                            .font(.headline)

                        if tasks.isEmpty {
                            Text("Chưa có nhiệm vụ nào được gắn với dự án này.")
                                .font(.caption).foregroundColor(.secondary)
                                .padding(.vertical, 4)
                        } else {
                            VStack(spacing: 8) {
                                ForEach(tasks) { task in
                                    NavigationLink(destination: TaskDetailScreen(taskId: task.id)) {
                                        HStack {
                                            VStack(alignment: .leading, spacing: 4) {
                                                Text(task.title).bold().font(.subheadline).foregroundColor(.primary)
                                                if let due = task.due_date, !due.isEmpty {
                                                    Text("Hạn: \(due)").font(.caption).foregroundColor(.secondary)
                                                }
                                            }
                                            Spacer()
                                            Text("\(task.progress)%")
                                                .bold()
                                                .font(.caption)
                                                .foregroundColor(Color(red: 0.07, green: 0.45, blue: 0.20))
                                        }
                                        .padding(10)
                                        .background(Color(.systemBackground))
                                        .cornerRadius(8)
                                    }
                                }
                            }
                        }
                    }
                    .padding(16)
                    .background(Color(.secondarySystemBackground))
                    .cornerRadius(14)
                }
            }
            .padding(14)
        }
        .navigationTitle("Chi tiết dự án")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button(action: { reload() }) {
                    Image(systemName: "arrow.clockwise")
                }
            }
        }
        .sheet(isPresented: $showAddSubDialog) {
            NavigationView {
                Form {
                    Section(header: Text("Thông tin dự án con")) {
                        TextField("Tên dự án con / Hạng mục *", text: $newSubName)
                        TextField("Mô tả chi tiết (tuỳ chọn)", text: $newSubDesc)
                    }
                    Section {
                        Button("Tạo dự án con") {
                            createSubProject()
                        }
                        .disabled(newSubName.trimmingCharacters(in: .whitespaces).isEmpty || isSubmittingSub)
                    }
                }
                .navigationTitle("Thêm dự án con")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .navigationBarLeading) {
                        Button("Đóng") { showAddSubDialog = false }
                    }
                }
            }
        }
        .alert(isPresented: $showDeleteSubAlert) {
            Alert(
                title: Text("Xác nhận xoá"),
                message: Text("Bạn có chắc chắn muốn xoá dự án con \"\(subProjectToDelete?.name ?? "")\"?"),
                primaryButton: .destructive(Text("Xoá")) {
                    if let sub = subProjectToDelete {
                        deleteSubProject(sub.id)
                    }
                },
                secondaryButton: .cancel(Text("Huỷ"))
            )
        }
        .task {
            reload()
        }
    }

    private func reload() {
        loading = true
        Task {
            do {
                let allP = try await SupabaseApi.shared.getAllProjects()
                let curP = allP.first(where: { $0.id == projectId })
                var subs: [Project] = []
                var mList: [ProjectTeamMember] = []
                var tList: [HrTask] = []

                if let p = curP {
                    subs = try await SupabaseApi.shared.getSubProjects(parentProjectId: projectId)
                    mList = try await SupabaseApi.shared.getProjectMembers(projectId: projectId)
                    tList = try await SupabaseApi.shared.getProjectTasks(projectId: projectId, projectName: p.name)
                }

                await MainActor.run {
                    self.project = curP
                    self.subProjects = subs
                    self.members = mList
                    self.tasks = tList
                    self.loading = false
                }
            } catch {
                await MainActor.run { self.loading = false }
            }
        }
    }

    private func createSubProject() {
        let name = newSubName.trimmingCharacters(in: .whitespaces)
        guard !name.isEmpty else { return }
        isSubmittingSub = true
        Task {
            let ok = (try? await SupabaseApi.shared.createSubProject(
                parentProjectId: projectId,
                name: name,
                description: newSubDesc.isEmpty ? nil : newSubDesc,
                userId: myUserId
            )) ?? false

            await MainActor.run {
                self.isSubmittingSub = false
                self.showAddSubDialog = false
                if ok {
                    self.newSubName = ""
                    self.newSubDesc = ""
                    self.reload()
                }
            }
        }
    }

    private func deleteSubProject(_ subId: String) {
        Task {
            _ = try? await SupabaseApi.shared.deleteProject(projectId: subId)
            await MainActor.run {
                self.subProjects.removeAll(where: { $0.id == subId })
            }
        }
    }

    private func statusBadge(_ status: String?) -> some View {
        let s = (status ?? "").lowercased()
        let info: (String, Color, Color)
        switch s {
        case "completed":
            info = ("Hoàn thành", Color(red: 0.07, green: 0.55, blue: 0.20), Color(red: 0.88, green: 0.96, blue: 0.88))
        case "in_progress", "active":
            info = ("Đang thực hiện", Color(red: 0.1, green: 0.45, blue: 0.85), Color(red: 0.9, green: 0.94, blue: 1.0))
        case "planning", "pending":
            info = ("Kế hoạch", Color(red: 0.9, green: 0.45, blue: 0.0), Color(red: 1.0, green: 0.93, blue: 0.85))
        default:
            info = ("Đang chạy", Color(red: 0.1, green: 0.45, blue: 0.85), Color(red: 0.9, green: 0.94, blue: 1.0))
        }
        return Text(info.0)
            .bold()
            .font(.caption2)
            .padding(.horizontal, 8).padding(.vertical, 3)
            .background(info.2).foregroundColor(info.1)
            .cornerRadius(6)
    }
}
