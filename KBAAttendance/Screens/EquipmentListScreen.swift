import SwiftUI

private func statusDisplay(_ status: String?) -> (label: String, color: Color) {
    switch status?.lowercased() {
    case "in_stock":
        return ("Trong kho", Color(red: 0.09, green: 0.64, blue: 0.29))
    case "in_use":
        return ("Đang sử dụng", Color(red: 0.15, green: 0.45, blue: 0.85))
    case "maintenance":
        return ("Bảo dưỡng", Color(red: 0.85, green: 0.47, blue: 0.02))
    case "disposed":
        return ("Đã thanh lý", Color(red: 0.86, green: 0.15, blue: 0.15))
    case "lost", "damaged":
        return ("Hỏng / Mất", Color(red: 0.86, green: 0.15, blue: 0.15))
    default:
        return (status ?? "Khác", Color.secondary)
    }
}

private func typeDisplay(_ type: String?) -> String {
    switch type?.lowercased() {
    case "tools": return "Công cụ"
    case "equipment": return "Thiết bị"
    case "materials": return "Vật tư"
    default: return type?.capitalized ?? "Khác"
    }
}

struct EquipmentListScreen: View {
    @State private var items: [EquipmentItem] = []
    @State private var loading = true
    @State private var errorMessage: String?
    @State private var searchQuery = ""
    @State private var selectedTypeFilter = "all" // all, tools, equipment, materials
    @State private var selectedItem: EquipmentItem?

    var filteredItems: [EquipmentItem] {
        var result = items

        // Filter by type
        if selectedTypeFilter != "all" {
            result = result.filter { ($0.asset_type ?? "").lowercased() == selectedTypeFilter }
        }

        // Filter by search query
        let q = searchQuery.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        if !q.isEmpty {
            result = result.filter { item in
                let name = item.asset_name.lowercased()
                let code = item.asset_id.lowercased()
                let brand = (item.brand ?? "").lowercased()
                let wh = (item.warehouse_name ?? "").lowercased()
                let serial = (item.serial_number ?? "").lowercased()
                return name.contains(q) || code.contains(q) || brand.contains(q) || wh.contains(q) || serial.contains(q)
            }
        }

        return result
    }

    var body: some View {
        VStack(spacing: 0) {
            // Search field
            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.secondary)
                TextField("Tìm theo tên, mã CCDC, hãng, kho…", text: $searchQuery)
                    .autocapitalization(.none)
                    .disableAutocorrection(true)
                if !searchQuery.isEmpty {
                    Button(action: { searchQuery = "" }) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.secondary)
                    }
                }
            }
            .padding(10)
            .background(Color(.secondarySystemBackground))
            .cornerRadius(10)
            .padding(.horizontal)
            .padding(.top, 8)
            .padding(.bottom, 6)

            // Category filter chips
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    typeChip(title: "Tất cả (\(items.count))", value: "all")
                    typeChip(title: "Công cụ (\(items.filter { ($0.asset_type ?? "").lowercased() == "tools" }.count))", value: "tools")
                    typeChip(title: "Thiết bị (\(items.filter { ($0.asset_type ?? "").lowercased() == "equipment" }.count))", value: "equipment")
                    typeChip(title: "Vật tư (\(items.filter { ($0.asset_type ?? "").lowercased() == "materials" }.count))", value: "materials")
                }
                .padding(.horizontal)
                .padding(.vertical, 6)
            }

            Divider()

            // Content
            if loading && items.isEmpty {
                Spacer()
                ProgressView("Đang tải dữ liệu…")
                Spacer()
            } else if let err = errorMessage, items.isEmpty {
                Spacer()
                VStack(spacing: 12) {
                    Image(systemName: "exclamationmark.triangle")
                        .font(.system(size: 40))
                        .foregroundColor(.orange)
                    Text("Không thể tải danh sách").font(.headline)
                    Text(err).font(.caption).foregroundColor(.secondary).multilineTextAlignment(.center)
                    Button("Thử lại") {
                        Task { await loadData() }
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 8)
                    .background(Color(red: 0.07, green: 0.45, blue: 0.20))
                    .foregroundColor(.white)
                    .cornerRadius(8)
                }
                .padding()
                Spacer()
            } else if filteredItems.isEmpty {
                Spacer()
                VStack(spacing: 8) {
                    Image(systemName: "wrench.and.screwdriver")
                        .font(.system(size: 44))
                        .foregroundColor(.secondary)
                    Text(searchQuery.isEmpty ? "Chưa có công cụ dụng cụ nào" : "Không tìm thấy kết quả phù hợp")
                        .foregroundColor(.secondary)
                }
                .padding()
                Spacer()
            } else {
                List(filteredItems) { item in
                    EquipmentRow(item: item)
                        .contentShape(Rectangle())
                        .onTapGesture {
                            selectedItem = item
                        }
                }
                .listStyle(.plain)
                .refreshable {
                    await loadData()
                }
            }
        }
        .navigationTitle("Công cụ dụng cụ")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(item: $selectedItem) { item in
            NavigationView {
                EquipmentDetailView(item: item)
            }
        }
        .task {
            await loadData()
        }
    }

    private func typeChip(title: String, value: String) -> some View {
        let isSelected = selectedTypeFilter == value
        return Button(action: {
            selectedTypeFilter = value
        }) {
            Text(title)
                .font(.caption)
                .fontWeight(isSelected ? .semibold : .regular)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(isSelected ? Color(red: 0.07, green: 0.45, blue: 0.20) : Color(.secondarySystemBackground))
                .foregroundColor(isSelected ? .white : .primary)
                .cornerRadius(16)
        }
    }

    private func loadData() async {
        do {
            let res = try await SupabaseApi.shared.getEquipmentList()
            await MainActor.run {
                self.items = res
                self.loading = false
                self.errorMessage = nil
            }
        } catch {
            await MainActor.run {
                self.errorMessage = error.localizedDescription
                self.loading = false
            }
        }
    }
}

private struct EquipmentRow: View {
    let item: EquipmentItem

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(item.asset_name)
                        .font(.headline)
                        .foregroundColor(.primary)
                        .lineLimit(2)
                    HStack(spacing: 8) {
                        Text(item.asset_id)
                            .font(.caption)
                            .bold()
                            .foregroundColor(Color(red: 0.07, green: 0.45, blue: 0.20))
                        if let brand = item.brand, !brand.isEmpty {
                            Text("• \(brand)")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                }
                Spacer()
                let status = statusDisplay(item.physical_status ?? item.current_status)
                Text(status.label)
                    .font(.caption2)
                    .bold()
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(status.color.opacity(0.15))
                    .foregroundColor(status.color)
                    .cornerRadius(6)
            }

            HStack(spacing: 16) {
                // Stock
                HStack(spacing: 4) {
                    Image(systemName: "shippingbox")
                        .foregroundColor(.secondary)
                        .font(.caption)
                    Text("Tồn: \(String(format: "%g", item.stock_quantity ?? 0)) \(item.unit ?? "")")
                        .font(.caption)
                        .foregroundColor(.primary)
                }

                // Allocated
                if (item.allocated_quantity ?? 0) > 0 {
                    HStack(spacing: 4) {
                        Image(systemName: "person.2")
                            .foregroundColor(.secondary)
                            .font(.caption)
                        Text("Cấp phát: \(String(format: "%g", item.allocated_quantity ?? 0))")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }

                Spacer()

                // Warehouse
                if let wh = item.warehouse_name, !wh.isEmpty {
                    HStack(spacing: 3) {
                        Image(systemName: "mappin.and.ellipse")
                            .foregroundColor(.secondary)
                            .font(.caption2)
                        Text(wh)
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .lineLimit(1)
                    }
                }
            }
        }
        .padding(.vertical, 6)
    }
}

struct EquipmentDetailView: View {
    let item: EquipmentItem
    @Environment(\.presentationMode) var presentationMode

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                // Header card
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        let status = statusDisplay(item.physical_status ?? item.current_status)
                        Text(status.label)
                            .font(.caption)
                            .bold()
                            .padding(.horizontal, 10)
                            .padding(.vertical, 4)
                            .background(status.color.opacity(0.15))
                            .foregroundColor(status.color)
                            .cornerRadius(8)

                        Spacer()

                        Text(typeDisplay(item.asset_type))
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Color(.systemBackground))
                            .cornerRadius(6)
                    }

                    Text(item.asset_name)
                        .font(.title3)
                        .bold()

                    Text(item.asset_id)
                        .font(.subheadline)
                        .bold()
                        .foregroundColor(Color(red: 0.07, green: 0.45, blue: 0.20))
                }
                .padding()
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color(.secondarySystemBackground))
                .cornerRadius(12)

                // Quantities & Location Card
                VStack(spacing: 12) {
                    infoRow(icon: "shippingbox.fill", label: "Tồn kho khả dụng", value: "\(String(format: "%g", item.stock_quantity ?? 0)) \(item.unit ?? "")")
                    Divider()
                    infoRow(icon: "person.2.fill", label: "Đang cấp phát", value: "\(String(format: "%g", item.allocated_quantity ?? 0)) \(item.unit ?? "")")
                    Divider()
                    infoRow(icon: "building.2.fill", label: "Kho lưu trữ", value: item.warehouse_name ?? "—")
                }
                .padding()
                .background(Color(.secondarySystemBackground))
                .cornerRadius(12)

                // Additional details card
                VStack(spacing: 12) {
                    infoRow(icon: "tag.fill", label: "Thương hiệu / Hãng", value: item.brand?.isEmpty == false ? item.brand! : "—")
                    Divider()
                    infoRow(icon: "barcode", label: "Số Serial", value: item.serial_number?.isEmpty == false ? item.serial_number! : "—")
                    Divider()
                    infoRow(icon: "cart.fill", label: "Nhà cung cấp", value: item.supplier?.isEmpty == false ? item.supplier! : "—")
                    if let notes = item.notes, !notes.isEmpty {
                        Divider()
                        infoRow(icon: "note.text", label: "Ghi chú", value: notes)
                    }
                }
                .padding()
                .background(Color(.secondarySystemBackground))
                .cornerRadius(12)
            }
            .padding()
        }
        .navigationTitle("Chi tiết CCDC")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button("Đóng") {
                    presentationMode.wrappedValue.dismiss()
                }
            }
        }
    }

    private func infoRow(icon: String, label: String, value: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .font(.body)
                .foregroundColor(Color(red: 0.07, green: 0.45, blue: 0.20))
                .frame(width: 24)
            Text(label)
                .font(.subheadline)
                .foregroundColor(.secondary)
            Spacer()
            Text(value)
                .font(.subheadline)
                .fontWeight(.medium)
                .multilineTextAlignment(.trailing)
        }
    }
}
