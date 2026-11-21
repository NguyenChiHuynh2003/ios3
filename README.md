# KBA Chấm công (iOS)

Ứng dụng iOS native viết bằng SwiftUI, dùng chung backend Supabase với app Android KBA. Đồng bộ 100% tính năng và giao diện với app Android.

## Yêu cầu & Tương thích thiết bị
- Xcode 13.0 trở lên
- **iOS 15.0+**: Hỗ trợ đầy đủ từ **iPhone 6s, iPhone 7, iPhone 8, iPhone X, iPhone 11, iPhone 12, iPhone 13, iPhone 14, iPhone 15, iPhone 16** (các dòng iPhone 12 trở lên chạy iOS 15/16/17/18 đều tương thích 100%).
- Swift 5.5 (đã tối ưu hoàn toàn cú pháp tương thích iOS 15 và Xcode 13.0+, không bị lỗi `buildIf` của iOS 16).

## Mở dự án
Dự án đã có sẵn `KBAAttendance.xcodeproj` được cấu hình đầy đủ. Sau khi clone, chỉ cần:

```bash
open KBAAttendance.xcodeproj
```

Nhấn Run trong Xcode là build được ngay.

## Cấu hình
- Bundle ID: `vn.kba2018.attendance`
- Supabase URL & anon key được cấu hình trong `KBAAttendance/Config.swift`.

## Các tính năng nổi bật (Đồng bộ với Android)
1. **Logo & Biểu tượng ứng dụng**:
   - Sử dụng logo chuẩn mới KBA 2018 (hình người thể thao cách điệu màu vàng - đỏ kèm chữ số 2018 xanh lá cây).
   - Tự động tạo và cấu hình cả Logo in-app (`Logo.imageset`) và App Icon (`AppIcon.appiconset`, độ phân giải 1024x1024).
2. **Thông báo tin nhắn Realtime & Chuông báo**:
   - **Thông báo cả khi không vào app**: Tích hợp `NotificationManager` sử dụng `UserNotifications` framework. Khi có tin nhắn mới (kể cả khi app đang ở màn hình khác, thu nhỏ dưới nền, hoặc khóa màn hình), iOS sẽ tự động hiển thị Banner thông báo đẩy (Lock Screen & Notification Center) kèm tên người gửi và nội dung tin nhắn.
   - **Âm thanh chuông thông báo**: Tích hợp file âm thanh chuông `message_sound.mp3` qua cả `UNNotificationSound`, `AudioServicesPlayAlertSound` (kênh âm thanh chuông hệ thống) và `AVAudioPlayer` đảm bảo luôn phát chuông và rung máy khi có tin nhắn mới.
   - **Đồng bộ ngầm toàn app (`ChatSyncService`)**: Tự động kiểm tra tin nhắn mới định kỳ, tự động cập nhật số tin chưa đọc lên icon app ngoài màn hình chính (`applicationIconBadgeNumber`) và hiển thị Badge đỏ ngay trên thẻ "Chat nội bộ" ở màn hình chính.
   - **Nhắc nhở chấm công 8:05 sáng**: Tự động đặt lịch thông báo nhắc nhân viên chấm công mỗi sáng.
3. **Chấm công hằng ngày & Lịch sử**:
   - Chấm công vào/ra (hỗ trợ công tác ngoài site, ghi chú).
   - Xem lịch sử chấm công theo tháng hiện tại.
4. **Đơn từ & Nghỉ phép**:
   - Xem danh sách đơn nghỉ phép và trạng thái (Chờ duyệt, Đã duyệt, Từ chối).
   - **Tạo đơn mới (`CreateLeaveScreen`)**: Đầy đủ 10 loại đơn từ (nghỉ phép, vắng mặt, tăng ca, làm thêm, công tác, làm chế độ, đổi ca, giải trình chấm công, nghỉ bù, xác nhận dữ liệu), hỗ trợ 3 hình thức thời gian (cả ngày, nửa ngày, theo giờ), ngày giờ và lý do.
5. **Chat nội bộ (`ChatListScreen`, `ChatRoomScreen`, `NewChatScreen`)**:
   - Danh sách cuộc trò chuyện, hiển thị preview tin nhắn cuối và badge số tin chưa đọc.
   - Trò chuyện 1-1 và tạo nhóm chat nhiều thành viên.
   - Tự động đánh dấu đã đọc khi xem tin nhắn.
6. **Quản lý nhiệm vụ (`TaskListScreen`, `TaskDetailScreen`, `CreateTaskScreen`)**:
   - Danh sách nhiệm vụ theo Tab (*Tất cả / Được giao / Tôi giao*) và Filter trạng thái (*Tất cả, Chờ nhận, Đang làm, Hoàn thành*).
   - Chi tiết nhiệm vụ: xem phân công, cập nhật thanh tiến độ % (0%, 25%, 50%, 75%, 100%), tiếp nhận hoặc từ chối việc.
   - Báo cáo tiến độ & bình luận trực tiếp trong từng nhiệm vụ.
   - Giao việc mới: chỉ định người phụ trách chính, người phối hợp, dự án, mức độ ưu tiên, hạn hoàn thành, chu kỳ lặp lại định kỳ.
7. **Quản lý dự án (`ProjectListScreen`, `ProjectDetailScreen`)**:
   - Phân quyền theo module `projects` (quyền xem và quyền sử dụng chức năng).
   - Danh sách dự án (*Tất cả / Dự án của tôi*) kèm bộ lọc trạng thái.
   - Chi tiết dự án: thông tin tổng quan, ngân sách, vị trí, danh sách dự án con/hạng mục (thêm/xóa dự án con), danh sách thành viên đội ngũ và nhiệm vụ liên quan.
8. **Kho công cụ dụng cụ (`WarehouseStockScreen`)**:
   - Xem tồn kho theo từng kho lưu trữ (`warehouses`) và loại danh mục (Công cụ, Thiết bị, Vật tư).
   - Tìm kiếm nhanh đa năng theo tên, mã SKU, thương hiệu.
   - Thống kê tổng số lượng, số lượng còn hàng và hết hàng.
9. **Kiểm tra CCDC hàng ngày (`ToolCheckScreen`)**:
   - Dành riêng cho nhân sự có quyền `equipment-statistics`.
   - Bảng kiểm tra công cụ, thiết bị theo tuần (Thứ 2 đến Thứ 7), cho phép chuyển tuần trước/tuần sau/về tuần hiện tại.
   - Đánh dấu nhanh trạng thái *Ở KHO* (toggle) hoặc nhập tên *DỰ ÁN* đang sử dụng thiết bị kèm ghi chú và người kiểm tra.
10. **Hướng dẫn sử dụng (`GuideScreen`)**:
    - Hướng dẫn chi tiết tất cả các chức năng trong app.

## Cấu trúc thư mục
```
KBAAttendance/
├── KBAAttendance.xcodeproj/        # Project Xcode native (đã tích hợp đầy đủ file & resources)
├── KBAAttendance/
│   ├── KBAAttendanceApp.swift      # @main entry (khởi động Notification, Reminder & ChatSyncService)
│   ├── Config.swift                # Supabase URL/key
│   ├── SessionStore.swift          # Auth session lưu UserDefaults (kèm quyền module allowed/canEdit)
│   ├── NotificationManager.swift   # Quản lý xin quyền thông báo, hiển thị banner, chuông & nhắc 8:05
│   ├── ChatSyncService.swift       # Dịch vụ đồng bộ tin nhắn ngầm toàn app & cập nhật badge
│   ├── SoundManager.swift          # Quản lý phát âm thanh chuông thông báo & rung
│   ├── message_sound.mp3           # File âm thanh chuông thông báo khi có tin nhắn
│   ├── Info.plist                  # Cấu hình app (bao gồm UIBackgroundModes)
│   ├── Api/
│   │   ├── Models.swift            # Models dữ liệu chấm công, đơn từ, chat, CCDC, Task, Project, ToolCheck
│   │   └── SupabaseApi.swift       # API client Supabase, Chat RPC, Task API, Project API, Warehouse & ToolCheck
│   ├── Screens/
│   │   ├── LoginScreen.swift       # Màn hình đăng nhập & đồng bộ quyền user
│   │   ├── HomeScreen.swift        # Màn hình chính (đầy đủ 8 module & phân quyền hiển thị thẻ)
│   │   ├── LeaveScreen.swift       # Danh sách đơn nghỉ phép
│   │   ├── CreateLeaveScreen.swift # Màn hình tạo đơn nghỉ phép mới
│   │   ├── HistoryScreen.swift     # Lịch sử chấm công
│   │   ├── ChatListScreen.swift    # Danh sách chat nội bộ
│   │   ├── ChatRoomScreen.swift    # Phòng chat & tin nhắn thời gian thực
│   │   ├── NewChatScreen.swift     # Tạo chat 1-1 hoặc nhóm chat mới
│   │   ├── TaskListScreen.swift    # Danh sách quản lý nhiệm vụ (Tabs, Filters, Giao việc)
│   │   ├── TaskDetailScreen.swift  # Chi tiết nhiệm vụ, cập nhật tiến độ, bình luận/báo cáo
│   │   ├── CreateTaskScreen.swift  # Giao nhiệm vụ mới (chọn nhân sự, dự án, định kỳ)
│   │   ├── ProjectListScreen.swift # Danh sách dự án (phân quyền xem/sửa)
│   │   ├── ProjectDetailScreen.swift # Chi tiết dự án, dự án con, thành viên, task dự án
│   │   ├── WarehouseStockScreen.swift # Kho công cụ dụng cụ & tồn kho
│   │   ├── ToolCheckScreen.swift   # Bảng kiểm tra CCDC tuần T2-T7 (ở kho / dự án)
│   │   ├── EquipmentListScreen.swift # Tra cứu danh mục CCDC cũ
│   │   └── GuideScreen.swift       # Hướng dẫn sử dụng
│   └── Assets.xcassets/            # Logo KBA mới, AppIcon 1024x1024, AccentColor
├── project.yml                     # Spec cho XcodeGen (tuỳ chọn)
└── README.md
```
