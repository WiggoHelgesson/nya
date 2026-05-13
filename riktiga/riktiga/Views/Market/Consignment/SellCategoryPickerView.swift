import SwiftUI

struct SellCategoryPickerView: View {
    @ObservedObject var model: SellFlowModel
    @Binding var path: NavigationPath

    @State private var search: String = ""

    private let accent = Color.black

    private var filtered: [SportCategory] {
        let trimmed = search.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !trimmed.isEmpty else { return SportCategory.all }
        return SportCategory.all.filter { cat in
            cat.displayName.lowercased().contains(trimmed)
                || cat.subcategories.contains { $0.displayName.lowercased().contains(trimmed) }
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            searchBar
            ScrollView {
                VStack(spacing: 0) {
                    ForEach(filtered) { category in
                        Button {
                            if category.subcategories.isEmpty {
                                model.selectedCategory = category.displayName
                                path.removeLast()
                            } else {
                                path.append(SellRoute.subcategory(topCategoryId: category.id))
                            }
                        } label: {
                            HStack(spacing: 14) {
                                Image(systemName: category.sfSymbol)
                                    .font(.system(size: 18, weight: .semibold))
                                    .foregroundStyle(accent)
                                    .frame(width: 28)
                                Text(category.displayName)
                                    .font(.system(size: 16))
                                    .foregroundStyle(.primary)
                                Spacer()
                                Image(systemName: "chevron.right")
                                    .font(.system(size: 13, weight: .semibold))
                                    .foregroundStyle(.secondary)
                            }
                            .padding(.horizontal, 18)
                            .padding(.vertical, 16)
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        Divider().padding(.leading, 60)
                    }
                }
            }
        }
        .background(Color(.systemBackground).ignoresSafeArea())
        .navigationTitle(L.t(sv: "Sport", nb: "Sport"))
        .navigationBarTitleDisplayMode(.inline)
    }

    private var searchBar: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(.secondary)
            TextField(
                L.t(sv: "Hitta kategori", nb: "Finn kategori"),
                text: $search
            )
            .textInputAutocapitalization(.never)
            .autocorrectionDisabled()
            if !search.isEmpty {
                Button {
                    search = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .padding(.horizontal, 16)
        .padding(.top, 12)
        .padding(.bottom, 8)
    }
}

struct SellSubcategoryPickerView: View {
    @ObservedObject var model: SellFlowModel
    @Binding var path: NavigationPath
    let topCategoryId: String

    @State private var search: String = ""

    private let accent = Color.black

    private var category: SportCategory? {
        SportCategory.find(id: topCategoryId)
    }

    private var filtered: [SportSubcategory] {
        guard let list = category?.subcategories else { return [] }
        let trimmed = search.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !trimmed.isEmpty else { return list }
        return list.filter { $0.displayName.lowercased().contains(trimmed) }
    }

    var body: some View {
        VStack(spacing: 0) {
            searchBar
            ScrollView {
                VStack(spacing: 0) {
                    ForEach(filtered) { sub in
                        Button {
                            if let cat = category {
                                model.selectedCategory = "\(cat.displayName) / \(sub.displayName)"
                            } else {
                                model.selectedCategory = sub.displayName
                            }
                            path.removeLast(path.count)
                        } label: {
                            HStack(spacing: 14) {
                                Image(systemName: category?.sfSymbol ?? "circle")
                                    .font(.system(size: 18, weight: .semibold))
                                    .foregroundStyle(accent)
                                    .frame(width: 28)
                                Text(sub.displayName)
                                    .font(.system(size: 16))
                                    .foregroundStyle(.primary)
                                Spacer()
                            }
                            .padding(.horizontal, 18)
                            .padding(.vertical, 16)
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        Divider().padding(.leading, 60)
                    }
                }
            }
        }
        .background(Color(.systemBackground).ignoresSafeArea())
        .navigationTitle(category?.displayName ?? L.t(sv: "Kategori", nb: "Kategori"))
        .navigationBarTitleDisplayMode(.inline)
    }

    private var searchBar: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(.secondary)
            TextField(
                L.t(sv: "Hitta underkategori", nb: "Finn underkategori"),
                text: $search
            )
            .textInputAutocapitalization(.never)
            .autocorrectionDisabled()
            if !search.isEmpty {
                Button {
                    search = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .padding(.horizontal, 16)
        .padding(.top, 12)
        .padding(.bottom, 8)
    }
}
