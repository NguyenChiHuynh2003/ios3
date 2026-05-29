import SwiftUI

struct LoginScreen: View {
    @EnvironmentObject var store: SessionStore
    @State private var email = ""
    @State private var password = ""
    @State private var loading = false
    @State private var error: String?

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 16) {
                    Image("Logo")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 140, height: 140)
                        .padding(.top, 24)
                    Text("Đăng nhập").font(.title).bold()

                    TextField("Email", text: $email)
                        .keyboardType(.emailAddress)
                        .autocapitalization(.none)
                        .disableAutocorrection(true)
                        .textFieldStyle(.roundedBorder)

                    SecureField("Mật khẩu", text: $password)
                        .textFieldStyle(.roundedBorder)

                    if let e = error {
                        Text(e).foregroundColor(.red).font(.footnote)
                    }

                    Button(action: signIn) {
                        HStack {
                            if loading { ProgressView().tint(.white) }
                            Text("Đăng nhập").bold()
                        }
                        .frame(maxWidth: .infinity, minHeight: 48)
                        .background((email.isEmpty || password.isEmpty || loading) ? Color.gray : Color(red: 0.07, green: 0.45, blue: 0.20))
                        .foregroundColor(.white)
                        .cornerRadius(10)
                    }
                    .disabled(email.isEmpty || password.isEmpty || loading)

                    Text("Sử dụng tài khoản nội bộ kba2018.vn")
                        .font(.caption).foregroundColor(.secondary)
                }
                .padding(24)
            }
            .navigationTitle("KBA Chấm công")
            .navigationBarTitleDisplayMode(.inline)
        }
        .navigationViewStyle(.stack)
    }

    private func signIn() {
        let loginEmail = email.trimmingCharacters(in: .whitespaces)
        let loginPassword = password

        Task {
            await MainActor.run {
                error = nil
                loading = true
            }

            do {
                let res = try await SupabaseApi.shared.signIn(email: loginEmail, password: loginPassword)
                guard let token = res.access_token, let uid = res.user?.id else {
                    await MainActor.run {
                        error = res.error_description ?? res.msg ?? "Đăng nhập thất bại"
                        loading = false
                    }
                    return
                }
                await SupabaseApi.shared.setTokens(token: token, refresh: res.refresh_token)
                guard let emp = try await SupabaseApi.shared.getMyEmployee(userId: uid) else {
                    await MainActor.run {
                        error = "Không tìm thấy hồ sơ nhân viên"
                        loading = false
                    }
                    return
                }
                if emp.is_active == false {
                    await MainActor.run {
                        error = "Tài khoản đã bị vô hiệu hoá"
                        loading = false
                    }
                    return
                }
                await MainActor.run {
                    store.save(token: token, refresh: res.refresh_token, userId: uid, empId: emp.id, name: emp.full_name, pos: emp.position, dep: emp.department)
                    loading = false
                }
            } catch {
                await MainActor.run {
                    self.error = error.localizedDescription
                    loading = false
                }
            }
        }
    }
}
