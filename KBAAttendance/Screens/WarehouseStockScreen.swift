import SwiftUI

struct WarehouseStockScreen: View {
    @Environment(\.presentationMode) var presentationMode
    @EnvironmentObject var store: SessionStore

    @State private var warehouses: [Warehouse] = []
    @State private var allStockItems: [WarehouseStockItem] = []
    @State private var loading = true
    @State private var errorMsg: String?

    @State private var selectedWarehouse: String? = nil // nil = All
    @State private var selectedType = "ALL" // ALL, tools, equipment, materials
    @State private var searchQuery = ""

    private var filteredItems: [WarehouseStockItem] {
        allStockItems.filter { item in
            // Filter warehouse
            if let wh = selectedWarehouse, !item.warehouse_name.localizedCaseInsensitiveContains(wh) {
                return false
            }

            // Filter type
            let assetType = (item.asset?.asset_type ?? "").lowercased()
            let matchType: Bool
            switch selectedType {
            case "tools":
                matchType = assetType == "tools" || assetType.contains("tool") || assetType.contains("cong_cu")
            case "equipment":
                matchType = assetType == "equipment" || assetType.contains("equip") || assetType.contains("thiet_bi")
            case "materials":
                matchType = assetType == "materials" || assetType.contains("material") || assetType.contains("vat_tu")
            default:
                matchType = true
            }
            if !matchType { return false }

            // Filter search
            let query = searchQuery.trimmingCharacters(in: .whitespaces).lowercased()
            if query.isEmpty { return true }
            let name = (item.asset?.asset_name ?? "").lowercased()
            let code = (item.asset?.asset_id ?? "").lowercased()
            let sku = (item.asset?.sku ?? "").lowercased()
            let brand = (item.asset?.brand ?? "").lowercased()
            return name.contains(query) || code.contains(query) || sku.contains(query) || brand.contains(query)
        }
    }

    private var inStockCount: Int {
        filteredItems.filter { $0.quantity > 0 }.count
    }

    private var outOfStockCount: Int {
        filteredItems.count - inStockCount
    }

    var body: some View {
        VStack(spacing: 0) {
            // Search and Filters
            VStack(spacing: 8) {
                // Search field
                HStack {
                    Image(systemName: "magnifyingglass").foregroundColor(.secondary)
                    TextField("Tìm theo tên, mã đồ, thương hiệu…", text: $searchQuery)
                    if !searchQuery.isEmpty {
                        Button(action: { searchQuery = "" }) {
                            Image(systemName: "xmark.circle.fill").foregroundColor(.secondary)
                        }
                    }
                }
                .padding(10)
                .background(Color(.systemGray6))
                .cornerRadius(10)

                // Warehouse filter
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        FilterButton(title: "Tất cả kho", isSelected: selectedWarehouse == nil) {
                            selectedWarehouse = nil
                        }
                        ForEach(warehouses) { wh in
                            FilterButton(title: wh.name, isSelected: selectedWarehouse == wh.name) {
                                if selectedWarehouse == wh.name { selectedWarehouse = nil }
                                else { selectedWarehouse = wh.name }
                            }
                        }
                    }
                }

                // Type filter
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        FilterButton(title: "Tất cả loại", isSelected: selectedType == "ALL") { selectedType = "ALL" }
                        FilterButton(title: "Công cụ / Dụng cụ", isSelected: selectedType == "tools") { selectedType = "tools" }
                        FilterButton(title: "Thiết bị", isSelected: selectedType == "equipment") { selectedType = "equipment" }
                        FilterButton(title: "Vật tư", isSelected: selectedType == "materials") { selectedType = "materials" }
                    }
                }

                // Summary Row
                HStack(spacing: 12) {
                    SummaryBadge(title: "Tổng số", count: filteredItems.count, color: .primary)
                    SummaryBadge(title: "Còn tồn", count: inStockCount, color: Color(red: 0.07, green: 0.55, blue: 0.20))
                    SummaryBadge(title: "Hết hàng", count: outOfStockCount, color: .red)
                }
                .padding(.top, 4)
            }
            .padding(.horizontal)
            .padding(.vertical, 8)
            .background(Color(.secondarySystemBackground))

            // Items List
            if loading && allStockItems.isEmpty {
                Spacer()
                ProgressView("Đang tải dữ liệu kho…")
                Spacer()
            } else if let err = errorMsg, allStockItems.isEmpty {
                Spacer()
                Text(err).foregroundColor(.red).padding()
                Button("Thử lại") { loadData() }
                Spacer()
            } else if filteredItems.isEmpty {
                Spacer()
                VStack(spacing: 12) {
                    Image(systemName: "shippingbox").font(.system(size: 50)).foregroundColor(.secondary)
                    Text("Không tìm thấy đồ hoặc vật tư phù hợp").foregroundColor(.secondary)
                }
                Spacer()
            } else {
                List(filteredItems) { item in
                    WarehouseStockCard(item: item)
                        .listRowInsets(EdgeInsets(top: 6, leading: 14, bottom: 6, trailing: 14))
                        .listRowSeparator(.hidden)
                }
                .listStyle(.plain)
                .refreshable {
                    await reloadDataAsync()
                }
            }
        }
        .navigationTitle("Kho công cụ dụng cụ")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button(action: { loadData() }) {
                    Image(systemName: "arrow.clockwise")
                }
            }
        }
        .task {
            loadData()
        }
    }

    private func loadData() {
        loading = true
        errorMsg = nil
        Task {
            await reloadDataAsync()
        }
    }

    private func reloadDataAsync() async {
        do {
            let whList = try await SupabaseApi.shared.getWarehouses()
            let stockList = try await SupabaseApi.shared.getWarehouseStock()
            await MainActor.run {
                self.warehouses = whList
                self.allStockItems = stockList
                self.loading = false
            }
        } catch {
            await MainActor.run {
                self.errorMsg = error.localizedDescription
                self.loading = false
            }
        }
    }
}

private struct FilterButton: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .bold()
                .font(.footnote)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(isSelected ? Color(red: 0.07, green: 0.45, blue: 0.20) : Color(.systemBackground))
                .foregroundColor(isSelected ? .white : .primary)
                .cornerRadius(16)
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(isSelected ? Color.clear : Color(.systemGray4), lineWidth: 1)
                )
        }
    }
}

private struct SummaryBadge: View {
    let title: String
    let count: Int
    let color: Color

    var body: some View {
        HStack(spacing: 4) {
            Text("\(title):").font(.caption).foregroundColor(.secondary)
            Text("\(count)").bold().font(.caption).foregroundColor(color)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(Color(.systemBackground))
        .cornerRadius(8)
    }
}

private struct WarehouseStockCard: View {
    let item: WarehouseStockItem

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                HStack(spacing: 4) {
                    Image(systemName: "building.2.crop.list").font(.caption)
                    Text(item.warehouse_name).bold().font(.caption)
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 3)
                .background(Color(.systemGray5))
                .cornerRadius(6)

                Spacer()

                if item.quantity > 0 {
                    let formatted = item.quantity.truncatingRemainder(dividingBy: 1) == 0 ? String(format: "%.0f", item.quantity) : String(format: "%.2f", item.quantity)
                    Text("Còn \(formatted) \(item.asset?.unit ?? "cái")")
                        .bold()
                        .font(.caption)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(Color(red: 0.86, green: 0.95, blue: 0.88))
                        .foregroundColor(Color(red: 0.07, green: 0.45, blue: 0.20))
                        .cornerRadius(6)
                } else {
                    Text("Hết hàng")
                        .bold()
                        .font(.caption)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(Color(red: 1.0, green: 0.9, blue: 0.9))
                        .foregroundColor(.red)
                        .cornerRadius(6)
                }
            }

            Text(item.asset?.asset_name ?? "Chưa rõ tên")
                .font(.headline)
                .foregroundColor(.primary)

            HStack(spacing: 12) {
                if let code = item.asset?.asset_id, !code.isEmpty {
                    Text("Mã: \(code)").font(.caption).foregroundColor(.secondary)
                }
                if let sku = item.asset?.sku, !sku.isEmpty {
                    Text("SKU: \(sku)").font(.caption).foregroundColor(.secondary)
                }
                if let brand = item.asset?.brand, !brand.isEmpty {
                    Text("Hiệu: \(brand)").font(.caption).foregroundColor(.secondary)
                }
            }

            if let notes = item.asset?.notes, !notes.isEmpty {
                Text("Ghi chú: \(notes)")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .italic()
            }
        }
        .padding(14)
        .background(Color(.secondarySystemBackground))
        .cornerRadius(12)
    }
}
