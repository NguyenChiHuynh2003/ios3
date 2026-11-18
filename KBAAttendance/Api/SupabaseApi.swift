import Foundation

enum SupabaseError: Error, LocalizedError {
    case authExpired
    case http(Int, String)
    case decode(String)
    var errorDescription: String? {
        switch self {
        case .authExpired: return "Phiên đăng nhập đã hết hạn, vui lòng đăng nhập lại"
        case .http(let c, let b): return "HTTP \(c): \(b.prefix(200))"
        case .decode(let m): return "Decode error: \(m)"
        }
    }
}

actor SupabaseApi {
    static let shared = SupabaseApi()

    private(set) var currentToken: String?
    private(set) var currentRefreshToken: String?
    var onTokensRefreshed: ((String, String?) async -> Void)?
    var onAuthExpired: (() async -> Void)?

    func setTokens(token: String?, refresh: String?) {
        self.currentToken = token
        self.currentRefreshToken = refresh
    }
    func setOnTokensRefreshed(_ cb: @escaping (String, String?) async -> Void) { self.onTokensRefreshed = cb }
    func setOnAuthExpired(_ cb: @escaping () async -> Void) { self.onAuthExpired = cb }

    private let session: URLSession = {
        let c = URLSessionConfiguration.default
        c.timeoutIntervalForRequest = 20
        c.timeoutIntervalForResource = 20
        return URLSession(configuration: c)
    }()

    private let decoder: JSONDecoder = { let d = JSONDecoder(); return d }()
    private let encoder: JSONEncoder = { let e = JSONEncoder(); return e }()

    private func headers(token: String?) -> [String: String] {
        [
            "apikey": Config.supabaseAnonKey,
            "Authorization": "Bearer \(token ?? Config.supabaseAnonKey)",
            "Content-Type": "application/json"
        ]
    }

    private func makeRequest(_ url: URL, method: String, token: String?, body: Data? = nil, prefer: String? = nil) -> URLRequest {
        var r = URLRequest(url: url)
        r.httpMethod = method
        for (k, v) in headers(token: token) { r.setValue(v, forHTTPHeaderField: k) }
        if let p = prefer { r.setValue(p, forHTTPHeaderField: "Prefer") }
        r.httpBody = body
        return r
    }

    private func refreshAccessToken() async -> String? {
        guard let rt = currentRefreshToken, !rt.isEmpty else { return nil }
        let url = URL(string: "\(Config.supabaseURL)/auth/v1/token?grant_type=refresh_token")!
        let body = try? JSONSerialization.data(withJSONObject: ["refresh_token": rt])
        let req = makeRequest(url, method: "POST", token: nil, body: body)
        do {
            let (data, resp) = try await session.data(for: req)
            guard let http = resp as? HTTPURLResponse, (200..<300).contains(http.statusCode) else { return nil }
            let auth = try decoder.decode(AuthResponse.self, from: data)
            guard let newAccess = auth.access_token else { return nil }
            currentToken = newAccess
            if let nr = auth.refresh_token, !nr.isEmpty { currentRefreshToken = nr }
            await onTokensRefreshed?(newAccess, auth.refresh_token)
            return newAccess
        } catch { return nil }
    }

    private func executeAuthed(makeReq: (String) -> URLRequest) async throws -> (Data, HTTPURLResponse) {
        guard let t = currentToken else { throw SupabaseError.authExpired }
        var (data, resp) = try await session.data(for: makeReq(t))
        var http = resp as! HTTPURLResponse
        if http.statusCode == 401 || http.statusCode == 403 {
            guard let nt = await refreshAccessToken() else {
                await onAuthExpired?()
                throw SupabaseError.authExpired
            }
            (data, resp) = try await session.data(for: makeReq(nt))
            http = resp as! HTTPURLResponse
            if http.statusCode == 401 || http.statusCode == 403 {
                await onAuthExpired?()
                throw SupabaseError.authExpired
            }
        }
        return (data, http)
    }

    // MARK: - Auth
    func signIn(email: String, password: String) async throws -> AuthResponse {
        let url = URL(string: "\(Config.supabaseURL)/auth/v1/token?grant_type=password")!
        let body = try JSONSerialization.data(withJSONObject: ["email": email, "password": password])
        let req = makeRequest(url, method: "POST", token: nil, body: body)
        let (data, _) = try await session.data(for: req)
        return try decoder.decode(AuthResponse.self, from: data)
    }

    func getMyEmployee(userId: String) async throws -> Employee? {
        let urlStr = "\(Config.supabaseURL)/rest/v1/employees?user_id=eq.\(userId)&select=id,full_name,employee_code,position,department,user_id,is_active&limit=1"
        let url = URL(string: urlStr)!
        let (data, http) = try await executeAuthed { t in self.makeRequest(url, method: "GET", token: t) }
        guard (200..<300).contains(http.statusCode) else { return nil }
        return (try? decoder.decode([Employee].self, from: data))?.first
    }

    func getTodayAttendance(employeeId: String, date: String) async throws -> AttendanceRecord? {
        let urlStr = "\(Config.supabaseURL)/rest/v1/attendance_records?employee_id=eq.\(employeeId)&work_date=eq.\(date)&select=*&limit=1"
        let url = URL(string: urlStr)!
        let (data, http) = try await executeAuthed { t in self.makeRequest(url, method: "GET", token: t) }
        guard (200..<300).contains(http.statusCode) else { return nil }
        return (try? decoder.decode([AttendanceRecord].self, from: data))?.first
    }

    func checkIn(record: AttendanceRecord) async throws {
        let url = URL(string: "\(Config.supabaseURL)/rest/v1/attendance_records")!
        let body = try encoder.encode(record)
        let (data, http) = try await executeAuthed { t in
            self.makeRequest(url, method: "POST", token: t, body: body, prefer: "return=minimal")
        }
        if !(200..<300).contains(http.statusCode) {
            throw SupabaseError.http(http.statusCode, String(data: data, encoding: .utf8) ?? "")
        }
    }

    func updateCheckOut(recordId: String, checkOut: String) async throws {
        let url = URL(string: "\(Config.supabaseURL)/rest/v1/attendance_records?id=eq.\(recordId)")!
        let body = try JSONSerialization.data(withJSONObject: ["check_out": checkOut])
        _ = try await executeAuthed { t in
            self.makeRequest(url, method: "PATCH", token: t, body: body, prefer: "return=minimal")
        }
    }

    func getLeaveRequests(employeeId: String) async throws -> [LeaveRequest] {
        let urlStr = "\(Config.supabaseURL)/rest/v1/leave_requests?employee_id=eq.\(employeeId)&select=*&order=created_at.desc&limit=50"
        let url = URL(string: urlStr)!
        let (data, http) = try await executeAuthed { t in self.makeRequest(url, method: "GET", token: t) }
        guard (200..<300).contains(http.statusCode) else { return [] }
        return (try? decoder.decode([LeaveRequest].self, from: data)) ?? []
    }

    func getAttendanceMonth(employeeId: String, from: String, to: String) async throws -> [AttendanceRecord] {
        let urlStr = "\(Config.supabaseURL)/rest/v1/attendance_records?employee_id=eq.\(employeeId)&work_date=gte.\(from)&work_date=lte.\(to)&select=*&order=work_date.desc"
        let url = URL(string: urlStr)!
        let (data, http) = try await executeAuthed { t in self.makeRequest(url, method: "GET", token: t) }
        guard (200..<300).contains(http.statusCode) else { return [] }
        return (try? decoder.decode([AttendanceRecord].self, from: data)) ?? []
    }

    // MARK: - Leave Requests
    func createLeaveRequest(payload: CreateLeavePayload) async throws {
        let url = URL(string: "\(Config.supabaseURL)/rest/v1/leave_requests")!
        let body = try encoder.encode(payload)
        let (data, http) = try await executeAuthed { t in
            self.makeRequest(url, method: "POST", token: t, body: body, prefer: "return=minimal")
        }
        guard (200..<300).contains(http.statusCode) else {
            let errStr = String(data: data, encoding: .utf8) ?? ""
            throw SupabaseError.http(http.statusCode, "Lỗi tạo đơn: \(errStr)")
        }
    }

    // MARK: - Chat APIs
    func getConversations() async throws -> [ChatConversation] {
        let url = URL(string: "\(Config.supabaseURL)/rest/v1/rpc/chat_get_conversations")!
        let body = "{}".data(using: .utf8)
        let (data, http) = try await executeAuthed { t in
            self.makeRequest(url, method: "POST", token: t, body: body)
        }
        guard (200..<300).contains(http.statusCode) else { return [] }
        return (try? decoder.decode([ChatConversation].self, from: data)) ?? []
    }

    func createDirect(otherUserId: String) async throws -> String? {
        let url = URL(string: "\(Config.supabaseURL)/rest/v1/rpc/chat_create_direct")!
        let body = try JSONSerialization.data(withJSONObject: ["p_other": otherUserId])
        let (data, http) = try await executeAuthed { t in
            self.makeRequest(url, method: "POST", token: t, body: body)
        }
        guard (200..<300).contains(http.statusCode) else { return nil }
        if let str = String(data: data, encoding: .utf8)?.trimmingCharacters(in: CharacterSet(charactersIn: "\"\n\r ")) {
            return str.isEmpty ? nil : str
        }
        return nil
    }

    func createGroup(name: String, members: [String]) async throws -> String? {
        let url = URL(string: "\(Config.supabaseURL)/rest/v1/rpc/chat_create_group")!
        let body = try JSONSerialization.data(withJSONObject: ["p_name": name, "p_members": members])
        let (data, http) = try await executeAuthed { t in
            self.makeRequest(url, method: "POST", token: t, body: body)
        }
        guard (200..<300).contains(http.statusCode) else { return nil }
        if let str = String(data: data, encoding: .utf8)?.trimmingCharacters(in: CharacterSet(charactersIn: "\"\n\r ")) {
            return str.isEmpty ? nil : str
        }
        return nil
    }

    func markAsRead(conversationId: String) async throws {
        let url = URL(string: "\(Config.supabaseURL)/rest/v1/rpc/chat_mark_as_read")!
        let body = try JSONSerialization.data(withJSONObject: ["p_conversation_id": conversationId])
        _ = try? await executeAuthed { t in
            self.makeRequest(url, method: "POST", token: t, body: body)
        }
    }

    func getUnreadCount() async throws -> Int {
        let url = URL(string: "\(Config.supabaseURL)/rest/v1/rpc/chat_get_unread_count")!
        let body = "{}".data(using: .utf8)
        let (data, http) = try await executeAuthed { t in
            self.makeRequest(url, method: "POST", token: t, body: body)
        }
        guard (200..<300).contains(http.statusCode) else { return 0 }
        let s = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return Int(s) ?? 0
    }

    func getMessages(conversationId: String, limit: Int = 100) async throws -> [ChatMessage] {
        let urlStr = "\(Config.supabaseURL)/rest/v1/chat_messages?conversation_id=eq.\(conversationId)&select=*&order=created_at.desc&limit=\(limit)"
        let url = URL(string: urlStr)!
        let (data, http) = try await executeAuthed { t in
            self.makeRequest(url, method: "GET", token: t)
        }
        guard (200..<300).contains(http.statusCode) else { return [] }
        let msgs = (try? decoder.decode([ChatMessage].self, from: data)) ?? []
        return msgs.reversed()
    }

    func sendMessage(payload: ChatSendPayload) async throws -> Bool {
        let url = URL(string: "\(Config.supabaseURL)/rest/v1/chat_messages")!
        let body = try encoder.encode(payload)
        let (_, http) = try await executeAuthed { t in
            self.makeRequest(url, method: "POST", token: t, body: body, prefer: "return=minimal")
        }
        return (200..<300).contains(http.statusCode)
    }

    func getActiveUsers(excludeUserId: String?) async throws -> [ProfileLite] {
        let urlStr = "\(Config.supabaseURL)/rest/v1/employees?is_active=eq.true&user_id=not.is.null&select=user_id,full_name&order=full_name.asc&limit=500"
        let url = URL(string: urlStr)!
        let (data, http) = try await executeAuthed { t in
            self.makeRequest(url, method: "GET", token: t)
        }
        guard (200..<300).contains(http.statusCode) else { return [] }
        guard let arr = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]] else { return [] }
        var list: [ProfileLite] = []
        var seen = Set<String>()
        for obj in arr {
            guard let uid = obj["user_id"] as? String, !uid.isEmpty, uid != "null" else { continue }
            if let exc = excludeUserId, uid == exc { continue }
            if seen.contains(uid) { continue }
            seen.insert(uid)
            let name = obj["full_name"] as? String
            list.append(ProfileLite(id: uid, full_name: name))
        }
        return list
    }

    // MARK: - Equipment & Tools APIs
    func getEquipmentList(limit: Int = 1000) async throws -> [EquipmentItem] {
        let urlStr = "\(Config.supabaseURL)/rest/v1/asset_master_data?select=id,asset_id,asset_name,asset_type,brand,unit,stock_quantity,allocated_quantity,warehouse_name,physical_status,current_status,serial_number,supplier,notes,created_at&order=asset_name.asc&limit=\(limit)"
        let url = URL(string: urlStr)!
        let (data, http) = try await executeAuthed { t in
            self.makeRequest(url, method: "GET", token: t)
        }
        guard (200..<300).contains(http.statusCode) else { return [] }
        return (try? decoder.decode([EquipmentItem].self, from: data)) ?? []
    }

    // MARK: - User Permissions
    func getUserPermissions(userId: String) async throws -> UserPermissionsResult {
        let urlStr = "\(Config.supabaseURL)/rest/v1/user_permissions?user_id=eq.\(userId)&select=allowed_modules,can_edit_modules&limit=1"
        guard let url = URL(string: urlStr) else { return UserPermissionsResult() }
        let (data, http) = try await executeAuthed { t in
            self.makeRequest(url, method: "GET", token: t)
        }
        guard (200..<300).contains(http.statusCode) else { return UserPermissionsResult() }
        let list = (try? decoder.decode([UserPermissionsResult].self, from: data)) ?? []
        return list.first ?? UserPermissionsResult()
    }

    // MARK: - Warehouse APIs
    func getWarehouses() async throws -> [Warehouse] {
        let urlStr = "\(Config.supabaseURL)/rest/v1/warehouses?select=id,name,description,is_active&order=name.asc"
        guard let url = URL(string: urlStr) else { return [] }
        let (data, http) = try await executeAuthed { t in
            self.makeRequest(url, method: "GET", token: t)
        }
        guard (200..<300).contains(http.statusCode) else { return [] }
        return (try? decoder.decode([Warehouse].self, from: data)) ?? []
    }

    func getWarehouseStock(warehouseName: String? = nil) async throws -> [WarehouseStockItem] {
        var base = "\(Config.supabaseURL)/rest/v1/asset_warehouse_stock?select=id,warehouse_name,quantity,asset:asset_master_id(id,asset_id,asset_name,sku,unit,asset_type,brand,stock_quantity,notes)&order=warehouse_name.asc&limit=1000"
        if let wh = warehouseName, !wh.isEmpty, let encoded = wh.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) {
            base += "&warehouse_name=eq.\(encoded)"
        }
        guard let url = URL(string: base) else { return [] }
        let (data, http) = try await executeAuthed { t in
            self.makeRequest(url, method: "GET", token: t)
        }
        guard (200..<300).contains(http.statusCode) else { return [] }
        return (try? decoder.decode([WarehouseStockItem].self, from: data)) ?? []
    }

    // MARK: - Tool Check APIs
    func getToolCheckItems() async throws -> [ToolCheckItem] {
        let urlStr = "\(Config.supabaseURL)/rest/v1/tool_check_items?select=id,code,name,note,sort_order,created_at&order=sort_order.asc,name.asc"
        guard let url = URL(string: urlStr) else { return [] }
        let (data, http) = try await executeAuthed { t in
            self.makeRequest(url, method: "GET", token: t)
        }
        guard (200..<300).contains(http.statusCode) else { return [] }
        return (try? decoder.decode([ToolCheckItem].self, from: data)) ?? []
    }

    func getToolCheckEntries(from: String, to: String) async throws -> [ToolCheckEntry] {
        let urlStr = "\(Config.supabaseURL)/rest/v1/tool_check_entries?check_date=gte.\(from)&check_date=lte.\(to)&select=*&limit=1000"
        guard let url = URL(string: urlStr) else { return [] }
        let (data, http) = try await executeAuthed { t in
            self.makeRequest(url, method: "GET", token: t)
        }
        guard (200..<300).contains(http.statusCode) else { return [] }
        return (try? decoder.decode([ToolCheckEntry].self, from: data)) ?? []
    }

    func upsertToolCheckEntry(_ entry: ToolCheckEntryUpsert) async throws -> Bool {
        let url = URL(string: "\(Config.supabaseURL)/rest/v1/tool_check_entries")!
        let body = try encoder.encode(entry)
        let (_, http) = try await executeAuthed { t in
            self.makeRequest(url, method: "POST", token: t, body: body, prefer: "resolution=merge-duplicates,return=minimal")
        }
        return (200..<300).contains(http.statusCode)
    }

    func deleteToolCheckEntry(itemId: String, checkDate: String) async throws -> Bool {
        let urlStr = "\(Config.supabaseURL)/rest/v1/tool_check_entries?item_id=eq.\(itemId)&check_date=eq.\(checkDate)"
        guard let url = URL(string: urlStr) else { return false }
        let (_, http) = try await executeAuthed { t in
            self.makeRequest(url, method: "DELETE", token: t)
        }
        return (200..<300).contains(http.statusCode)
    }

    // MARK: - Project APIs
    func getAllProjects() async throws -> [Project] {
        let urlStr = "\(Config.supabaseURL)/rest/v1/projects?select=id,name,description,location,status,start_date,end_date,budget,priority,project_kind,created_by,created_at,parent_id&order=name.asc&limit=500"
        guard let url = URL(string: urlStr) else { return [] }
        let (data, http) = try await executeAuthed { t in
            self.makeRequest(url, method: "GET", token: t)
        }
        if (200..<300).contains(http.statusCode) {
            let list = (try? decoder.decode([Project].self, from: data)) ?? []
            if !list.isEmpty { return list }
        }
        return try await getSimpleProjects()
    }

    func getSimpleProjects() async throws -> [Project] {
        let urlStr = "\(Config.supabaseURL)/rest/v1/projects?select=id,name,parent_id&order=name.asc&limit=500"
        guard let url = URL(string: urlStr) else { return [] }
        let (data, http) = try await executeAuthed { t in
            self.makeRequest(url, method: "GET", token: t)
        }
        guard (200..<300).contains(http.statusCode) else { return [] }
        return (try? decoder.decode([Project].self, from: data)) ?? []
    }

    func getMemberProjectIds(userId: String) async throws -> [String] {
        let urlStr = "\(Config.supabaseURL)/rest/v1/team_members?user_id=eq.\(userId)&select=project_id&limit=500"
        guard let url = URL(string: urlStr) else { return [] }
        let (data, http) = try await executeAuthed { t in
            self.makeRequest(url, method: "GET", token: t)
        }
        guard (200..<300).contains(http.statusCode) else { return [] }
        guard let arr = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]] else { return [] }
        return arr.compactMap { $0["project_id"] as? String }
    }

    func getProjectMembers(projectId: String) async throws -> [ProjectTeamMember] {
        let urlStr = "\(Config.supabaseURL)/rest/v1/team_members?project_id=eq.\(projectId)&select=*&limit=200"
        guard let url = URL(string: urlStr) else { return [] }
        let (data, http) = try await executeAuthed { t in
            self.makeRequest(url, method: "GET", token: t)
        }
        guard (200..<300).contains(http.statusCode) else { return [] }
        return (try? decoder.decode([ProjectTeamMember].self, from: data)) ?? []
    }

    func getProjectTasks(projectId: String, projectName: String) async throws -> [HrTask] {
        let encodedName = projectName.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? projectName
        let urlStr = "\(Config.supabaseURL)/rest/v1/hr_tasks?or=(project_id.eq.\(projectId),project_name.eq.\(encodedName))&select=*&order=created_at.desc&limit=100"
        guard let url = URL(string: urlStr) else { return [] }
        let (data, http) = try await executeAuthed { t in
            self.makeRequest(url, method: "GET", token: t)
        }
        guard (200..<300).contains(http.statusCode) else { return [] }
        return (try? decoder.decode([HrTask].self, from: data)) ?? []
    }

    func getSubProjects(parentProjectId: String) async throws -> [Project] {
        let urlStr = "\(Config.supabaseURL)/rest/v1/projects?parent_id=eq.\(parentProjectId)&select=id,name,description,location,status,start_date,end_date,budget,priority,project_kind,created_by,created_at,parent_id&order=created_at.asc"
        guard let url = URL(string: urlStr) else { return [] }
        let (data, http) = try await executeAuthed { t in
            self.makeRequest(url, method: "GET", token: t)
        }
        guard (200..<300).contains(http.statusCode) else { return [] }
        return (try? decoder.decode([Project].self, from: data)) ?? []
    }

    func createSubProject(parentProjectId: String, name: String, description: String? = nil, userId: String? = nil) async throws -> Bool {
        let url = URL(string: "\(Config.supabaseURL)/rest/v1/projects")!
        var dict: [String: Any] = [
            "parent_id": parentProjectId,
            "name": name.trimmingCharacters(in: .whitespacesAndNewlines),
            "status": "planning"
        ]
        if let desc = description, !desc.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            dict["description"] = desc.trimmingCharacters(in: .whitespacesAndNewlines)
        }
        if let u = userId, !u.isEmpty {
            dict["created_by"] = u
        }
        let body = try JSONSerialization.data(withJSONObject: dict)
        let (_, http) = try await executeAuthed { t in
            self.makeRequest(url, method: "POST", token: t, body: body)
        }
        return (200..<300).contains(http.statusCode)
    }

    func deleteProject(projectId: String) async throws -> Bool {
        // Try RPC delete_project first
        let rpcUrl = URL(string: "\(Config.supabaseURL)/rest/v1/rpc/delete_project")!
        let rpcBody = try? JSONSerialization.data(withJSONObject: ["project_id_to_delete": projectId])
        if let (_, http) = try? await executeAuthed(makeReq: { t in
            self.makeRequest(rpcUrl, method: "POST", token: t, body: rpcBody)
        }), (200..<300).contains(http.statusCode) {
            return true
        }

        // Fallback: DELETE directly
        let deleteUrl = URL(string: "\(Config.supabaseURL)/rest/v1/projects?id=eq.\(projectId)")!
        let (_, http) = try await executeAuthed { t in
            self.makeRequest(deleteUrl, method: "DELETE", token: t)
        }
        return (200..<300).contains(http.statusCode)
    }

    // MARK: - Task APIs
    func getTasks() async throws -> [HrTask] {
        let urlStr = "\(Config.supabaseURL)/rest/v1/hr_tasks?select=*&order=created_at.desc&limit=200"
        guard let url = URL(string: urlStr) else { return [] }
        let (data, http) = try await executeAuthed { t in
            self.makeRequest(url, method: "GET", token: t)
        }
        guard (200..<300).contains(http.statusCode) else { return [] }
        return (try? decoder.decode([HrTask].self, from: data)) ?? []
    }

    func getAssignees(taskIds: [String]) async throws -> [HrTaskAssignee] {
        guard !taskIds.isEmpty else { return [] }
        let joined = taskIds.joined(separator: ",")
        let urlStr = "\(Config.supabaseURL)/rest/v1/hr_task_assignees?task_id=in.(\(joined))&select=*&limit=1000"
        guard let url = URL(string: urlStr) else { return [] }
        let (data, http) = try await executeAuthed { t in
            self.makeRequest(url, method: "GET", token: t)
        }
        guard (200..<300).contains(http.statusCode) else { return [] }
        return (try? decoder.decode([HrTaskAssignee].self, from: data)) ?? []
    }

    func getReports(taskId: String) async throws -> [HrTaskReport] {
        let urlStr = "\(Config.supabaseURL)/rest/v1/hr_task_reports?task_id=eq.\(taskId)&select=*&order=created_at.asc&limit=200"
        guard let url = URL(string: urlStr) else { return [] }
        let (data, http) = try await executeAuthed { t in
            self.makeRequest(url, method: "GET", token: t)
        }
        guard (200..<300).contains(http.statusCode) else { return [] }
        return (try? decoder.decode([HrTaskReport].self, from: data)) ?? []
    }

    func createTask(
        payload: CreateTaskPayload,
        ownerEmployeeId: String?,
        collaboratorEmployeeIds: [String],
        employees: [Employee]
    ) async throws -> Bool {
        let url = URL(string: "\(Config.supabaseURL)/rest/v1/hr_tasks")!
        let body = try encoder.encode(payload)
        let (data, http) = try await executeAuthed { t in
            self.makeRequest(url, method: "POST", token: t, body: body, prefer: "return=representation")
        }
        guard (200..<300).contains(http.statusCode) else { return false }
        let createdTasks = (try? decoder.decode([HrTask].self, from: data)) ?? []
        guard let createdTaskId = createdTasks.first?.id else { return false }

        let empMap = Dictionary(uniqueKeysWithValues: employees.map { ($0.id, $0) })
        var assigneesToInsert: [CreateAssigneePayload] = []

        if let oid = ownerEmployeeId, !oid.isEmpty {
            let uid = empMap[oid]?.user_id
            assigneesToInsert.append(CreateAssigneePayload(task_id: createdTaskId, employee_id: oid, user_id: uid, role: "owner", acceptance_status: "pending"))
        }

        for cid in collaboratorEmployeeIds where !cid.isEmpty && cid != ownerEmployeeId {
            let uid = empMap[cid]?.user_id
            assigneesToInsert.append(CreateAssigneePayload(task_id: createdTaskId, employee_id: cid, user_id: uid, role: "collaborator", acceptance_status: nil))
        }

        if !assigneesToInsert.isEmpty {
            let aUrl = URL(string: "\(Config.supabaseURL)/rest/v1/hr_task_assignees")!
            let aBody = try encoder.encode(assigneesToInsert)
            _ = try? await executeAuthed { t in
                self.makeRequest(aUrl, method: "POST", token: t, body: aBody, prefer: "return=minimal")
            }
        }

        return true
    }

    func respondAcceptance(
        taskId: String,
        employeeId: String?,
        accepted: Bool,
        note: String? = nil
    ) async throws -> Bool {
        let isoFmt = ISO8601DateFormatter()
        let nowIso = isoFmt.string(from: Date())
        let statusVal = accepted ? "accepted" : "declined"
        let taskStatus = accepted ? "in_progress" : "declined"

        var taskUpdate: [String: Any] = [
            "acceptance_status": statusVal,
            "acceptance_responded_at": nowIso,
            "status": taskStatus
        ]
        if let n = note { taskUpdate["acceptance_note"] = n }

        let taskUrl = URL(string: "\(Config.supabaseURL)/rest/v1/hr_tasks?id=eq.\(taskId)")!
        let taskBody = try JSONSerialization.data(withJSONObject: taskUpdate)
        let (_, http) = try await executeAuthed { t in
            self.makeRequest(taskUrl, method: "PATCH", token: t, body: taskBody, prefer: "return=minimal")
        }
        let taskOk = (200..<300).contains(http.statusCode)

        if let empId = employeeId, !empId.isEmpty {
            let aUrl = URL(string: "\(Config.supabaseURL)/rest/v1/hr_task_assignees?task_id=eq.\(taskId)&employee_id=eq.\(empId)")!
            var aUpdate: [String: Any] = [
                "acceptance_status": statusVal,
                "acceptance_responded_at": nowIso
            ]
            if let n = note { aUpdate["acceptance_note"] = n }
            if let aBody = try? JSONSerialization.data(withJSONObject: aUpdate) {
                _ = try? await executeAuthed { t in
                    self.makeRequest(aUrl, method: "PATCH", token: t, body: aBody, prefer: "return=minimal")
                }
            }
        }

        return taskOk
    }

    func updateTaskProgress(taskId: String, progress: Int) async throws -> Bool {
        let newStatus = progress >= 100 ? "completed" : "in_progress"
        let updateDict: [String: Any] = [
            "progress": progress,
            "status": newStatus
        ]
        let url = URL(string: "\(Config.supabaseURL)/rest/v1/hr_tasks?id=eq.\(taskId)")!
        let body = try JSONSerialization.data(withJSONObject: updateDict)
        let (_, http) = try await executeAuthed { t in
            self.makeRequest(url, method: "PATCH", token: t, body: body, prefer: "return=minimal")
        }
        return (200..<300).contains(http.statusCode)
    }

    func addReport(taskId: String, userId: String, reporterName: String, content: String) async throws -> Bool {
        let payload = CreateReportPayload(task_id: taskId, user_id: userId, reporter_name: reporterName, content: content)
        let url = URL(string: "\(Config.supabaseURL)/rest/v1/hr_task_reports")!
        let body = try encoder.encode(payload)
        let (_, http) = try await executeAuthed { t in
            self.makeRequest(url, method: "POST", token: t, body: body, prefer: "return=minimal")
        }
        return (200..<300).contains(http.statusCode)
    }

    func getActiveEmployees() async throws -> [Employee] {
        let urlStr = "\(Config.supabaseURL)/rest/v1/employees?is_active=eq.true&select=id,full_name,employee_code,position,department,user_id&order=full_name.asc&limit=500"
        guard let url = URL(string: urlStr) else { return [] }
        let (data, http) = try await executeAuthed { t in
            self.makeRequest(url, method: "GET", token: t)
        }
        guard (200..<300).contains(http.statusCode) else { return [] }
        return (try? decoder.decode([Employee].self, from: data)) ?? []
    }
}


