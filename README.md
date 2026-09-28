# KBA Chấm công (iOS)

Ứng dụng iOS native viết bằng SwiftUI, dùng chung backend Supabase với app Android KBA.

## Yêu cầu & Tương thích thiết bị
- Xcode 14.2 trở lên
- **iOS 15.0+**: Hỗ trợ đầy đủ từ **iPhone 6s, iPhone 7, iPhone 8, iPhone X, iPhone 11, iPhone 12, iPhone 13, iPhone 14, iPhone 15, iPhone 16** (các dòng iPhone 12 trở lên chạy iOS 15/16/17/18 đều tương thích 100%).
- *Lưu ý về iOS 12*: Apple bắt đầu phát hành SwiftUI từ iOS 13 trở lên (các tính năng Swift Concurrency async/await và @main App hiện đại cần tối thiểu iOS 14-15), do đó các máy quá cũ không thể nâng cấp lên iOS 13+ (như iPhone 6 ra mắt 2014 kẹt ở iOS 12.5) sẽ không thể chạy ứng dụng SwiftUI. Tuy nhiên tất cả các dòng từ iPhone 6s và đặc biệt **iPhone 12** đều được hỗ trợ tối đa.
- Swift 5.7

## Mở dự án
Dự án đã có sẵn `KBAAttendance.xcodeproj` được cấu hình đầy đủ. Sau khi clone, chỉ cần:

```bash
open KBAAttendance.xcodeproj
```

Không cần cài `xcodegen` hay chạy bất kỳ lệnh sinh project nào. Nhấn Run trong Xcode 14.2 trở lên là build được ngay.

## Cấu hình
- Bundle ID: `vn.kba2018.attendance`
- Supabase URL & anon key được cấu hình trong `KBAAttendance/Config.swift`.

## Các tính năng đã xây dựng đồng bộ với Android
1. **Chấm công hằng ngày & Lịch sử**:
   - Chấm công vào/ra (hỗ trợ công tác ngoài site, ghi chú).
   - Xem lịch sử chấm công theo tháng hiện tại.
2. **Đơn từ & Nghỉ phép**:
   - Xem danh sách đơn nghỉ phép và trạng thái (Chờ duyệt, Đã duyệt, Từ chối).
   - **Tạo đơn mới (`CreateLeaveScreen`)**: Đầy đủ 10 loại đơn từ (nghỉ phép, vắng mặt, tăng ca, làm thêm, công tác, làm chế độ, đổi ca, giải trình chấm công, nghỉ bù, xác nhận dữ liệu), hỗ trợ 3 hình thức thời gian (cả ngày, nửa ngày, theo giờ), ngày giờ và lý do.
3. **Chat nội bộ (`ChatListScreen`, `ChatRoomScreen`, `NewChatScreen`)**:
   - Danh sách cuộc trò chuyện, hiển thị preview tin nhắn cuối và badge số tin chưa đọc.
   - Trò chuyện 1-1 và tạo nhóm chat nhiều thành viên.
   - Cập nhật tin nhắn theo thời gian thực (polling 2.5s) và đánh dấu đã đọc.
   - **Âm thanh thông báo chuông (`SoundManager`)**: Phát file âm thanh `message_sound.mp3` kèm rung khi có tin nhắn mới gửi đến.
4. **Công cụ dụng cụ (`EquipmentListScreen`, `EquipmentDetailView`)**:
   - Xem và tìm kiếm thời gian thực toàn bộ danh mục CCDC, thiết bị, vật tư công ty.
   - Bộ lọc theo danh mục: Tất cả, Công cụ (`tools`), Thiết bị (`equipment`), Vật tư (`materials`).
   - Tìm kiếm nhanh đa năng theo tên, mã CCDC, thương hiệu, kho hoặc số serial.
   - Xem chi tiết từng tài sản: số lượng tồn kho, số lượng đã cấp phát, trạng thái (trong kho, đang sử dụng, bảo dưỡng...), nhà cung cấp, ghi chú.
5. **Hướng dẫn sử dụng (`GuideScreen`)**:
   - Hướng dẫn chi tiết các tính năng đăng nhập, chấm công, tạo đơn, chat nội bộ và tra cứu CCDC.

## Cấu trúc thư mục
```
KBAAttendance/
├── KBAAttendance.xcodeproj/        # Project Xcode native (đã tích hợp đầy đủ file & resources)
├── KBAAttendance/
│   ├── KBAAttendanceApp.swift      # @main entry
│   ├── Config.swift                # Supabase URL/key
│   ├── SessionStore.swift          # Auth session lưu UserDefaults
│   ├── SoundManager.swift          # Quản lý phát âm thanh chuông thông báo & rung
│   ├── message_sound.mp3           # File âm thanh chuông thông báo khi có tin nhắn
│   ├── Info.plist                  # Cấu hình app
│   ├── Api/
│   │   ├── Models.swift            # Models dữ liệu chấm công, đơn từ, chat, CCDC
│   │   └── SupabaseApi.swift       # API client Supabase & Chat RPC & Asset query
│   ├── Screens/
│   │   ├── LoginScreen.swift       # Màn hình đăng nhập
│   │   ├── HomeScreen.swift        # Màn hình chính
│   │   ├── LeaveScreen.swift       # Danh sách đơn nghỉ phép
│   │   ├── CreateLeaveScreen.swift # Màn hình tạo đơn nghỉ phép mới
│   │   ├── HistoryScreen.swift     # Lịch sử chấm công
│   │   ├── ChatListScreen.swift    # Danh sách chat nội bộ
│   │   ├── ChatRoomScreen.swift    # Phòng chat & tin nhắn thời gian thực
│   │   ├── NewChatScreen.swift     # Tạo chat 1-1 hoặc nhóm chat mới
│   │   ├── EquipmentListScreen.swift # Màn hình tra cứu & chi tiết CCDC, thiết bị
│   │   └── GuideScreen.swift       # Hướng dẫn sử dụng
│   └── Assets.xcassets/            # Logo KBA, AppIcon, AccentColor
├── project.yml                     # Spec cho XcodeGen (tuỳ chọn)
└── README.md
```
