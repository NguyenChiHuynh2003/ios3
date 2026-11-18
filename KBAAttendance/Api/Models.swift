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


// MARK: - User Permissions

struct UserPermissionsResult: Codable {
    var allowed_modules: [String] = []
    var can_edit_modules: [String] = []
}

// MARK: - Warehouse Models

struct Warehouse: Codable, Identifiable {
    let id: String
    let name: String
    var description: String?
    var is_active: Bool? = true
}

struct AssetMasterInfo: Codable, Identifiable {
    var id: String?
    var asset_id: String?
    var sku: String?
    var asset_name: String?
    var unit: String?
    var asset_type: String?
    var brand: String?
    var stock_quantity: Double?
    var notes: String?
}

struct WarehouseStockItem: Codable, Identifiable {
    let id: String
    let warehouse_name: String
    var quantity: Double = 0.0
    var asset: AssetMasterInfo?

    enum CodingKeys: String, CodingKey {
        case id, warehouse_name, quantity, asset
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        warehouse_name = try container.decode(String.self, forKey: .warehouse_name)
        asset = try? container.decodeIfPresent(AssetMasterInfo.self, forKey: .asset)
        if let q = try? container.decodeIfPresent(Double.self, forKey: .quantity) {
            quantity = q
        } else if let qInt = try? container.decodeIfPresent(Int.self, forKey: .quantity) {
            quantity = Double(qInt)
        } else {
            quantity = 0.0
        }
    }
}

// MARK: - Tool Check Models

struct ToolCheckItem: Codable, Identifiable {
    let id: String
    var code: String?
    let name: String
    var note: String?
    var sort_order: Int? = 0
    var created_at: String?
}

struct ToolCheckEntry: Codable, Identifiable {
    var id: String?
    let item_id: String
    let check_date: String
    var in_warehouse: Bool = false
    var project_name: String?
    var note: String?
    var inspector: String?
}

struct ToolCheckEntryUpsert: Codable {
    let item_id: String
    let check_date: String
    let in_warehouse: Bool
    var project_name: String?
    var note: String?
    var inspector: String?
}

// MARK: - Project Models

struct Project: Codable, Identifiable {
    let id: String
    var name: String
    var description: String?
    var location: String?
    var status: String?
    var start_date: String?
    var end_date: String?
    var budget: String?
    var priority: String?
    var project_kind: String?
    var created_by: String?
    var created_at: String?
    var parent_id: String?

    enum CodingKeys: String, CodingKey {
        case id, name, description, location, status, start_date, end_date
        case budget, priority, project_kind, created_by, created_at, parent_id
    }

    init(id: String, name: String, description: String? = nil, location: String? = nil, status: String? = nil, start_date: String? = nil, end_date: String? = nil, budget: String? = nil, priority: String? = nil, project_kind: String? = nil, created_by: String? = nil, created_at: String? = nil, parent_id: String? = nil) {
        self.id = id
        self.name = name
        self.description = description
        self.location = location
        self.status = status
        self.start_date = start_date
        self.end_date = end_date
        self.budget = budget
        self.priority = priority
        self.project_kind = project_kind
        self.created_by = created_by
        self.created_at = created_at
        self.parent_id = parent_id
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        name = (try? container.decode(String.self, forKey: .name)) ?? ""
        description = try? container.decodeIfPresent(String.self, forKey: .description)
        location = try? container.decodeIfPresent(String.self, forKey: .location)
        status = try? container.decodeIfPresent(String.self, forKey: .status)
        start_date = try? container.decodeIfPresent(String.self, forKey: .start_date)
        end_date = try? container.decodeIfPresent(String.self, forKey: .end_date)
        priority = try? container.decodeIfPresent(String.self, forKey: .priority)
        project_kind = try? container.decodeIfPresent(String.self, forKey: .project_kind)
        created_by = try? container.decodeIfPresent(String.self, forKey: .created_by)
        created_at = try? container.decodeIfPresent(String.self, forKey: .created_at)
        parent_id = try? container.decodeIfPresent(String.self, forKey: .parent_id)

        if let bStr = try? container.decodeIfPresent(String.self, forKey: .budget) {
            budget = bStr
        } else if let bDouble = try? container.decodeIfPresent(Double.self, forKey: .budget) {
            budget = String(bDouble)
        } else if let bInt = try? container.decodeIfPresent(Int.self, forKey: .budget) {
            budget = String(bInt)
        } else {
            budget = nil
        }
    }
}

struct ProjectTeamMember: Codable, Identifiable {
    var id: String?
    let project_id: String
    var user_id: String?
    var role: String?
    var manual_name: String?
    var position: String?
    var department: String?
    var joined_at: String?
}

// MARK: - Task Models

struct HrTask: Codable, Identifiable {
    let id: String
    var title: String
    var description: String?
    var category: String?
    var assigned_to: String?
    var progress: Int = 0
    var status: String = "pending"
    var priority: String = "medium"
    var created_date: String?
    var due_date: String?
    var notes: String?
    let created_by: String
    var created_at: String?
    var updated_at: String?
    var project_name: String?
    var project_id: String?
    var acceptance_status: String?
    var acceptance_note: String?
    var acceptance_responded_at: String?

    enum CodingKeys: String, CodingKey {
        case id, title, description, category, assigned_to, progress, status, priority
        case created_date, due_date, notes, created_by, created_at, updated_at
        case project_name, project_id, acceptance_status, acceptance_note, acceptance_responded_at
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        title = (try? container.decode(String.self, forKey: .title)) ?? ""
        description = try? container.decodeIfPresent(String.self, forKey: .description)
        category = try? container.decodeIfPresent(String.self, forKey: .category)
        assigned_to = try? container.decodeIfPresent(String.self, forKey: .assigned_to)
        status = (try? container.decodeIfPresent(String.self, forKey: .status)) ?? "pending"
        priority = (try? container.decodeIfPresent(String.self, forKey: .priority)) ?? "medium"
        created_date = try? container.decodeIfPresent(String.self, forKey: .created_date)
        due_date = try? container.decodeIfPresent(String.self, forKey: .due_date)
        notes = try? container.decodeIfPresent(String.self, forKey: .notes)
        created_by = (try? container.decode(String.self, forKey: .created_by)) ?? ""
        created_at = try? container.decodeIfPresent(String.self, forKey: .created_at)
        updated_at = try? container.decodeIfPresent(String.self, forKey: .updated_at)
        project_name = try? container.decodeIfPresent(String.self, forKey: .project_name)
        project_id = try? container.decodeIfPresent(String.self, forKey: .project_id)
        acceptance_status = try? container.decodeIfPresent(String.self, forKey: .acceptance_status)
        acceptance_note = try? container.decodeIfPresent(String.self, forKey: .acceptance_note)
        acceptance_responded_at = try? container.decodeIfPresent(String.self, forKey: .acceptance_responded_at)

        if let pInt = try? container.decodeIfPresent(Int.self, forKey: .progress) {
            progress = pInt
        } else if let pDouble = try? container.decodeIfPresent(Double.self, forKey: .progress) {
            progress = Int(pDouble)
        } else {
            progress = 0
        }
    }
}

struct HrTaskAssignee: Codable, Identifiable {
    var id: String?
    let task_id: String
    var employee_id: String?
    var user_id: String?
    var role: String // "owner" or "collaborator"
    var acceptance_status: String?
    var acceptance_note: String?
    var acceptance_responded_at: String?
}

struct HrTaskReport: Codable, Identifiable {
    var id: String?
    let task_id: String
    let user_id: String
    var reporter_name: String?
    let content: String
    var created_at: String?
}

struct TaskRecurrence: Codable {
    var freq: String = "weekly" // "daily", "weekly", "monthly"
    var weekday: Int = 1 // 1: Monday, 2: Tuesday ...
}

struct CreateTaskPayload: Codable {
    let title: String
    var description: String?
    var project_id: String?
    var project_name: String?
    var priority: String = "medium"
    var due_date: String?
    var assigned_to: String?
    let created_by: String
    var status: String = "awaiting_acceptance"
    var progress: Int = 0
    let created_date: String
    var recurrence: TaskRecurrence?
    var notes: String?
}

struct CreateAssigneePayload: Codable {
    let task_id: String
    var employee_id: String?
    var user_id: String?
    let role: String // "owner" or "collaborator"
    var acceptance_status: String?
}

struct CreateReportPayload: Codable {
    let task_id: String
    let user_id: String
    var reporter_name: String?
    let content: String
}
