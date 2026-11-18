import Foundation
import SwiftUI

@MainActor
final class SessionStore: ObservableObject {
    struct Session: Equatable {
        var token: String?
        var refreshToken: String?
        var userId: String?
        var employeeId: String?
        var employeeName: String?
        var position: String?
        var department: String?
        var canEditModules: [String] = []
        var allowedModules: [String] = []
    }

    @Published private(set) var session = Session()
    @Published var isLoading = true

    private let d = UserDefaults.standard
    private let kToken = "kba.token"
    private let kRefresh = "kba.refresh"
    private let kUser = "kba.user"
    private let kEmpId = "kba.empId"
    private let kEmpName = "kba.empName"
    private let kPos = "kba.pos"
    private let kDep = "kba.dep"
    private let kCanEditModules = "kba.canEditModules"
    private let kAllowedModules = "kba.allowedModules"

    func load() {
        let canEditStr = d.string(forKey: kCanEditModules) ?? ""
        let allowedStr = d.string(forKey: kAllowedModules) ?? ""

        let canEdit = canEditStr.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty }
        let allowed = allowedStr.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty }

        session = Session(
            token: d.string(forKey: kToken),
            refreshToken: d.string(forKey: kRefresh),
            userId: d.string(forKey: kUser),
            employeeId: d.string(forKey: kEmpId),
            employeeName: d.string(forKey: kEmpName),
            position: d.string(forKey: kPos),
            department: d.string(forKey: kDep),
            canEditModules: canEdit,
            allowedModules: allowed
        )
        isLoading = false
    }

    var isLoggedIn: Bool {
        !(session.token?.isEmpty ?? true) && !(session.employeeId?.isEmpty ?? true)
    }

    func save(token: String, refresh: String?, userId: String, empId: String, name: String, pos: String?, dep: String?) {
        d.set(token, forKey: kToken)
        d.set(refresh ?? "", forKey: kRefresh)
        d.set(userId, forKey: kUser)
        d.set(empId, forKey: kEmpId)
        d.set(name, forKey: kEmpName)
        d.set(pos ?? "", forKey: kPos)
        d.set(dep ?? "", forKey: kDep)
        load()
    }

    func saveUserId(_ userId: String) {
        d.set(userId, forKey: kUser)
        load()
    }

    func savePermissions(allowed: [String], canEdit: [String]) {
        d.set(allowed.joined(separator: ","), forKey: kAllowedModules)
        d.set(canEdit.joined(separator: ","), forKey: kCanEditModules)
        load()
    }

    func updateTokens(token: String, refresh: String?) {
        d.set(token, forKey: kToken)
        if let r = refresh, !r.isEmpty { d.set(r, forKey: kRefresh) }
        load()
    }

    func clear() {
        [kToken, kRefresh, kUser, kEmpId, kEmpName, kPos, kDep, kCanEditModules, kAllowedModules].forEach { d.removeObject(forKey: $0) }
        load()
    }
}
