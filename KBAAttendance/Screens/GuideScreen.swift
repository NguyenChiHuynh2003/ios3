import SwiftUI

struct GuideScreen: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                section("1. Đăng nhập",
                        "• Mở app KBA Chấm công.\n• Nhập Email và Mật khẩu của tài khoản nội bộ kba2018.vn.\n• Bấm \"Đăng nhập\". Nếu quên mật khẩu, liên hệ Quản trị viên (Admin) để được cấp lại.")
                section("2. Chấm công hằng ngày",
                        "• Sau khi đăng nhập, bạn sẽ thấy thẻ \"Chấm công hôm nay\".\n• (Tuỳ chọn) Bật \"Đi công tác (ngoài site)\" nếu làm việc ngoài văn phòng.\n• (Tuỳ chọn) Nhập ghi chú nếu cần.\n• Bấm \"Chấm công\": Giờ vào lấy theo thời điểm bấm, giờ ra mặc định 17:00.\n• Mỗi ngày chỉ chấm công 1 lần.")
                section("3. Đơn nghỉ phép",
                        "• Bấm \"Đơn nghỉ phép\" trên màn hình chính.\n• Xem danh sách đơn và trạng thái duyệt (Chờ duyệt, Đã duyệt, Từ chối).\n• Bấm nút \"+\" ở góc trên bên phải để tạo đơn nghỉ phép mới (chọn loại đơn, hình thức cả ngày/nửa ngày/theo giờ, ngày giờ và lý do).")
                section("4. Chat nội bộ",
                        "• Bấm \"Chat nội bộ\" để trò chuyện với đồng nghiệp hoặc tạo nhóm chat công việc.\n• Nhận thông báo âm thanh chuông khi có tin nhắn mới theo thời gian thực.")
                section("5. Công cụ dụng cụ",
                        "• Bấm \"Công cụ dụng cụ\" để tra cứu danh mục CCDC, thiết bị, vật tư.\n• Tìm kiếm tức thời theo tên, mã CCDC, thương hiệu, vị trí kho hoặc số serial.\n• Lọc nhanh theo phân loại: Công cụ, Thiết bị, Vật tư.\n• Xem chi tiết số lượng tồn kho khả dụng, số lượng đang cấp phát và trạng thái bảo dưỡng.")
                section("6. Lịch sử chấm công",
                        "• Bấm \"Lịch sử chấm công\" để xem các bản ghi chấm công của tháng hiện tại.\n• Dữ liệu đồng bộ theo thời gian thực với hệ thống.")
                section("7. Đăng xuất",
                        "• Bấm icon đăng xuất ở góc trên bên phải màn hình chính.")
                section("8. Hỗ trợ",
                        "• Website nội bộ: https://kba2018.vn/noi-bo\n• Mọi vấn đề về tài khoản, dữ liệu chấm công: liên hệ phòng HR.\n• Lỗi kỹ thuật: liên hệ bộ phận IT của công ty.")
            }
            .padding()
        }
        .navigationTitle("Hướng dẫn sử dụng")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func section(_ title: String, _ body: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title).font(.headline).foregroundColor(Color(red: 0.07, green: 0.45, blue: 0.20))
            Text(body).font(.subheadline).foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(Color(.secondarySystemBackground))
        .cornerRadius(10)
    }
}
