import SwiftUI

struct SellColorsPickerView: View {
    @ObservedObject var model: SellFlowModel
    @Binding var path: NavigationPath

    private let accent = Color.black

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                ForEach(ListingColor.allCases) { color in
                    Button {
                        toggle(color)
                    } label: {
                        HStack(spacing: 14) {
                            Circle()
                                .fill(color.swatch)
                                .frame(width: 22, height: 22)
                                .overlay(
                                    Circle().strokeBorder(Color.black.opacity(0.12), lineWidth: 1)
                                )
                            Text(color.displayName)
                                .font(.system(size: 16))
                                .foregroundStyle(.primary)
                            Spacer()
                            checkbox(isSelected: model.colors.contains(color.rawValue))
                        }
                        .padding(.horizontal, 18)
                        .padding(.vertical, 14)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    Divider().padding(.leading, 54)
                }
            }
        }
        .background(Color(.systemBackground).ignoresSafeArea())
        .navigationTitle(L.t(sv: "Färger", nb: "Farger"))
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button(L.t(sv: "Klar", nb: "Ferdig")) {
                    path.removeLast()
                }
                .fontWeight(.semibold)
                .disabled(model.colors.isEmpty)
            }
        }
    }

    private func toggle(_ color: ListingColor) {
        if let idx = model.colors.firstIndex(of: color.rawValue) {
            model.colors.remove(at: idx)
        } else {
            model.colors.append(color.rawValue)
        }
    }

    private func checkbox(isSelected: Bool) -> some View {
        ZStack {
            RoundedRectangle(cornerRadius: 6)
                .strokeBorder(isSelected ? accent : Color.gray.opacity(0.5), lineWidth: 2)
                .frame(width: 22, height: 22)
            if isSelected {
                RoundedRectangle(cornerRadius: 6)
                    .fill(accent)
                    .frame(width: 22, height: 22)
                Image(systemName: "checkmark")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(.white)
            }
        }
    }
}
