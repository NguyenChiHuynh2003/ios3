import SwiftUI

func fmtDate(_ s: String) -> String {
    guard s.count >= 10 else { return s }
    let p = s.prefix(10).split(separator: "-")
    guard p.count == 3 else { return s }
    return "\(p[2])/\(p[1])/\(p[0])"
}

private func statusLabel(_ s: String) -> (String, Color) {
    switch s {
    case "approved": return ("Đã duyệt", Color(red: 0.09, green: 0.64, blue: 0.29))
    case "rejected": return ("Từ chối", Color(red: 0.86, green: 0.15, blue: 0.15))
    case "pending": return ("Chờ duyệt", Color(red: 0.85, green: 0.47, blue: 0.02))
    default: return (s, .gray)
    }
}

private func leaveTypeTitle(_ type: String) -> String {
    switch type {
    case "leave": return "Đơn xin nghỉ"
    case "absence": return "Đơn vắng mặt"
    case "overtime": return "Đơn tăng ca"
    case "extra_work": return "Đơn làm thêm"
    case "business_trip": return "Đơn công tác"
    case "benefits": return "Đơn làm chế độ"
    case "shift_change": return "Đơn đổi ca"
    case "attendance_explain": return "Đơn giải trình chấm công"
    case "comp_leave": return "Đơn nghỉ bù"
    case "attendance_confirm": return "Xác nhận dữ liệu chấm công"
    default: return type.capitalized
    }
}

struct LeaveScreen: View {
    @EnvironmentObject var store: SessionStore
    @State private var items: [LeaveRequest] = []
    @State private var loading = true
    @State private var error: String?

    var body: some View {
        Group {
            if loading && items.isEmpty {
                ProgressView()
            } else if let e = error, items.isEmpty {
                VStack(spacing: 8) {
                    Text(e).foregroundColor(.red).padding()
                    Button("Thử lại") {
                        Task { await loadData() }
                    }
                }
            } else if items.isEmpty {
                VStack(spacing: 12) {
                    Text("Chưa có đơn nghỉ phép nào").foregroundColor(.secondary)
                    NavigationLink(destination: CreateLeaveScreen()) {
                        Label("Tạo đơn mới", systemImage: "plus")
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
                List(items) { lr in
                    VStack(alignment: .leading, spacing: 6) {
                        HStack {
                            Text(leaveTypeTitle(lr.leave_type))
                                .font(.headline)
                            Spacer()
                            let (label, color) = statusLabel(lr.status)
                            Text(label)
                                .font(.caption)
                                .bold()
                                .padding(.horizontal, 8)
                                .padding(.vertical, 3)
                                .background(color.opacity(0.15))
                                .foregroundColor(color)
                                .cornerRadius(8)
                        }
                        Text("Từ \(fmtDate(lr.start_date)) → \(fmtDate(lr.end_date)) (\(String(format: "%g", lr.total_days ?? 1)) ngày)")
                            .font(.subheadline)
                        if let r = lr.reason, !r.isEmpty {
                            Text("Lý do: \(r)")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    .padding(.vertical, 4)
                }
                .listStyle(.insetGrouped)
                .refreshable {
                    await loadData()
                }
            }
        }
        .navigationTitle("Đơn nghỉ phép")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                NavigationLink(destination: CreateLeaveScreen()) {
                    Image(systemName: "plus")
                        .font(.body.weight(.semibold))
                }
            }
        }
        .task {
            await loadData()
        }
        .onAppear {
            Task { await loadData() }
        }
    }

    private func loadData() async {
        guard let emp = store.session.employeeId else {
            loading = false
            return
        }
        do {
            let res = try await SupabaseApi.shared.getLeaveRequests(employeeId: emp)
            await MainActor.run {
                self.items = res
                self.error = nil
                self.loading = false
            }
        } catch {
            await MainActor.run {
                self.error = error.localizedDescription
                self.loading = false
            }
        }
    }
}
