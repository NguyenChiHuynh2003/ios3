import Foundation

struct AuthUser: Codable { let id: String; let email: String? }

struct AuthResponse: Codable {
    let access_token: String?
    let refresh_token: String?
    let expires_in: Int?
    let user: AuthUser?
    let error: String?
    let error_description: String?
    let msg: String?
}

struct Employee: Codable, Identifiable {
    let id: String
    let full_name: String
    let employee_code: String?
    let position: String?
    let department: String?
    let user_id: String?
    let is_active: Bool?
}

struct AttendanceRecord: Codable, Identifiable {
    var id: String?
    let employee_id: String
    let work_date: String
    var check_in: String?
    var check_out: String?
    var status: String = "present"
    var notes: String?
    var off_site: Bool? = false
}

struct LeaveRequest: Codable, Identifiable {
    let id: String
    let employee_id: String
    let leave_type: String
    let start_date: String
    let end_date: String
    let total_days: Double?
    let reason: String?
    let status: String
    let approved_at: String?
    let created_at: String?
}

struct CreateLeavePayload: Codable {
    let employee_id: String
    let leave_type: String
    let start_date: String
    let end_date: String
    let time_period: String?
    let start_time: String?
    let end_time: String?
    let shift_info: String?
    let reason: String?
    let notes: String?
    let approver_id: String?
    let notification_recipients: [String]?
    let status: String
}

// MARK: - Chat Models

struct ChatMember: Codable {
    let user_id: String
    let full_name: String?
    let last_read_at: String?
}

struct ChatLastMessage: Codable {
    let content: String?
    let attachment_name: String?
    let sender_id: String?
    let created_at: String?
}

struct ChatConversation: Codable, Identifiable {
    let id: String
    var is_group: Bool?
    var name: String?
    var last_message_at: String?
    var created_by: String?
    var members: [ChatMember]?
    var last_message: ChatLastMessage?
    var unread_count: Int?
    var display_name: String?

    // Custom decode to handle numeric unread_count whether Int or Double or 0
    enum CodingKeys: String, CodingKey {
        case id, is_group, name, last_message_at, created_by, members, last_message, unread_count, display_name
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        is_group = try container.decodeIfPresent(Bool.self, forKey: .is_group)
        name = try container.decodeIfPresent(String.self, forKey: .name)
        last_message_at = try container.decodeIfPresent(String.self, forKey: .last_message_at)
        created_by = try container.decodeIfPresent(String.self, forKey: .created_by)
        members = try container.decodeIfPresent([ChatMember].self, forKey: .members)
        last_message = try container.decodeIfPresent(ChatLastMessage.self, forKey: .last_message)
        display_name = try container.decodeIfPresent(String.self, forKey: .display_name)
        
        if let count = try? container.decodeIfPresent(Int.self, forKey: .unread_count) {
            unread_count = count
        } else if let countDouble = try? container.decodeIfPresent(Double.self, forKey: .unread_count) {
            unread_count = Int(countDouble)
        } else {
            unread_count = 0
        }
    }

    func resolvedTitle(myUserId: String) -> String {
        if let d = display_name, !d.trimmingCharacters(in: .whitespaces).isEmpty {
            return d
        }
        if let n = name, !n.trimmingCharacters(in: .whitespaces).isEmpty {
            return n
        }
        if let other = members?.first(where: { $0.user_id != myUserId }), let fn = other.full_name, !fn.isEmpty {
            return fn
        }
        return "Chat"
    }
}

struct ChatMessage: Codable, Identifiable, Equatable {
    let id: String
    let conversation_id: String
    let sender_id: String
    var content: String?
    var attachment_url: String?
    var attachment_name: String?
    var attachment_type: String?
    var created_at: String?
    var edited_at: String?
    var deleted_at: String?
}

struct ProfileLite: Codable, Identifiable {
    let id: String
    let full_name: String?
}

struct ChatSendPayload: Codable {
    let conversation_id: String
    let sender_id: String
    let content: String?
    var attachment_url: String? = nil
    var attachment_name: String? = nil
    var attachment_type: String? = nil
}

// MARK: - Equipment & Tools Models

struct EquipmentItem: Codable, Identifiable {
    let id: String
    let asset_id: String
    let asset_name: String
    var asset_type: String?
    var brand: String?
    var unit: String?
    var stock_quantity: Double?
    var allocated_quantity: Double?
    var warehouse_name: String?
    var physical_status: String?
    var current_status: String?
    var serial_number: String?
    var supplier: String?
    var notes: String?
    var created_at: String?

    enum CodingKeys: String, CodingKey {
        case id, asset_id, asset_name, asset_type, brand, unit
        case stock_quantity, allocated_quantity, warehouse_name
        case physical_status, current_status, serial_number, supplier, notes, created_at
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        asset_id = (try? container.decode(String.self, forKey: .asset_id)) ?? ""
        asset_name = (try? container.decode(String.self, forKey: .asset_name)) ?? ""
        asset_type = try? container.decodeIfPresent(String.self, forKey: .asset_type)
        brand = try? container.decodeIfPresent(String.self, forKey: .brand)
        unit = try? container.decodeIfPresent(String.self, forKey: .unit)
        warehouse_name = try? container.decodeIfPresent(String.self, forKey: .warehouse_name)
        physical_status = try? container.decodeIfPresent(String.self, forKey: .physical_status)
        current_status = try? container.decodeIfPresent(String.self, forKey: .current_status)
        serial_number = try? container.decodeIfPresent(String.self, forKey: .serial_number)
        supplier = try? container.decodeIfPresent(String.self, forKey: .supplier)
        notes = try? container.decodeIfPresent(String.self, forKey: .notes)
        created_at = try? container.decodeIfPresent(String.self, forKey: .created_at)

        if let sq = try? container.decodeIfPresent(Double.self, forKey: .stock_quantity) {
            stock_quantity = sq
        } else if let sqInt = try? container.decodeIfPresent(Int.self, forKey: .stock_quantity) {
            stock_quantity = Double(sqInt)
        } else {
            stock_quantity = 0
        }

        if let aq = try? container.decodeIfPresent(Double.self, forKey: .allocated_quantity) {
            allocated_quantity = aq
        } else if let aqInt = try? container.decodeIfPresent(Int.self, forKey: .allocated_quantity) {
            allocated_quantity = Double(aqInt)
        } else {
            allocated_quantity = 0
        }
    }
}

