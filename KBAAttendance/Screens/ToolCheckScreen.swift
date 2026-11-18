import SwiftUI

private let vnTZ = TimeZone(identifier: "Asia/Ho_Chi_Minh")!

private func dateToStr(_ date: Date, fmt: String = "yyyy-MM-dd") -> String {
    let f = DateFormatter()
    f.locale = Locale(identifier: "en_US_POSIX")
    f.timeZone = vnTZ
    f.dateFormat = fmt
    return f.string(from: date)
}

private func getWeekRange(weekOffset: Int = 0) -> (Date, Date) {
    var cal = Calendar(identifier: .gregorian)
    cal.timeZone = vnTZ
    cal.firstWeekday = 2 // Monday

    let now = Date()
    var targetDate = cal.date(byAdding: .weekOfYear, value: weekOffset, to: now) ?? now
    var comps = cal.dateComponents([.yearForWeekOfYear, .weekOfYear], from: targetDate)
    comps.weekday = 2 // Monday
    comps.hour = 0
    comps.minute = 0
    comps.second = 0
    let monday = cal.date(from: comps) ?? targetDate
    let saturday = cal.date(byAdding: .day, value: 5, to: monday) ?? monday
    return (monday, saturday)
}

private func weekDays(from monday: Date) -> [Date] {
    var cal = Calendar(identifier: .gregorian)
    cal.timeZone = vnTZ
    return (0...5).compactMap { cal.date(byAdding: .day, value: $0, to: monday) }
}

private func dayOfWeekVi(_ date: Date) -> String {
    var cal = Calendar(identifier: .gregorian)
    cal.timeZone = vnTZ
    let dow = cal.component(.weekday, from: date)
    switch dow {
    case 2: return "T2"
    case 3: return "T3"
    case 4: return "T4"
    case 5: return "T5"
    case 6: return "T6"
    case 7: return "T7"
    default: return "CN"
    }
}

struct ToolCheckScreen: View {
    @EnvironmentObject var store: SessionStore

    @State private var items: [ToolCheckItem] = []
    @State private var entries: [ToolCheckEntry] = []
    @State private var loading = true
    @State private var errorMsg: String?
    @State private var savingKey: String?

    @State private var weekOffset = 0
    @State private var selectedDayIndex = 0

    // Dialog for entering project name
    @State private var dialogItem: ToolCheckItem?
    @State private var dialogProjectName = ""
    @State private var dialogNote = ""
    @State private var showProjectDialog = false

    private var weekStartAndEnd: (Date, Date) {
        getWeekRange(weekOffset: weekOffset)
    }

    private var days: [Date] {
        weekDays(from: weekStartAndEnd.0)
    }

    private var selectedDate: Date {
        if selectedDayIndex < days.count {
            return days[selectedDayIndex]
        }
        return Date()
    }

    private var inspectorName: String {
        store.session.employeeName ?? ""
    }

    var body: some View {
        VStack(spacing: 0) {
            // Week navigation header
            VStack(spacing: 8) {
                HStack {
                    Button(action: {
                        weekOffset -= 1
                    }) {
                        Image(systemName: "chevron.left")
                            .font(.headline)
                            .padding(8)
                            .background(Color(.systemGray5))
                            .cornerRadius(8)
                    }

                    Spacer()

                    VStack {
                        Text("Tuần \(dateToStr(weekStartAndEnd.0, fmt: "dd/MM")) - \(dateToStr(weekStartAndEnd.1, fmt: "dd/MM/yyyy"))")
                            .font(.headline)
                        if weekOffset == 0 {
                            Text("Tuần hiện tại").font(.caption).foregroundColor(Color(red: 0.07, green: 0.45, blue: 0.20)).bold()
                        } else {
                            Button("Về tuần này") { weekOffset = 0 }
                                .font(.caption).foregroundColor(.blue)
                        }
                    }

                    Spacer()

                    Button(action: {
                        weekOffset += 1
                    }) {
                        Image(systemName: "chevron.right")
                            .font(.headline)
                            .padding(8)
                            .background(Color(.systemGray5))
                            .cornerRadius(8)
                    }
                }
                .padding(.horizontal)
                .padding(.top, 8)

                // Day selector (T2 .. T7)
                HStack(spacing: 6) {
                    ForEach(Array(days.enumerated()), id: \.offset) { idx, d in
                        let isSelected = idx == selectedDayIndex
                        Button(action: { selectedDayIndex = idx }) {
                            VStack(spacing: 2) {
                                Text(dayOfWeekVi(d))
                                    .font(.caption2)
                                    .bold()
                                Text(dateToStr(d, fmt: "dd/MM"))
                                    .font(.system(size: 11))
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 8)
                            .background(isSelected ? Color(red: 0.07, green: 0.45, blue: 0.20) : Color(.systemBackground))
                            .foregroundColor(isSelected ? .white : .primary)
                            .cornerRadius(10)
                            .overlay(
                                RoundedRectangle(cornerRadius: 10)
                                    .stroke(isSelected ? Color.clear : Color(.systemGray4), lineWidth: 1)
                            )
                        }
                    }
                }
                .padding(.horizontal)
                .padding(.bottom, 8)

                // Current day summary banner
                HStack {
                    Image(systemName: "calendar")
                    Text("Ngày: \(dateToStr(selectedDate, fmt: "EEEE, dd/MM/yyyy"))")
                        .font(.footnote)
                        .bold()
                    Spacer()
                    if !inspectorName.isEmpty {
                        Text("KTV: \(inspectorName)").font(.caption).foregroundColor(.secondary)
                    }
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 6)
                .background(Color(.systemGray6))
            }
            .background(Color(.secondarySystemBackground))

            // Tool checklist
            if loading && items.isEmpty {
                Spacer()
                ProgressView("Đang tải danh mục kiểm tra…")
                Spacer()
            } else if let err = errorMsg, items.isEmpty {
                Spacer()
                Text(err).foregroundColor(.red).padding()
                Button("Thử lại") { loadData() }
                Spacer()
            } else if items.isEmpty {
                Spacer()
                Text("Không có công cụ dụng cụ nào cần kiểm tra").foregroundColor(.secondary)
                Spacer()
            } else {
                List(items) { item in
                    let dateStr = dateToStr(selectedDate)
                    let entry = entries.first(where: { $0.item_id == item.id && $0.check_date == dateStr })
                    let isSaving = savingKey == "\(item.id)_\(dateStr)"

                    ToolCheckRow(
                        item: item,
                        entry: entry,
                        isSaving: isSaving,
                        onToggleWarehouse: {
                            toggleWarehouse(item: item, date: selectedDate)
                        },
                        onProjectTap: {
                            dialogItem = item
                            dialogProjectName = entry?.project_name ?? ""
                            dialogNote = entry?.note ?? ""
                            showProjectDialog = true
                        }
                    )
                    .listRowInsets(EdgeInsets(top: 6, leading: 14, bottom: 6, trailing: 14))
                    .listRowSeparator(.hidden)
                }
                .listStyle(.plain)
                .refreshable {
                    await reloadDataAsync()
                }
            }
        }
        .navigationTitle("Kiểm tra CCDC hàng ngày")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button(action: { loadData() }) {
                    Image(systemName: "arrow.clockwise")
                }
            }
        }
        .sheet(isPresented: $showProjectDialog) {
            if let targetItem = dialogItem {
                NavigationView {
                    Form {
                        Section(header: Text("Thiết bị / Dụng cụ")) {
                            Text(targetItem.name).bold()
                            if let c = targetItem.code, !c.isEmpty {
                                Text("Mã: \(c)").font(.caption).foregroundColor(.secondary)
                            }
                        }

                        Section(header: Text("Thông tin dự án đang sử dụng")) {
                            TextField("Nhập tên dự án (VD: Nhà thi đấu, KĐT…)", text: $dialogProjectName)
                            TextField("Ghi chú thêm (tuỳ chọn)", text: $dialogNote)
                        }

                        Section {
                            Button("Lưu trạng thái dự án") {
                                saveProjectEntry(item: targetItem, date: selectedDate, projectName: dialogProjectName, note: dialogNote)
                                showProjectDialog = false
                            }
                            .bold()
                            .frame(maxWidth: .infinity, alignment: .center)
                            .foregroundColor(Color(red: 0.07, green: 0.45, blue: 0.20))

                            if entries.contains(where: { $0.item_id == targetItem.id && $0.check_date == dateToStr(selectedDate) }) {
                                Button("Huỷ kiểm tra (Xoá ghi nhận)", role: .destructive) {
                                    deleteEntry(item: targetItem, date: selectedDate)
                                    showProjectDialog = false
                                }
                                .frame(maxWidth: .infinity, alignment: .center)
                            }
                        }
                    }
                    .navigationTitle("Vị trí tại Dự án")
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar {
                        ToolbarItem(placement: .navigationBarLeading) {
                            Button("Đóng") { showProjectDialog = false }
                        }
                    }
                }
            }
        }
        .task {
            loadData()
        }
        .onChange(of: weekOffset) { _ in
            loadData()
        }
    }

    private func loadData() {
        loading = true
        errorMsg = nil
        Task {
            await reloadDataAsync()
        }
    }

    private func reloadDataAsync() async {
        do {
            let fromStr = dateToStr(weekStartAndEnd.0)
            let toStr = dateToStr(weekStartAndEnd.1)
            let itList = try await SupabaseApi.shared.getToolCheckItems()
            let entList = try await SupabaseApi.shared.getToolCheckEntries(from: fromStr, to: toStr)
            await MainActor.run {
                self.items = itList
                self.entries = entList
                self.loading = false
            }
        } catch {
            await MainActor.run {
                self.errorMsg = error.localizedDescription
                self.loading = false
            }
        }
    }

    private func toggleWarehouse(item: ToolCheckItem, date: Date) {
        let dateStr = dateToStr(date)
        let existing = entries.first(where: { $0.item_id == item.id && $0.check_date == dateStr })
        let key = "\(item.id)_\(dateStr)"
        savingKey = key

        Task {
            do {
                if let ex = existing, ex.in_warehouse {
                    _ = try await SupabaseApi.shared.deleteToolCheckEntry(itemId: item.id, checkDate: dateStr)
                    await MainActor.run {
                        self.entries.removeAll(where: { $0.item_id == item.id && $0.check_date == dateStr })
                    }
                } else {
                    let upsert = ToolCheckEntryUpsert(
                        item_id: item.id,
                        check_date: dateStr,
                        in_warehouse: true,
                        project_name: nil,
                        note: nil,
                        inspector: inspectorName.isEmpty ? nil : inspectorName
                    )
                    _ = try await SupabaseApi.shared.upsertToolCheckEntry(upsert)
                    await MainActor.run {
                        self.entries.removeAll(where: { $0.item_id == item.id && $0.check_date == dateStr })
                        self.entries.append(ToolCheckEntry(
                            id: nil,
                            item_id: item.id,
                            check_date: dateStr,
                            in_warehouse: true,
                            project_name: nil,
                            note: nil,
                            inspector: inspectorName.isEmpty ? nil : inspectorName
                        ))
                    }
                }
            } catch {
                print("Lỗi toggle kho: \(error)")
            }
            await MainActor.run { self.savingKey = nil }
        }
    }

    private func saveProjectEntry(item: ToolCheckItem, date: Date, projectName: String, note: String) {
        let dateStr = dateToStr(date)
        let trimmed = projectName.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else {
            deleteEntry(item: item, date: date)
            return
        }

        let key = "\(item.id)_\(dateStr)"
        savingKey = key

        Task {
            do {
                let upsert = ToolCheckEntryUpsert(
                    item_id: item.id,
                    check_date: dateStr,
                    in_warehouse: false,
                    project_name: trimmed,
                    note: note.isEmpty ? nil : note,
                    inspector: inspectorName.isEmpty ? nil : inspectorName
                )
                _ = try await SupabaseApi.shared.upsertToolCheckEntry(upsert)
                await MainActor.run {
                    self.entries.removeAll(where: { $0.item_id == item.id && $0.check_date == dateStr })
                    self.entries.append(ToolCheckEntry(
                        id: nil,
                        item_id: item.id,
                        check_date: dateStr,
                        in_warehouse: false,
                        project_name: trimmed,
                        note: note.isEmpty ? nil : note,
                        inspector: inspectorName.isEmpty ? nil : inspectorName
                    ))
                }
            } catch {
                print("Lỗi lưu dự án: \(error)")
            }
            await MainActor.run { self.savingKey = nil }
        }
    }

    private func deleteEntry(item: ToolCheckItem, date: Date) {
        let dateStr = dateToStr(date)
        let key = "\(item.id)_\(dateStr)"
        savingKey = key

        Task {
            do {
                _ = try await SupabaseApi.shared.deleteToolCheckEntry(itemId: item.id, checkDate: dateStr)
                await MainActor.run {
                    self.entries.removeAll(where: { $0.item_id == item.id && $0.check_date == dateStr })
                }
            } catch {
                print("Lỗi xoá entry: \(error)")
            }
            await MainActor.run { self.savingKey = nil }
        }
    }
}

private struct ToolCheckRow: View {
    let item: ToolCheckItem
    let entry: ToolCheckEntry?
    let isSaving: Bool
    let onToggleWarehouse: () -> Void
    let onProjectTap: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            // Title & code
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(item.name)
                        .font(.headline)
                        .foregroundColor(.primary)
                    if let code = item.code, !code.isEmpty {
                        Text("Mã: \(code)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }

                Spacer()

                if isSaving {
                    ProgressView().scaleEffect(0.8)
                } else if let e = entry {
                    if e.in_warehouse {
                        Text("Ở KHO")
                            .font(.caption2).bold()
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Color(red: 0.86, green: 0.95, blue: 0.88))
                            .foregroundColor(Color(red: 0.07, green: 0.45, blue: 0.20))
                            .cornerRadius(6)
                    } else if let p = e.project_name, !p.isEmpty {
                        Text("DỰ ÁN: \(p)")
                            .font(.caption2).bold()
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Color(red: 0.9, green: 0.94, blue: 1.0))
                            .foregroundColor(Color(red: 0.1, green: 0.4, blue: 0.8))
                            .cornerRadius(6)
                    }
                } else {
                    Text("Chưa check")
                        .font(.caption2)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color(.systemGray5))
                        .foregroundColor(.secondary)
                        .cornerRadius(6)
                }
            }

            if let note = entry?.note, !note.isEmpty {
                Text("Ghi chú: \(note)")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .italic()
            }

            // Action Buttons
            HStack(spacing: 10) {
                // Toggle Kho button
                Button(action: onToggleWarehouse) {
                    HStack {
                        Image(systemName: (entry?.in_warehouse == true) ? "checkmark.circle.fill" : "circle")
                        Text("Ở KHO")
                            .font(.footnote)
                            .bold()
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
                    .background((entry?.in_warehouse == true) ? Color(red: 0.07, green: 0.45, blue: 0.20) : Color(.systemBackground))
                    .foregroundColor((entry?.in_warehouse == true) ? .white : Color(red: 0.07, green: 0.45, blue: 0.20))
                    .cornerRadius(8)
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(Color(red: 0.07, green: 0.45, blue: 0.20), lineWidth: 1)
                    )
                }

                // Project button
                Button(action: onProjectTap) {
                    HStack {
                        Image(systemName: "building.2")
                        Text((entry?.in_warehouse == false && entry?.project_name != nil) ? "ĐỔI DỰ ÁN" : "DỰ ÁN")
                            .font(.footnote)
                            .bold()
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
                    .background((entry?.in_warehouse == false && entry?.project_name != nil) ? Color.blue : Color(.systemBackground))
                    .foregroundColor((entry?.in_warehouse == false && entry?.project_name != nil) ? .white : .blue)
                    .cornerRadius(8)
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(Color.blue, lineWidth: 1)
                    )
                }
            }
        }
        .padding(14)
        .background(Color(.secondarySystemBackground))
        .cornerRadius(12)
    }
}
