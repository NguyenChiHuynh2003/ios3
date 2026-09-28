# KBA Chấm công (iOS)

Ứng dụng iOS native viết bằng SwiftUI, dùng chung backend Supabase với app Android KBA.

## Yêu cầu & Tương thích thiết bị
- Xcode 14.2 trở lên
- **iOS 15.0+**: Hỗ trợ đầy đủ từ **iPhone 6s, iPhone 7, iPhone 8, iPhone X, iPhone 11, iPhone 12, iPhone 13, iPhone 14, iPhone 15, iPhone 16** (các dòng iPhone 12 trở lên chạy iOS 15/16/17/18 đều tương thích 100%).
- Swift 5.7 (đã tối ưu hoàn toàn cú pháp tương thích iOS 15, không bị lỗi `buildIf` của iOS 16).

## Mở dự án
Dự án đã có sẵn `KBAAttendance.xcodeproj` được cấu hình đầy đủ. Sau khi clone, chỉ cần:

```bash
open KBAAttendance.xcodeproj
```

Nhấn Run trong Xcode là build được ngay.

## Cấu hình
- Bundle ID: `vn.kba2018.attendance`
- Supabase URL & anon key được cấu hình trong `KBAAttendance/Config.swift`.

## Các tính năng nổi bật
1. **Logo & Biểu tượng ứng dụng**:
   - Sử dụng logo chuẩn mới KBA 2018 (hình người thể thao cách điệu màu vàng - đỏ kèm chữ số 2018 xanh lá cây).
   - Tự động tạo và cấu hình cả Logo in-app (`Logo.imageset`) và App Icon (`AppIcon.appiconset`, độ phân giải 1024x1024).
2. **Thông báo tin nhắn Realtime & Âm thanh chuông**:
   - **Thông báo cả khi không vào app**: Tích hợp `NotificationManager` sử dụng `UserNotifications` framework. Khi có tin nhắn mới (kể cả khi app đang ở màn hình khác, thu nhỏ dưới nền, hoặc khóa màn hình), iOS sẽ tự động hiển thị Banner thông báo đẩy (Lock Screen & Notification Center) kèm tên người gửi và nội dung tin nhắn.
   - **Âm thanh chuông thông báo**: Tích hợp file âm thanh chuông `message_sound.mp3` qua cả `UNNotificationSound`, `AudioServicesPlayAlertSound` (kênh âm thanh chuông hệ thống) và `AVAudioPlayer` đảm bảo luôn phát chuông và rung máy khi có tin nhắn mới.
   - **Đồng bộ ngầm toàn app (`ChatSyncService`)**: Tự động kiểm tra tin nhắn mới định kỳ, tự động cập nhật số tin chưa đọc lên icon app ngoài màn hình chính (`applicationIconBadgeNumber`) và hiển thị Badge đỏ ngay trên thẻ "Chat nội bộ" ở màn hình chính.
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
6. **Công cụ dụng cụ (`EquipmentListScreen`, `EquipmentDetailView`)**:
   - Xem và tìm kiếm thời gian thực toàn bộ danh mục CCDC, thiết bị, vật tư công ty.
   - Bộ lọc theo danh mục: Tất cả, Công cụ (`tools`), Thiết bị (`equipment`), Vật tư (`materials`).
   - Tìm kiếm nhanh đa năng theo tên, mã CCDC, thương hiệu, kho hoặc số serial.
   - Xem chi tiết từng tài sản: số lượng tồn kho, số lượng đã cấp phát, trạng thái (trong kho, đang sử dụng, bảo dưỡng...), nhà cung cấp, ghi chú.
7. **Hướng dẫn sử dụng (`GuideScreen`)**:
   - Hướng dẫn chi tiết các tính năng đăng nhập, chấm công, tạo đơn, chat nội bộ và tra cứu CCDC.

## Cấu trúc thư mục
```
KBAAttendance/
├── KBAAttendance.xcodeproj/        # Project Xcode native (đã tích hợp đầy đủ file & resources)
├── KBAAttendance/
│   ├── KBAAttendanceApp.swift      # @main entry (khởi động Notification & ChatSyncService)
│   ├── Config.swift                # Supabase URL/key
│   ├── SessionStore.swift          # Auth session lưu UserDefaults
│   ├── NotificationManager.swift   # Quản lý xin quyền thông báo, hiển thị banner & chuông
│   ├── ChatSyncService.swift       # Dịch vụ đồng bộ tin nhắn ngầm toàn app & cập nhật badge
│   ├── SoundManager.swift          # Quản lý phát âm thanh chuông thông báo & rung
│   ├── message_sound.mp3           # File âm thanh chuông thông báo khi có tin nhắn
│   ├── Info.plist                  # Cấu hình app (bao gồm UIBackgroundModes)
│   ├── Api/
│   │   ├── Models.swift            # Models dữ liệu chấm công, đơn từ, chat, CCDC
│   │   └── SupabaseApi.swift       # API client Supabase & Chat RPC & Asset query
│   ├── Screens/
│   │   ├── LoginScreen.swift       # Màn hình đăng nhập
│   │   ├── HomeScreen.swift        # Màn hình chính (có badge tin nhắn chưa đọc)
│   │   ├── LeaveScreen.swift       # Danh sách đơn nghỉ phép
│   │   ├── CreateLeaveScreen.swift # Màn hình tạo đơn nghỉ phép mới
│   │   ├── HistoryScreen.swift     # Lịch sử chấm công
│   │   ├── ChatListScreen.swift    # Danh sách chat nội bộ
│   │   ├── ChatRoomScreen.swift    # Phòng chat & tin nhắn thời gian thực
│   │   ├── NewChatScreen.swift     # Tạo chat 1-1 hoặc nhóm chat mới
│   │   ├── EquipmentListScreen.swift # Màn hình tra cứu & chi tiết CCDC, thiết bị
│   │   └── GuideScreen.swift       # Hướng dẫn sử dụng
│   └── Assets.xcassets/            # Logo KBA mới, AppIcon 1024x1024, AccentColor
├── project.yml                     # Spec cho XcodeGen (tuỳ chọn)
└── README.md
```
