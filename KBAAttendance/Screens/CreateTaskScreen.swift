import SwiftUI

struct CreateTaskScreen: View {
    var onCreated: (() -> Void)? = nil

    @Environment(\.presentationMode) var presentationMode
    @EnvironmentObject var store: SessionStore

    @State private var title = ""
    @State private var description = ""
    @State private var notes = ""
    @State private var priority = "medium" // low, medium, high, urgent
    @State private var dueDate = Date().addingTimeInterval(86400 * 3)
    @State private var hasDueDate = true

    // Project
    @State private var isOtherProject = false
    @State private var customProjectName = ""
    @State private var selectedProjectId: String? = nil
    @State private var projects: [Project] = []

    // People
    @State private var selectedOwnerId: String? = nil
    @State private var selectedCollaboratorIds = Set<String>()
    @State private var employees: [Employee] = []

    // Recurrence
    @State private var isRecurring = false
    @State private var recurringCycle = "weekly" // daily, weekly, monthly
    @State private var recurringWeekday = 1 // 1: Mon .. 7: Sun

    @State private var submitting = false
    @State private var errorMsg: String?

    private let dateFmt: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.timeZone = TimeZone(identifier: "Asia/Ho_Chi_Minh")
        f.dateFormat = "yyyy-MM-dd"
        return f
    }()

    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Thông tin cơ bản")) {
                    TextField("Tiêu đề nhiệm vụ *", text: $title)
                    TextField("Mô tả chi tiết", text: $description)
                }

                Section(header: Text("Dự án liên quan")) {
                    Toggle("Không thuộc dự án cụ thể / Khác", isOn: $isOtherProject)

                    if isOtherProject {
                        TextField("Nhập tên dự án hoặc địa điểm", text: $customProjectName)
                    } else {
                        Picker("Chọn dự án", selection: $selectedProjectId) {
                            Text("— Chưa chọn dự án —").tag(String?.none)
                            ForEach(projects) { proj in
                                Text(proj.name).tag(String?.some(proj.id))
                            }
                        }
                    }
                }

                Section(header: Text("Mức độ ưu tiên")) {
                    Picker("Mức độ", selection: $priority) {
                        Text("Thấp").tag("low")
                        Text("Trung bình").tag("medium")
                        Text("Cao").tag("high")
                        Text("Khẩn cấp").tag("urgent")
                    }
                    .pickerStyle(.segmented)
                }

                Section(header: Text("Thời hạn")) {
                    Toggle("Có hạn hoàn thành", isOn: $hasDueDate)
                    if hasDueDate {
                        DatePicker("Hạn hoàn thành", selection: $dueDate, displayedComponents: .date)
                            .environment(\.locale, Locale(identifier: "vi_VN"))
                    }
                }

                Section(header: Text("Phân công nhân sự")) {
                    Picker("Phụ trách chính *", selection: $selectedOwnerId) {
                        Text("— Chọn người phụ trách —").tag(String?.none)
                        ForEach(employees) { emp in
                            Text(emp.full_name + (emp.department.map { " (\($0))" } ?? "")).tag(String?.some(emp.id))
                        }
                    }

                    // Multi-select for collaborators
                    NavigationLink(destination: CollaboratorsSelectionView(
                        employees: employees,
                        ownerId: selectedOwnerId,
                        selectedIds: $selectedCollaboratorIds
                    )) {
                        HStack {
                            Text("Người phối hợp")
                            Spacer()
                            Text(selectedCollaboratorIds.isEmpty ? "Chưa chọn" : "\(selectedCollaboratorIds.count) người")
                                .foregroundColor(.secondary)
                        }
                    }
                }

                Section(header: Text("Lặp lại định kỳ")) {
                    Toggle("Lặp lại định kỳ", isOn: $isRecurring)
                    if isRecurring {
                        Picker("Chu kỳ", selection: $recurringCycle) {
                            Text("Hàng ngày").tag("daily")
                            Text("Hàng tuần").tag("weekly")
                            Text("Hàng tháng").tag("monthly")
                        }
                    }
                }

                Section(header: Text("Ghi chú thêm")) {
                    TextField("Ghi chú (tuỳ chọn)", text: $notes)
                }

                if let err = errorMsg {
                    Section {
                        Text(err).foregroundColor(.red).font(.footnote)
                    }
                }

                Section {
                    Button(action: submitTask) {
                        HStack {
                            Spacer()
                            if submitting {
                                ProgressView().tint(.white)
                            }
                            Text("Tạo nhiệm vụ").bold()
                            Spacer()
                        }
                    }
                    .disabled(submitting || title.trimmingCharacters(in: .whitespaces).isEmpty || selectedOwnerId == nil)
                    .listRowBackground(
                        (title.trimmingCharacters(in: .whitespaces).isEmpty || selectedOwnerId == nil || submitting)
                            ? Color.gray
                            : Color(red: 0.07, green: 0.45, blue: 0.20)
                    )
                    .foregroundColor(.white)
                }
            }
            .navigationTitle("Tạo nhiệm vụ mới")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Đóng") { presentationMode.wrappedValue.dismiss() }
                }
            }
            .task {
                loadInitialData()
            }
        }
    }

    private func loadInitialData() {
        Task {
            let pList = (try? await SupabaseApi.shared.getAllProjects()) ?? []
            let eList = (try? await SupabaseApi.shared.getActiveEmployees()) ?? []
            await MainActor.run {
                self.projects = pList
                self.employees = eList
                if self.selectedOwnerId == nil {
                    self.selectedOwnerId = store.session.employeeId
                }
            }
        }
    }

    private func submitTask() {
        let trimmedTitle = title.trimmingCharacters(in: .whitespaces)
        guard !trimmedTitle.isEmpty, let ownerId = selectedOwnerId, let uid = store.session.userId else { return }

        submitting = true
        errorMsg = nil

        var projId: String? = nil
        var projName: String? = nil
        if isOtherProject {
            if !customProjectName.trimmingCharacters(in: .whitespaces).isEmpty {
                projName = customProjectName.trimmingCharacters(in: .whitespaces)
            }
        } else if let selId = selectedProjectId {
            projId = selId
            projName = projects.first(where: { $0.id == selId })?.name
        }

        let dueStr = hasDueDate ? dateFmt.string(from: dueDate) : nil
        let createdDateStr = dateFmt.string(from: Date())

        let payload = CreateTaskPayload(
            title: trimmedTitle,
            description: description.trimmingCharacters(in: .whitespaces).isEmpty ? nil : description.trimmingCharacters(in: .whitespaces),
            project_id: projId,
            project_name: projName,
            priority: priority,
            due_date: dueStr,
            assigned_to: ownerId,
            created_by: uid,
            status: "awaiting_acceptance",
            progress: 0,
            created_date: createdDateStr,
            recurrence: isRecurring ? TaskRecurrence(freq: recurringCycle, weekday: recurringWeekday) : nil,
            notes: notes.trimmingCharacters(in: .whitespaces).isEmpty ? nil : notes.trimmingCharacters(in: .whitespaces)
        )

        let collabList = Array(selectedCollaboratorIds)

        Task {
            do {
                let success = try await SupabaseApi.shared.createTask(
                    payload: payload,
                    ownerEmployeeId: ownerId,
                    collaboratorEmployeeIds: collabList,
                    employees: employees
                )
                await MainActor.run {
                    self.submitting = false
                    if success {
                        onCreated?()
                        presentationMode.wrappedValue.dismiss()
                    } else {
                        self.errorMsg = "Không thể tạo nhiệm vụ. Vui lòng thử lại."
                    }
                }
            } catch {
                await MainActor.run {
                    self.submitting = false
                    self.errorMsg = error.localizedDescription
                }
            }
        }
    }
}

private struct CollaboratorsSelectionView: View {
    let employees: [Employee]
    let ownerId: String?
    @Binding var selectedIds: Set<String>

    var body: some View {
        List {
            ForEach(employees.filter { $0.id != ownerId }) { emp in
                Button(action: {
                    if selectedIds.contains(emp.id) {
                        selectedIds.remove(emp.id)
                    } else {
                        selectedIds.insert(emp.id)
                    }
                }) {
                    HStack {
                        VStack(alignment: .leading) {
                            Text(emp.full_name).font(.body).foregroundColor(.primary)
                            if let dep = emp.department, !dep.isEmpty {
                                Text(dep).font(.caption).foregroundColor(.secondary)
                            }
                        }
                        Spacer()
                        if selectedIds.contains(emp.id) {
                            Image(systemName: "checkmark").foregroundColor(Color(red: 0.07, green: 0.45, blue: 0.20)).bold()
                        }
                    }
                }
            }
        }
        .navigationTitle("Chọn người phối hợp")
    }
}
