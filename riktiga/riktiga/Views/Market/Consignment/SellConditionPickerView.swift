import SwiftUI

struct SellConditionPickerView: View {
    @ObservedObject var model: SellFlowModel
    @Binding var path: NavigationPath

    private let accent = Color.black

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                ForEach(SellCondition.allCases) { condition in
                    Button {
                        model.condition = condition.rawValue
                        Task { @MainActor in
                            if !path.isEmpty { path.removeLast() }
                        }
                    } label: {
                        HStack(alignment: .top, spacing: 14) {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(condition.title)
                                    .font(.system(size: 16, weight: .semibold))
                                    .foregroundStyle(.primary)
                                Text(condition.descriptionText)
                                    .font(.system(size: 13))
                                    .foregroundStyle(.secondary)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                            Spacer()
                            radio(isSelected: model.condition == condition.rawValue)
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
        .navigationTitle(L.t(sv: "Skick", nb: "Stand"))
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
