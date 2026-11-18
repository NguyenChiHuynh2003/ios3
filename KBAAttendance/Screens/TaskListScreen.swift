import SwiftUI

struct TaskListScreen: View {
    @EnvironmentObject var store: SessionStore

    @State private var tasks: [HrTask] = []
    @State private var assignees: [HrTaskAssignee] = []
    @State private var employees: [Employee] = []
    @State private var loading = true
    @State private var searchQuery = ""
    @State private var selectedTab = 0 // 0: Tất cả / Của tôi, 1: Được giao, 2: Tôi giao
    @State private var selectedStatusFilter = "all" // all, awaiting, in_progress, completed
    @State private var showCreateTask = false

    private var myUserId: String? {
        store.session.userId
    }

    private var myEmployeeId: String? {
        store.session.employeeId
    }

    private var hasFullTaskPermission: Bool {
        store.session.canEditModules.contains("hr-tasks")
    }

    private var empMap: [String: Employee] {
        Dictionary(uniqueKeysWithValues: employees.map { ($0.id, $0) })
    }

    private var assigneesByTask: [String: [HrTaskAssignee]] {
        Dictionary(grouping: assignees, by: { $0.task_id })
    }

    private var visibleTasks: [HrTask] {
        if hasFullTaskPermission {
            return tasks
        } else {
            return tasks.filter { task in
                task.created_by == myUserId ||
                task.assigned_to == myEmployeeId ||
                assigneesByTask[task.id]?.contains(where: { $0.employee_id == myEmployeeId || $0.user_id == myUserId }) == true
            }
        }
    }

    private var filteredTasks: [HrTask] {
        visibleTasks.filter { task in
            // Tab filter
            let matchesTab: Bool
            switch selectedTab {
            case 1: // Được giao
                matchesTab = task.assigned_to == myEmployeeId ||
                    assigneesByTask[task.id]?.contains(where: { $0.employee_id == myEmployeeId || $0.user_id == myUserId }) == true
            case 2: // Tôi giao
                matchesTab = task.created_by == myUserId
            default:
                matchesTab = true
            }
            if !matchesTab { return false }

            // Status filter
            let matchesStatus: Bool
            switch selectedStatusFilter {
            case "awaiting":
                matchesStatus = task.status == "awaiting_acceptance" || task.status == "pending"
            case "in_progress":
                matchesStatus = task.status == "in_progress"
            case "completed":
                matchesStatus = task.status == "completed"
            default:
                matchesStatus = true
            }
            if !matchesStatus { return false }

            // Search filter
            let q = searchQuery.trimmingCharacters(in: .whitespaces).lowercased()
            if q.isEmpty { return true }
            let titleMatch = task.title.lowercased().contains(q)
            let projMatch = (task.project_name ?? "").lowercased().contains(q)
            let descMatch = (task.description ?? "").lowercased().contains(q)
            return titleMatch || projMatch || descMatch
        }
    }

    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            VStack(spacing: 0) {
                // Primary Tabs: Tất cả | Được giao | Tôi giao
                HStack(spacing: 0) {
                    TabItemButton(
                        title: hasFullTaskPermission ? "Tất cả (\(visibleTasks.count))" : "Của tôi (\(visibleTasks.count))",
                        isSelected: selectedTab == 0
                    ) { selectedTab = 0 }

                    let assignedCount = visibleTasks.filter {
                        $0.assigned_to == myEmployeeId ||
                        assigneesByTask[$0.id]?.contains(where: { a in a.employee_id == myEmployeeId || a.user_id == myUserId }) == true
                    }.count
                    TabItemButton(title: "Được giao (\(assignedCount))", isSelected: selectedTab == 1) { selectedTab = 1 }

                    let createdCount = visibleTasks.filter { $0.created_by == myUserId }.count
                    TabItemButton(title: "Tôi giao (\(createdCount))", isSelected: selectedTab == 2) { selectedTab = 2 }
                }
                .padding(.top, 4)
                .background(Color(.secondarySystemBackground))

                // Search & Filter chips
                VStack(spacing: 8) {
                    HStack {
                        Image(systemName: "magnifyingglass").foregroundColor(.secondary)
                        TextField("Tìm kiếm nhiệm vụ, dự án…", text: $searchQuery)
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
                            FilterChipButton(title: "Tất cả", isSelected: selectedStatusFilter == "all") { selectedStatusFilter = "all" }
                            FilterChipButton(title: "Chờ nhận", isSelected: selectedStatusFilter == "awaiting") { selectedStatusFilter = "awaiting" }
                            FilterChipButton(title: "Đang làm", isSelected: selectedStatusFilter == "in_progress") { selectedStatusFilter = "in_progress" }
                            FilterChipButton(title: "Hoàn thành", isSelected: selectedStatusFilter == "completed") { selectedStatusFilter = "completed" }
                        }
                    }
                }
                .padding(.horizontal)
                .padding(.vertical, 8)
                .background(Color(.secondarySystemBackground))

                // Tasks List
                if loading && tasks.isEmpty {
                    Spacer()
                    ProgressView("Đang tải danh sách nhiệm vụ…")
                    Spacer()
                } else if filteredTasks.isEmpty {
                    Spacer()
                    VStack(spacing: 12) {
                        Image(systemName: "doc.text.magnifyingglass").font(.system(size: 50)).foregroundColor(.secondary)
                        Text("Không có nhiệm vụ nào").foregroundColor(.secondary)
                    }
                    Spacer()
                } else {
                    List(filteredTasks) { task in
                        let taskAssignees = assigneesByTask[task.id] ?? []
                        let ownerAssignee = taskAssignees.first(where: { $0.role == "owner" })
                        let ownerName = ownerAssignee?.employee_id.flatMap { empMap[$0]?.full_name }
                            ?? task.assigned_to.flatMap { empMap[$0]?.full_name }
                            ?? "Chưa chỉ định"

                        let collaboratorNames = taskAssignees
                            .filter { $0.role == "collaborator" }
                            .compactMap { $0.employee_id.flatMap { eid in empMap[eid]?.full_name } }

                        let isMyTask = task.assigned_to == myEmployeeId ||
                            taskAssignees.contains(where: { $0.employee_id == myEmployeeId || $0.user_id == myUserId })
                        let isAwaiting = task.status == "awaiting_acceptance" || task.acceptance_status == "pending"

                        ZStack {
                            NavigationLink(destination: TaskDetailScreen(taskId: task.id, onUpdated: { reloadData() })) {
                                EmptyView()
                            }
                            .opacity(0)

                            TaskCardView(
                                task: task,
                                ownerName: ownerName,
                                collaboratorNames: collaboratorNames,
                                canAccept: isMyTask && isAwaiting,
                                onAccept: {
                                    respondAcceptance(task: task, accepted: true)
                                },
                                onDecline: {
                                    respondAcceptance(task: task, accepted: false)
                                }
                            )
                        }
                        .listRowInsets(EdgeInsets(top: 6, leading: 14, bottom: 6, trailing: 14))
                        .listRowSeparator(.hidden)
                    }
                    .listStyle(.plain)
                    .refreshable {
                        await reloadDataAsync()
                    }
                }
            }

            // Floating Action Button "Giao việc"
            Button(action: { showCreateTask = true }) {
                HStack(spacing: 6) {
                    Image(systemName: "plus")
                    Text("Giao việc").bold()
                }
                .font(.headline)
                .padding(.horizontal, 20)
                .padding(.vertical, 14)
                .background(Color(red: 0.07, green: 0.45, blue: 0.20))
                .foregroundColor(.white)
                .cornerRadius(28)
                .shadow(color: Color.black.opacity(0.25), radius: 5, x: 0, y: 3)
            }
            .padding(.trailing, 20)
            .padding(.bottom, 20)
        }
        .navigationTitle("Quản lý nhiệm vụ")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button(action: { reloadData() }) {
                    Image(systemName: "arrow.clockwise")
                }
            }
        }
        .sheet(isPresented: $showCreateTask) {
            CreateTaskScreen(onCreated: {
                showCreateTask = false
                reloadData()
            })
        }
        .task {
            reloadData()
        }
    }

    private func reloadData() {
        loading = true
        Task {
            await reloadDataAsync()
        }
    }

    private func reloadDataAsync() async {
        do {
            let taskList = try await SupabaseApi.shared.getTasks()
            let taskIds = taskList.map { $0.id }
            let aList = try await SupabaseApi.shared.getAssignees(taskIds: taskIds)
            let empList = try await SupabaseApi.shared.getActiveEmployees()

            await MainActor.run {
                self.tasks = taskList
                self.assignees = aList
                self.employees = empList
                self.loading = false
            }
        } catch {
            await MainActor.run {
                self.loading = false
            }
        }
    }

    private func respondAcceptance(task: HrTask, accepted: Bool) {
        Task {
            _ = try? await SupabaseApi.shared.respondAcceptance(
                taskId: task.id,
                employeeId: myEmployeeId,
                accepted: accepted,
                note: accepted ? nil : "Nhân sự từ chối"
            )
            reloadData()
        }
    }
}

private struct TabItemButton: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 6) {
                Text(title)
                    .font(.subheadline)
                    .bold()
                    .foregroundColor(isSelected ? Color(red: 0.07, green: 0.45, blue: 0.20) : .secondary)
                Rectangle()
                    .fill(isSelected ? Color(red: 0.07, green: 0.45, blue: 0.20) : Color.clear)
                    .frame(height: 3)
            }
            .frame(maxWidth: .infinity)
        }
    }
}

private struct FilterChipButton: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.footnote)
                .bold()
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(isSelected ? Color(red: 0.07, green: 0.45, blue: 0.20) : Color(.systemBackground))
                .foregroundColor(isSelected ? .white : .primary)
                .cornerRadius(16)
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(isSelected ? Color.clear : Color(.systemGray4), lineWidth: 1)
                )
        }
    }
}

private struct TaskCardView: View {
    let task: HrTask
    let ownerName: String
    let collaboratorNames: [String]
    let canAccept: Bool
    let onAccept: () -> Void
    let onDecline: () -> Void

    private var statusInfo: (String, Color, Color) {
        switch task.status {
        case "completed":
            return ("Hoàn thành", Color(red: 0.07, green: 0.55, blue: 0.20), Color(red: 0.88, green: 0.96, blue: 0.88))
        case "in_progress":
            return ("Đang thực hiện", Color(red: 0.1, green: 0.45, blue: 0.85), Color(red: 0.9, green: 0.94, blue: 1.0))
        case "awaiting_acceptance":
            return ("Chờ nhận việc", Color(red: 0.9, green: 0.45, blue: 0.0), Color(red: 1.0, green: 0.93, blue: 0.85))
        case "declined":
            return ("Đã từ chối", Color.red, Color(red: 1.0, green: 0.9, blue: 0.9))
        default:
            return ("Chờ xử lý", Color(red: 0.9, green: 0.45, blue: 0.0), Color(red: 1.0, green: 0.93, blue: 0.85))
        }
    }

    private var priorityInfo: (String, Color, Color) {
        switch task.priority {
        case "urgent":
            return ("Khẩn cấp", Color.red, Color(red: 1.0, green: 0.9, blue: 0.9))
        case "high":
            return ("Cao", Color.orange, Color(red: 1.0, green: 0.93, blue: 0.85))
        case "low":
            return ("Thấp", Color.gray, Color(.systemGray5))
        default:
            return ("Trung bình", Color(red: 0.15, green: 0.55, blue: 0.25), Color(red: 0.88, green: 0.95, blue: 0.88))
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            // Badges row: Priority & Status
            HStack {
                let p = priorityInfo
                Text(p.0)
                    .font(.caption2)
                    .bold()
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(p.2)
                    .foregroundColor(p.1)
                    .cornerRadius(6)

                Spacer()

                let s = statusInfo
                Text(s.0)
                    .font(.caption2)
                    .bold()
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(s.2)
                    .foregroundColor(s.1)
                    .cornerRadius(6)
            }

            // Title
            Text(task.title)
                .font(.headline)
                .foregroundColor(.primary)
                .lineLimit(2)

            // Project name
            if let proj = task.project_name, !proj.isEmpty {
                HStack(spacing: 4) {
                    Image(systemName: "mappin.and.ellipse").font(.caption)
                    Text(proj).font(.caption).bold()
                }
                .foregroundColor(Color(red: 0.07, green: 0.45, blue: 0.20))
            }

            // Assignees & Due date
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Image(systemName: "person.fill").font(.caption).foregroundColor(.secondary)
                    Text("Phụ trách: \(ownerName)").font(.caption).foregroundColor(.secondary)
                }

                if !collaboratorNames.isEmpty {
                    HStack(spacing: 6) {
                        Image(systemName: "person.2.fill").font(.caption).foregroundColor(.secondary)
                        Text("Hỗ trợ: \(collaboratorNames.joined(separator: ", "))").font(.caption).foregroundColor(.secondary)
                    }
                }

                if let due = task.due_date, !due.isEmpty {
                    HStack(spacing: 6) {
                        Image(systemName: "calendar.badge.clock").font(.caption).foregroundColor(.secondary)
                        Text("Hạn: \(due)").font(.caption).foregroundColor(.secondary)
                    }
                }
            }

            // Progress bar
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text("Tiến độ:").font(.caption2).foregroundColor(.secondary)
                    Spacer()
                    Text("\(task.progress)%").font(.caption2).bold().foregroundColor(statusInfo.1)
                }
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 4)
                            .fill(Color(.systemGray5))
                            .frame(height: 6)
                        RoundedRectangle(cornerRadius: 4)
                            .fill(statusInfo.1)
                            .frame(width: max(0, min(geo.size.width * CGFloat(task.progress) / 100.0, geo.size.width)), height: 6)
                    }
                }
                .frame(height: 6)
            }
            .padding(.top, 2)

            // Action buttons if awaiting acceptance
            if canAccept {
                Divider().padding(.vertical, 4)
                HStack(spacing: 12) {
                    Button(action: onDecline) {
                        Text("Từ chối")
                            .font(.footnote)
                            .bold()
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 8)
                            .foregroundColor(.red)
                            .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.red, lineWidth: 1))
                    }

                    Button(action: onAccept) {
                        Text("Nhận việc")
                            .font(.footnote)
                            .bold()
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 8)
                            .background(Color(red: 0.07, green: 0.45, blue: 0.20))
                            .foregroundColor(.white)
                            .cornerRadius(8)
                    }
                }
            }
        }
        .padding(14)
        .background(Color(.secondarySystemBackground))
        .cornerRadius(14)
    }
}
