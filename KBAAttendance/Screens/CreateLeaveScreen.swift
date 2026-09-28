import SwiftUI

struct CreateLeaveScreen: View {
    @Environment(\.presentationMode) var presentationMode
    @EnvironmentObject var store: SessionStore

    let leaveTypes = [
        ("leave", "Đơn xin nghỉ"),
        ("absence", "Đơn vắng mặt"),
        ("overtime", "Đơn tăng ca"),
        ("extra_work", "Đơn làm thêm"),
        ("business_trip", "Đơn công tác"),
        ("benefits", "Đơn làm chế độ"),
        ("shift_change", "Đơn đổi ca"),
        ("attendance_explain", "Đơn giải trình chấm công"),
        ("comp_leave", "Đơn nghỉ bù"),
        ("attendance_confirm", "Xác nhận dữ liệu chấm công")
    ]

    @State private var selectedLeaveType = "leave"
    @State private var timePeriodType = "all_day" // all_day, half_day, hourly
    @State private var halfDayPeriod = "morning" // morning, afternoon

    @State private var startDate = Date()
    @State private var endDate = Date()
    @State private var startTime = Calendar.current.date(bySettingHour: 8, minute: 0, second: 0, of: Date()) ?? Date()
    @State private var endTime = Calendar.current.date(bySettingHour: 17, minute: 0, second: 0, of: Date()) ?? Date()

    @State private var reason = ""
    @State private var notes = ""

    @State private var isSubmitting = false
    @State private var errorMessage: String?
    @State private var showSuccessAlert = false

    private let dateAPIFormatter: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.dateFormat = "yyyy-MM-dd"
        return f
    }()

    private let timeAPIFormatter: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.dateFormat = "HH:mm"
        return f
    }()

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                // Leave type picker
                VStack(alignment: .leading, spacing: 6) {
                    Text("Loại đơn từ *")
                        .font(.subheadline)
                        .foregroundColor(.secondary)

                    Menu {
                        ForEach(leaveTypes, id: \.0) { item in
                            Button(action: {
                                selectedLeaveType = item.0
                            }) {
                                HStack {
                                    Text(item.1)
                                    if selectedLeaveType == item.0 {
                                        Image(systemName: "checkmark")
                                    }
                                }
                            }
                        }
                    } label: {
                        HStack {
                            let title = leaveTypes.first(where: { $0.0 == selectedLeaveType })?.1 ?? "Chọn loại đơn"
                            Text(title)
                                .foregroundColor(.primary)
                            Spacer()
                            Image(systemName: "chevron.down")
                                .foregroundColor(.secondary)
                        }
                        .padding()
                        .background(Color(.secondarySystemBackground))
                        .cornerRadius(10)
                        .overlay(
                            RoundedRectangle(cornerRadius: 10)
                                .stroke(Color(.separator), lineWidth: 1)
                        )
                    }
                }

                // Time period type selection
                VStack(alignment: .leading, spacing: 8) {
                    Text("Hình thức thời gian *")
                        .font(.subheadline)
                        .foregroundColor(.secondary)

                    HStack(spacing: 8) {
                        periodChip(title: "Cả ngày", value: "all_day")
                        periodChip(title: "Nửa ngày", value: "half_day")
                        periodChip(title: "Theo giờ", value: "hourly")
                    }
                }

                // Date & Time pickers
                VStack(alignment: .leading, spacing: 12) {
                    if timePeriodType == "all_day" {
                        DatePicker("Từ ngày", selection: $startDate, displayedComponents: .date)
                            .datePickerStyle(.compact)
                            .environment(\.locale, Locale(identifier: "vi_VN"))
                            .onChange(of: startDate) { newDate in
                                if endDate < newDate { endDate = newDate }
                            }

                        DatePicker("Đến ngày", selection: $endDate, in: startDate..., displayedComponents: .date)
                            .datePickerStyle(.compact)
                            .environment(\.locale, Locale(identifier: "vi_VN"))
                    } else if timePeriodType == "half_day" {
                        DatePicker("Chọn ngày", selection: $startDate, displayedComponents: .date)
                            .datePickerStyle(.compact)
                            .environment(\.locale, Locale(identifier: "vi_VN"))

                        HStack(spacing: 24) {
                            Button(action: { halfDayPeriod = "morning" }) {
                                HStack(spacing: 6) {
                                    Image(systemName: halfDayPeriod == "morning" ? "largecircle.fill.circle" : "circle")
                                        .foregroundColor(Color(red: 0.07, green: 0.45, blue: 0.20))
                                    Text("Buổi sáng")
                                        .foregroundColor(.primary)
                                }
                            }
                            Button(action: { halfDayPeriod = "afternoon" }) {
                                HStack(spacing: 6) {
                                    Image(systemName: halfDayPeriod == "afternoon" ? "largecircle.fill.circle" : "circle")
                                        .foregroundColor(Color(red: 0.07, green: 0.45, blue: 0.20))
                                    Text("Buổi chiều")
                                        .foregroundColor(.primary)
                                }
                            }
                        }
                        .padding(.top, 4)
                    } else if timePeriodType == "hourly" {
                        DatePicker("Chọn ngày", selection: $startDate, displayedComponents: .date)
                            .datePickerStyle(.compact)
                            .environment(\.locale, Locale(identifier: "vi_VN"))

                        HStack(spacing: 12) {
                            DatePicker("Từ giờ", selection: $startTime, displayedComponents: .hourAndMinute)
                                .datePickerStyle(.compact)
                            DatePicker("Đến giờ", selection: $endTime, displayedComponents: .hourAndMinute)
                                .datePickerStyle(.compact)
                        }
                    }
                }
                .padding()
                .background(Color(.secondarySystemBackground))
                .cornerRadius(12)

                // Reason input
                VStack(alignment: .leading, spacing: 6) {
                    Text("Lý do cụ thể *")
                        .font(.subheadline)
                        .foregroundColor(.secondary)

                    TextField("Nhập lý do thực hiện đơn...", text: $reason)
                        .textFieldStyle(.roundedBorder)
                }

                // Notes input
                VStack(alignment: .leading, spacing: 6) {
                    Text("Ghi chú bổ sung (Nếu có)")
                        .font(.subheadline)
                        .foregroundColor(.secondary)

                    TextField("Nhập ghi chú thêm nếu cần", text: $notes)
                        .textFieldStyle(.roundedBorder)
                }

                if let err = errorMessage {
                    Text(err)
                        .font(.caption)
                        .foregroundColor(.red)
                }

                Spacer(minLength: 16)

                // Submit button
                Button(action: submitLeave) {
                    HStack {
                        if isSubmitting {
                            ProgressView()
                                .tint(.white)
                                .padding(.trailing, 4)
                        }
                        Text("Gửi đơn")
                            .font(.headline)
                            .foregroundColor(.white)
                    }
                    .frame(maxWidth: .infinity, minHeight: 48)
                    .background(Color(red: 0.07, green: 0.45, blue: 0.20))
                    .cornerRadius(12)
                }
                .disabled(isSubmitting)
            }
            .padding()
        }
        .navigationTitle("Tạo đơn nghỉ phép")
        .navigationBarTitleDisplayMode(.inline)
        .alert(isPresented: $showSuccessAlert) {
            Alert(
                title: Text("Thành công"),
                message: Text("Đã gửi đơn nghỉ phép thành công!"),
                dismissButton: .default(Text("Đóng")) {
                    presentationMode.wrappedValue.dismiss()
                }
            )
        }
    }

    private func periodChip(title: String, value: String) -> some View {
        let isSelected = timePeriodType == value
        return Button(action: {
            timePeriodType = value
            endDate = startDate
        }) {
            Text(title)
                .font(.subheadline)
                .fontWeight(isSelected ? .semibold : .regular)
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .background(isSelected ? Color(red: 0.07, green: 0.45, blue: 0.20).opacity(0.15) : Color(.secondarySystemBackground))
                .foregroundColor(isSelected ? Color(red: 0.07, green: 0.45, blue: 0.20) : .primary)
                .cornerRadius(20)
                .overlay(
                    RoundedRectangle(cornerRadius: 20)
                        .stroke(isSelected ? Color(red: 0.07, green: 0.45, blue: 0.20) : Color.clear, lineWidth: 1.5)
                )
        }
    }

    private func submitLeave() {
        guard let empId = store.session.employeeId, !empId.isEmpty else {
            errorMessage = "Phiên đăng nhập không hợp lệ"
            return
        }

        let cleanReason = reason.trimmingCharacters(in: .whitespacesAndNewlines)
        if cleanReason.isEmpty {
            errorMessage = "Vui lòng nhập lý do đơn từ"
            return
        }

        errorMessage = nil
        isSubmitting = true

        let sDateStr = dateAPIFormatter.string(from: startDate)
        let eDateStr = (timePeriodType == "all_day") ? dateAPIFormatter.string(from: endDate) : sDateStr

        let finalPeriod: String?
        switch timePeriodType {
        case "all_day": finalPeriod = "all_day"
        case "half_day": finalPeriod = halfDayPeriod
        default: finalPeriod = nil
        }

        let sTimeStr = (timePeriodType == "hourly") ? timeAPIFormatter.string(from: startTime) : nil
        let eTimeStr = (timePeriodType == "hourly") ? timeAPIFormatter.string(from: endTime) : nil
        let cleanNotes = notes.trimmingCharacters(in: .whitespacesAndNewlines)

        let payload = CreateLeavePayload(
            employee_id: empId,
            leave_type: selectedLeaveType,
            start_date: sDateStr,
            end_date: eDateStr,
            time_period: finalPeriod,
            start_time: sTimeStr,
            end_time: eTimeStr,
            shift_info: nil,
            reason: cleanReason,
            notes: cleanNotes.isEmpty ? nil : cleanNotes,
            approver_id: nil,
            notification_recipients: nil,
            status: "pending"
        )

        Task {
            do {
                try await SupabaseApi.shared.createLeaveRequest(payload: payload)
                await MainActor.run {
                    isSubmitting = false
                    showSuccessAlert = true
                }
            } catch {
                await MainActor.run {
                    isSubmitting = false
                    errorMessage = "Gửi đơn thất bại: \(error.localizedDescription)"
                }
            }
        }
    }
}
