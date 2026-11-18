import SwiftUI

struct TaskDetailScreen: View {
    let taskId: String
    var onUpdated: (() -> Void)? = nil

    @EnvironmentObject var store: SessionStore
    @Environment(\.presentationMode) var presentationMode

    @State private var task: HrTask?
    @State private var assignees: [HrTaskAssignee] = []
    @State private var reports: [HrTaskReport] = []
    @State private var employees: [Employee] = []
    @State private var loading = true

    @State private var commentText = ""
    @State private var sendingComment = false
    @State private var updatingProgress = false

    @State private var showDeclineDialog = false
    @State private var declineReason = ""

    private var myUserId: String? { store.session.userId }
    private var myEmployeeId: String? { store.session.employeeId }
    private var myName: String { store.session.employeeName ?? "Nhân sự" }

    private var empMap: [String: Employee] {
        Dictionary(uniqueKeysWithValues: employees.map { ($0.id, $0) })
    }

    private var ownerAssignee: HrTaskAssignee? {
        assignees.first(where: { $0.role == "owner" })
    }

    private var ownerName: String {
        ownerAssignee?.employee_id.flatMap { empMap[$0]?.full_name }
            ?? task?.assigned_to.flatMap { empMap[$0]?.full_name }
            ?? "Chưa chỉ định"
    }

    private var collaboratorNames: [String] {
        assignees.filter { $0.role == "collaborator" }
            .compactMap { $0.employee_id.flatMap { eid in empMap[eid]?.full_name } }
    }

    private var isAssignedToMe: Bool {
        task?.assigned_to == myEmployeeId ||
        assignees.contains(where: { $0.employee_id == myEmployeeId || $0.user_id == myUserId })
    }

    private var isAwaiting: Bool {
        task?.status == "awaiting_acceptance" || task?.acceptance_status == "pending"
    }

    var body: some View {
        VStack(spacing: 0) {
            if loading && task == nil {
                Spacer()
                ProgressView("Đang tải chi tiết nhiệm vụ…")
                Spacer()
            } else if let t = task {
                ScrollViewReader { proxy in
                    ScrollView {
                        VStack(spacing: 14) {
                            // Card 1: Main Task Info
                            VStack(alignment: .leading, spacing: 12) {
                                // Priority & Status
                                HStack {
                                    priorityBadge(t.priority)
                                    Spacer()
                                    statusBadge(t.status)
                                }

                                Text(t.title)
                                    .font(.title3)
                                    .fontWeight(.bold)

                                if let proj = t.project_name, !proj.isEmpty {
                                    HStack(spacing: 4) {
                                        Image(systemName: "mappin.and.ellipse")
                                        Text(proj).fontWeight(.bold)
                                    }
                                    .font(.subheadline)
                                    .foregroundColor(Color(red: 0.07, green: 0.45, blue: 0.20))
                                }

                                Divider()

                                // Assignment details
                                VStack(alignment: .leading, spacing: 6) {
                                    HStack {
                                        Text("Phụ trách chính:").font(.caption).foregroundColor(.secondary)
                                        Spacer()
                                        Text(ownerName).font(.caption).fontWeight(.bold)
                                    }
                                    if !collaboratorNames.isEmpty {
                                        HStack {
                                            Text("Người phối hợp:").font(.caption).foregroundColor(.secondary)
                                            Spacer()
                                            Text(collaboratorNames.joined(separator: ", ")).font(.caption).fontWeight(.bold)
                                        }
                                    }
                                    if let due = t.due_date, !due.isEmpty {
                                        HStack {
                                            Text("Hạn hoàn thành:").font(.caption).foregroundColor(.secondary)
                                            Spacer()
                                            Text(due).font(.caption).fontWeight(.bold)
                                        }
                                    }
                                    if let created = t.created_date, !created.isEmpty {
                                        HStack {
                                            Text("Ngày giao việc:").font(.caption).foregroundColor(.secondary)
                                            Spacer()
                                            Text(created).font(.caption)
                                        }
                                    }
                                }

                                if let desc = t.description, !desc.isEmpty {
                                    Divider()
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text("Mô tả:").font(.caption).fontWeight(.bold).foregroundColor(.secondary)
                                        Text(desc).font(.body)
                                    }
                                }

                                if let notes = t.notes, !notes.isEmpty {
                                    Divider()
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text("Ghi chú:").font(.caption).fontWeight(.bold).foregroundColor(.secondary)
                                        Text(notes).font(.caption).foregroundColor(.secondary)
                                    }
                                }

                                // Acceptance actions if assigned to me and awaiting
                                if isAssignedToMe && isAwaiting {
                                    Divider()
                                    VStack(spacing: 8) {
                                        Text("Bạn được giao nhiệm vụ này. Vui lòng xác nhận tiếp nhận việc:")
                                            .font(.caption).foregroundColor(.secondary)
                                        HStack(spacing: 12) {
                                            Button(action: { showDeclineDialog = true }) {
                                                Text("Từ chối")
                                                    .font(.footnote).fontWeight(.bold)
                                                    .frame(maxWidth: .infinity)
                                                    .padding(.vertical, 8)
                                                    .foregroundColor(.red)
                                                    .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.red, lineWidth: 1))
                                            }

                                            Button(action: { respondAcceptance(accepted: true, note: nil) }) {
                                                Text("Tiếp nhận việc")
                                                    .font(.footnote).fontWeight(.bold)
                                                    .frame(maxWidth: .infinity)
                                                    .padding(.vertical, 8)
                                                    .background(Color(red: 0.07, green: 0.45, blue: 0.20))
                                                    .foregroundColor(.white)
                                                    .cornerRadius(8)
                                            }
                                        }
                                    }
                                    .padding(.top, 4)
                                } else if let accStatus = t.acceptance_status, !accStatus.isEmpty {
                                    Divider()
                                    HStack {
                                        Text("Trạng thái nhận việc:").font(.caption).foregroundColor(.secondary)
                                        Spacer()
                                        Text(accStatus == "accepted" ? "Đã tiếp nhận" : "Đã từ chối")
                                            .font(.caption).fontWeight(.bold)
                                            .foregroundColor(accStatus == "accepted" ? Color(red: 0.07, green: 0.55, blue: 0.20) : .red)
                                    }
                                    if let accNote = t.acceptance_note, !accNote.isEmpty {
                                        Text("Lý do: \(accNote)").font(.caption).italic().foregroundColor(.secondary)
                                    }
                                }
                            }
                            .padding(16)
                            .background(Color(.secondarySystemBackground))
                            .cornerRadius(14)

                            // Card 2: Progress Section
                            VStack(alignment: .leading, spacing: 12) {
                                HStack {
                                    Text("Tiến độ công việc").font(.headline)
                                    Spacer()
                                    Text("\(t.progress)%").font(.headline).fontWeight(.bold)
                                        .foregroundColor(Color(red: 0.07, green: 0.45, blue: 0.20))
                                }

                                // Quick progress preset buttons
                                HStack(spacing: 8) {
                                    ForEach([0, 25, 50, 75, 100], id: \.self) { p in
                                        Button(action: {
                                            updateProgress(p)
                                        }) {
                                            Text("\(p)%")
                                                .font(.caption).fontWeight(.bold)
                                                .frame(maxWidth: .infinity)
                                                .padding(.vertical, 6)
                                                .background(t.progress == p ? Color(red: 0.07, green: 0.45, blue: 0.20) : Color(.systemBackground))
                                                .foregroundColor(t.progress == p ? .white : .primary)
                                                .cornerRadius(8)
                                                .overlay(
                                                    RoundedRectangle(cornerRadius: 8)
                                                        .stroke(t.progress == p ? Color.clear : Color(.systemGray4), lineWidth: 1)
                                                )
                                        }
                                    }
                                }
                            }
                            .padding(16)
                            .background(Color(.secondarySystemBackground))
                            .cornerRadius(14)

                            // Card 3: Reports & Comments Feed
                            VStack(alignment: .leading, spacing: 12) {
                                Text("Báo cáo & Bình luận (\(reports.count))")
                                    .font(.headline)

                                if reports.isEmpty {
                                    Text("Chưa có bình luận hoặc báo cáo tiến độ nào.")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                        .padding(.vertical, 8)
                                } else {
                                    VStack(spacing: 10) {
                                        ForEach(reports) { rep in
                                            let isMe = rep.user_id == myUserId
                                            HStack(alignment: .top) {
                                                if isMe { Spacer() }
                                                VStack(alignment: isMe ? .trailing : .leading, spacing: 4) {
                                                    HStack(spacing: 6) {
                                                        Text(rep.reporter_name ?? "Nhân sự")
                                                            .font(.caption).fontWeight(.bold)
                                                        if let created = rep.created_at {
                                                            Text(formatIsoTime(created))
                                                                .font(.system(size: 10))
                                                                .foregroundColor(.secondary)
                                                        }
                                                    }
                                                    Text(rep.content)
                                                        .font(.subheadline)
                                                        .padding(10)
                                                        .background(isMe ? Color(red: 0.86, green: 0.95, blue: 0.88) : Color(.systemGray5))
                                                        .cornerRadius(12)
                                                }
                                                if !isMe { Spacer() }
                                            }
                                        }
                                    }
                                }
                            }
                            .padding(16)
                            .background(Color(.secondarySystemBackground))
                            .cornerRadius(14)
                            .id("commentsBottom")
                        }
                        .padding(14)
                    }
                }

                // Bottom comment input bar
                HStack(spacing: 8) {
                    TextField("Viết bình luận / báo cáo tiến độ…", text: $commentText)
                        .padding(10)
                        .background(Color(.systemGray6))
                        .cornerRadius(20)

                    Button(action: sendComment) {
                        if sendingComment {
                            ProgressView().tint(.white)
                                .frame(width: 36, height: 36)
                                .background(Color(red: 0.07, green: 0.45, blue: 0.20))
                                .clipShape(Circle())
                        } else {
                            Image(systemName: "paperplane.fill")
                                .foregroundColor(.white)
                                .frame(width: 36, height: 36)
                                .background(commentText.trimmingCharacters(in: .whitespaces).isEmpty ? Color.gray : Color(red: 0.07, green: 0.45, blue: 0.20))
                                .clipShape(Circle())
                        }
                    }
                    .disabled(commentText.trimmingCharacters(in: .whitespaces).isEmpty || sendingComment)
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .background(Color(.systemBackground))
                .shadow(color: Color.black.opacity(0.05), radius: 3, x: 0, y: -2)
            } else {
                Spacer()
                Text("Không tìm thấy nhiệm vụ").foregroundColor(.secondary)
                Spacer()
            }
        }
        .navigationTitle("Chi tiết nhiệm vụ")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button(action: { reload() }) {
                    Image(systemName: "arrow.clockwise")
                }
            }
        }
        .sheet(isPresented: $showDeclineDialog) {
            NavigationView {
                Form {
                    Section(header: Text("Lý do từ chối")) {
                        TextEditor(text: $declineReason)
                            .frame(minHeight: 100)
                    }
                    Section {
                        Button("Xác nhận từ chối", role: .destructive) {
                            respondAcceptance(accepted: false, note: declineReason.trimmingCharacters(in: .whitespaces))
                            showDeclineDialog = false
                        }
                    }
                }
                .navigationTitle("Từ chối nhiệm vụ")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .navigationBarLeading) {
                        Button("Đóng") { showDeclineDialog = false }
                    }
                }
            }
        }
        .task {
            reload()
        }
    }

    private func reload() {
        loading = true
        Task {
            do {
                let allTasks = try await SupabaseApi.shared.getTasks()
                let curTask = allTasks.first(where: { $0.id == taskId })
                let curAssignees = try await SupabaseApi.shared.getAssignees(taskIds: [taskId])
                let curReports = try await SupabaseApi.shared.getReports(taskId: taskId)
                let empList = try await SupabaseApi.shared.getActiveEmployees()

                await MainActor.run {
                    self.task = curTask
                    self.assignees = curAssignees
                    self.reports = curReports
                    self.employees = empList
                    self.loading = false
                }
            } catch {
                await MainActor.run { self.loading = false }
            }
        }
    }

    private func updateProgress(_ newProgress: Int) {
        guard !updatingProgress else { return }
        updatingProgress = true
        Task {
            _ = try? await SupabaseApi.shared.updateTaskProgress(taskId: taskId, progress: newProgress)
            await MainActor.run {
                self.task?.progress = newProgress
                if newProgress >= 100 { self.task?.status = "completed" }
                self.updatingProgress = false
            }
            onUpdated?()
        }
    }

    private func respondAcceptance(accepted: Bool, note: String?) {
        Task {
            _ = try? await SupabaseApi.shared.respondAcceptance(
                taskId: taskId,
                employeeId: myEmployeeId,
                accepted: accepted,
                note: note
            )
            reload()
            onUpdated?()
        }
    }

    private func sendComment() {
        let content = commentText.trimmingCharacters(in: .whitespaces)
        guard !content.isEmpty, let uid = myUserId else { return }
        sendingComment = true
        Task {
            let ok = (try? await SupabaseApi.shared.addReport(taskId: taskId, userId: uid, reporterName: myName, content: content)) ?? false
            if ok {
                let newReports = (try? await SupabaseApi.shared.getReports(taskId: taskId)) ?? []
                await MainActor.run {
                    self.commentText = ""
                    self.reports = newReports
                    self.sendingComment = false
                }
            } else {
                await MainActor.run { self.sendingComment = false }
            }
        }
    }

    private func formatIsoTime(_ iso: String) -> String {
        let isoFormatter = ISO8601DateFormatter()
        isoFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        var date = isoFormatter.date(from: iso)
        if date == nil {
            isoFormatter.formatOptions = [.withInternetDateTime]
            date = isoFormatter.date(from: iso)
        }
        guard let d = date else { return iso }
        let outFmt = DateFormatter()
        outFmt.locale = Locale(identifier: "vi_VN")
        outFmt.dateFormat = "HH:mm dd/MM"
        return outFmt.string(from: d)
    }

    private func priorityBadge(_ priority: String) -> some View {
        let info: (String, Color, Color)
        switch priority {
        case "urgent": info = ("Khẩn cấp", .red, Color(red: 1.0, green: 0.9, blue: 0.9))
        case "high": info = ("Cao", .orange, Color(red: 1.0, green: 0.93, blue: 0.85))
        case "low": info = ("Thấp", .gray, Color(.systemGray5))
        default: info = ("Trung bình", Color(red: 0.15, green: 0.55, blue: 0.25), Color(red: 0.88, green: 0.95, blue: 0.88))
        }
        return Text(info.0)
            .font(.caption2).fontWeight(.bold)
            .padding(.horizontal, 8).padding(.vertical, 3)
            .background(info.2).foregroundColor(info.1)
            .cornerRadius(6)
    }

    private func statusBadge(_ status: String) -> some View {
        let info: (String, Color, Color)
        switch status {
        case "completed": info = ("Hoàn thành", Color(red: 0.07, green: 0.55, blue: 0.20), Color(red: 0.88, green: 0.96, blue: 0.88))
        case "in_progress": info = ("Đang thực hiện", Color(red: 0.1, green: 0.45, blue: 0.85), Color(red: 0.9, green: 0.94, blue: 1.0))
        case "awaiting_acceptance": info = ("Chờ nhận việc", Color(red: 0.9, green: 0.45, blue: 0.0), Color(red: 1.0, green: 0.93, blue: 0.85))
        case "declined": info = ("Đã từ chối", .red, Color(red: 1.0, green: 0.9, blue: 0.9))
        default: info = ("Chờ xử lý", Color(red: 0.9, green: 0.45, blue: 0.0), Color(red: 1.0, green: 0.93, blue: 0.85))
        }
        return Text(info.0)
            .font(.caption2).fontWeight(.bold)
            .padding(.horizontal, 8).padding(.vertical, 3)
            .background(info.2).foregroundColor(info.1)
            .cornerRadius(6)
    }
}
