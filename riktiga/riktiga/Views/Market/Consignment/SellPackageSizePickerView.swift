import SwiftUI

struct SellPackageSizePickerView: View {
    @ObservedObject var model: SellFlowModel
    @Binding var path: NavigationPath

    private let accent = Color.black

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                ForEach(PackageSize.allCases) { size in
                    Button {
                        model.packageSize = size.rawValue
                        Task { @MainActor in
                            if !path.isEmpty { path.removeLast() }
                        }
                    } label: {
                        HStack(alignment: .top, spacing: 14) {
                            Text(size.code)
                                .font(.system(size: 16, weight: .bold))
                                .foregroundStyle(.primary)
                                .frame(width: 40, alignment: .leading)
                            Text(size.descriptionText)
                                .font(.system(size: 14))
                                .foregroundStyle(.secondary)
                                .fixedSize(horizontal: false, vertical: true)
                            Spacer()
                            radio(isSelected: model.packageSize == size.rawValue)
                                .padding(.top, 2)
                        }
                        .padding(.horizontal, 18)
                        .padding(.vertical, 16)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    Divider().padding(.leading, 18)
                }
            }
        }
        .background(Color(.systemBackground).ignoresSafeArea())
        .navigationTitle(L.t(sv: "Paketstorlek", nb: "Pakkestørrelse"))
        .navigationBarTitleDisplayMode(.inline)
    }

    private func radio(isSelected: Bool) -> some View {
        ZStack {
            Circle()
                .strokeBorder(isSelected ? accent : Color.gray.opacity(0.5), lineWidth: 2)
                .frame(width: 22, height: 22)
            if isSelected {
                Circle()
                    .fill(accent)
                    .frame(width: 12, height: 12)
            }
        }
    }
}
