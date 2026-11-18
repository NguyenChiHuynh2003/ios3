import SwiftUI

private let vnTZ = TimeZone(identifier: "Asia/Ho_Chi_Minh")!

private let dateFmtAPI: DateFormatter = {
    let f = DateFormatter()
    f.locale = Locale(identifier: "en_US_POSIX")
    f.timeZone = vnTZ
    f.dateFormat = "yyyy-MM-dd"
    return f
}()

private let timeFmt: DateFormatter = {
    let f = DateFormatter()
    f.locale = Locale(identifier: "en_US_POSIX")
    f.timeZone = vnTZ
    f.dateFormat = "HH:mm:ss"
    return f
}()

private let displayFmt: DateFormatter = {
    let f = DateFormatter()
    f.locale = Locale(identifier: "vi_VN")
    f.timeZone = vnTZ
    f.dateFormat = "EEEE, dd/MM/yyyy"
    return f
}()

struct HomeScreen: View {
    @EnvironmentObject var store: SessionStore
    @EnvironmentObject var chatSync: ChatSyncService
    @State private var today: AttendanceRecord?
    @State private var loading = false
    @State private var msg: String?
    @State private var offSite = false
    @State private var notes = ""

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 12) {
                    // Greeting card
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Xin chào,").font(.caption).foregroundColor(.secondary)
                        Text(store.session.employeeName ?? "...").font(.title3).bold()
                        let sub = [store.session.position, store.session.department].compactMap { $0 }.filter { !$0.isEmpty }.joined(separator: " • ")
                        if !sub.isEmpty { Text(sub).font(.caption).foregroundColor(.secondary) }
                        Text(displayFmt.string(from: Date()).capitalized).font(.caption).padding(.top, 4)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding()
                    .background(Color(.secondarySystemBackground))
                    .cornerRadius(12)

                    // Today attendance card
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Chấm công hôm nay").font(.headline)
                        Text("Vào: \(today?.check_in ?? "—")")
                        Text("Ra:  \(today?.check_out ?? "—")")
                        if today?.off_site == true {
                            Text("📍 Ngoài site").font(.caption)
                        }
                        Toggle("Đi công tác (ngoài site)", isOn: $offSite)
                            .disabled(today != nil)
                        TextField("Ghi chú (tuỳ chọn)", text: $notes)
                            .textFieldStyle(.roundedBorder)
                            .disabled(today != nil)

                        Button(action: doCheckIn) {
                            HStack {
                                if loading { ProgressView().tint(.white) }
                                Text(today == nil ? "Chấm công" : "Đã chấm công hôm nay").bold()
                            }
                            .frame(maxWidth: .infinity, minHeight: 48)
                            .background(today != nil ? Color.gray : Color(red: 0.07, green: 0.45, blue: 0.20))
                            .foregroundColor(.white)
                            .cornerRadius(10)
                        }
                        .disabled(today != nil || loading)

                        if let m = msg { Text(m).font(.footnote) }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding()
                    .background(Color(red: 0.86, green: 0.95, blue: 0.88))
                    .cornerRadius(12)

                    // 1. Đơn nghỉ phép
                    NavigationLink(destination: LeaveScreen()) {
                        navRow(icon: "calendar.badge.clock", title: "Đơn nghỉ phép", sub: "Xem trạng thái duyệt")
                    }

                    // 2. Lịch sử chấm công
                    NavigationLink(destination: HistoryScreen()) {
                        navRow(icon: "clock.arrow.circlepath", title: "Lịch sử chấm công", sub: "Tháng hiện tại")
                    }

                    // 3. Chat nội bộ
                    NavigationLink(destination: ChatListScreen()) {
                        navRow(icon: "bubble.left.and.bubble.right", title: "Chat nội bộ", sub: "Trò chuyện với đồng nghiệp", badge: chatSync.totalUnread)
                    }

                    // 4. Quản lý nhiệm vụ
                    NavigationLink(destination: TaskListScreen()) {
                        navRow(icon: "list.bullet.clipboard", title: "Quản lý nhiệm vụ", sub: "Giao việc, nhận việc & báo cáo tiến độ")
                    }

                    // 5. Quản lý dự án (chỉ hiển thị nếu có quyền projects)
                    if store.session.allowedModules.contains("projects") || store.session.canEditModules.contains("projects") {
                        NavigationLink(destination: ProjectListScreen()) {
                            navRow(icon: "point.3.connected.trianglepath.dotted", title: "Quản lý dự án", sub: "Danh sách, thành viên & tiến độ dự án")
                        }
                    }

                    // 6. Kho công cụ dụng cụ
                    NavigationLink(destination: WarehouseStockScreen()) {
                        navRow(icon: "building.2.crop.list", title: "Kho công cụ dụng cụ", sub: "Xem danh sách & số lượng tồn kho")
                    }

                    // 7. Kiểm tra CCDC hàng ngày (chỉ hiển thị nếu có quyền equipment-statistics)
                    if store.session.canEditModules.contains("equipment-statistics") {
                        NavigationLink(destination: ToolCheckScreen()) {
                            navRow(icon: "checklist", title: "Kiểm tra CCDC hàng ngày", sub: "Phiếu kiểm tra công cụ, dụng cụ theo tuần")
                        }
                    }

                    // 8. Hướng dẫn sử dụng
                    NavigationLink(destination: GuideScreen()) {
                        navRow(icon: "questionmark.circle", title: "Hướng dẫn sử dụng", sub: "Cách dùng app KBA Chấm công")
                    }
                }
                .padding()
            }
            .navigationTitle("KBA Chấm công")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    HStack(spacing: 8) {
                        Image("Logo")
                            .resizable()
                            .scaledToFit()
                            .frame(width: 28, height: 28)
                        Text("KBA Chấm công")
                            .font(.headline)
                            .bold()
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: { store.clear() }) {
                        Image(systemName: "rectangle.portrait.and.arrow.right")
                    }
                }
            }
            .task {
                await reload()
                await checkPermissions()
            }
        }
        .navigationViewStyle(.stack)
    }

    private func navRow(icon: String, title: String, sub: String, badge: Int = 0) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon).font(.title2).foregroundColor(Color(red: 0.07, green: 0.45, blue: 0.20))
                .frame(width: 28)
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.body).bold().foregroundColor(.primary)
                Text(sub).font(.caption).foregroundColor(.secondary)
            }
            Spacer()
            if badge > 0 {
                Text("\(badge)")
                    .font(.caption2)
                    .bold()
                    .foregroundColor(.white)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.red)
                    .clipShape(Capsule())
            }
            Image(systemName: "chevron.right").foregroundColor(.secondary)
        }
        .padding()
        .background(Color(.secondarySystemBackground))
        .cornerRadius(12)
    }

    private func reload() async {
        guard let emp = store.session.employeeId else { return }
        let date = dateFmtAPI.string(from: Date())
        today = try? await SupabaseApi.shared.getTodayAttendance(employeeId: emp, date: date)
    }

    private func checkPermissions() async {
        guard let uid = store.session.userId, store.session.allowedModules.isEmpty else { return }
        if let perms = try? await SupabaseApi.shared.getUserPermissions(userId: uid) {
            store.savePermissions(allowed: perms.allowed_modules, canEdit: perms.can_edit_modules)
        }
    }

    private func doCheckIn() {
        guard let emp = store.session.employeeId else { return }
        loading = true
        msg = nil
        Task {
            let date = dateFmtAPI.string(from: Date())
            let now = timeFmt.string(from: Date())
            let rec = AttendanceRecord(
                id: nil,
                employee_id: emp,
                work_date: date,
                check_in: now,
                check_out: "17:00:00",
                status: "present",
                notes: notes.isEmpty ? nil : notes,
                off_site: offSite
            )
            do {
                _ = try await SupabaseApi.shared.checkIn(record: rec)
                await MainActor.run {
                    self.msg = "Đã chấm công lúc \(now) (giờ ra mặc định 17:00)"
                    self.today = rec
                    self.loading = false
                }
            } catch {
                await MainActor.run {
                    let errMsg = error.localizedDescription
                    if errMsg.contains("23505") || errMsg.contains("duplicate") || errMsg.contains("409") {
                        self.msg = "Bạn đã chấm công hôm nay rồi. Mai mới được chấm tiếp."
                        self.today = rec
                    } else {
                        self.msg = "Lỗi: \(errMsg)"
                    }
                    self.loading = false
                }
            }
        }
    }
}
