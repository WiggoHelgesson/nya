import SwiftUI

struct SearchRewardsView: View {
    let allRewards: [RewardCard]
    @State private var searchText = ""
    @Environment(\.dismiss) private var dismiss
    
    var filteredRewards: [RewardCard] {
        if searchText.isEmpty {
            return allRewards
        } else {
            return allRewards.filter { reward in
                reward.brandName.localizedCaseInsensitiveContains(searchText) ||
                reward.discount.localizedCaseInsensitiveContains(searchText) ||
                reward.category.localizedCaseInsensitiveContains(searchText)
            }
        }
    }
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Search bar
                HStack {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(.gray)
                        .font(.system(size: 16))
                    
                    TextField("Sök efter belöningar...", text: $searchText)
                        .font(.system(size: 16))
                        .textFieldStyle(PlainTextFieldStyle())
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .background(Color(.systemGray6))
                .cornerRadius(12)
                .padding(.horizontal, 16)
                .padding(.top, 8)
                
                // Results
                if filteredRewards.isEmpty && !searchText.isEmpty {
                    VStack(spacing: 16) {
                        Image(systemName: "magnifyingglass")
                            .font(.system(size: 48))
                            .foregroundColor(.gray)
                        
                        Text("Inga resultat hittades")
                            .font(.system(size: 18, weight: .medium))
                            .foregroundColor(.gray)
                        
                        Text("Prova att söka efter ett annat ord")
                            .font(.system(size: 14))
                            .foregroundColor(.gray)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    ScrollView {
                        LazyVStack(spacing: 16) {
                            ForEach(filteredRewards, id: \.id) { reward in
                                NavigationLink(destination: RewardDetailView(reward: reward)) {
                                    SearchRewardCard(reward: reward)
                                }
                                .buttonStyle(PlainButtonStyle())
                            }
                        }
                        .padding(.horizontal, 16)
                        .padding(.top, 16)
                    }
                }
            }
            .navigationTitle("Sök belöningar")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Stäng") {
                        dismiss()
                    }
                }
            }
        }
    }
}

struct SearchRewardCard: View {
    let reward: RewardCard
    
    var body: some View {
        HStack(spacing: 12) {
            // Brand logo
            Image(getBrandLogo(for: reward.imageName))
                .resizable()
                .scaledToFit()
                .frame(width: 50, height: 50)
                .clipShape(Circle())
            
            VStack(alignment: .leading, spacing: 4) {
                Text(reward.discount)
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(.primary)
                
                Text(reward.brandName)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.gray)
                
                Text(reward.category)
                    .font(.system(size: 12))
                    .foregroundColor(.gray)
            }
            
            Spacer()
            
            Image(systemName: "chevron.right")
                .font(.system(size: 14))
                .foregroundColor(.gray)
        }
        .padding(16)
        .background(Color(.secondarySystemBackground))
        .cornerRadius(12)
        .shadow(color: Color.black.opacity(0.1), radius: 2, x: 0, y: 1)
    }
    
    private func getBrandLogo(for imageName: String) -> String {
        switch imageName {
        case "4": return "15" // PLIKTGOLF (old)
        case "56": return "15" // PLIKTGOLF (new cover)
        case "5": return "5"  // PEGMATE (old)
        case "49": return "5"  // PEGMATE (new cover)
        case "6": return "14" // LONEGOLF (old)
        case "50": return "14" // LONEGOLF (new cover)
        case "7": return "17" // WINWIZE (old)
        case "51": return "17" // WINWIZE (new cover)
        case "8": return "18" // SCANDIGOLF
        case "9": return "19" // Exotic Golf
        case "10": return "16" // HAPPYALBA (old)
        case "57": return "16" // HAPPYALBA (new cover)
        case "11": return "20" // RETROGOLF
        case "12": return "21" // PUMPLABS (old)
        case "54": return "21" // PUMPLABS (new cover)
        case "13": return "22" // ZEN ENERGY (old)
        case "52": return "22" // ZEN ENERGY (new cover)
        case "34": return "34" // CAPSTONE
        case "35": return "46" // FUSE ENERGY (old)
        case "48": return "46" // FUSE ENERGY (new cover)
        case "38": return "38" // Fjällsyn UF
        case "39": return "39" // CLYRO (old)
        case "53": return "39" // CLYRO (new cover)
        case "40": return "40" // Powerwell (old)
        case "55": return "40" // Powerwell (new cover)
        case "44": return "45" // XEEIL
        default: return imageName // Use the image itself as logo if no mapping
        }
    }
}

#Preview {
    SearchRewardsView(allRewards: [])
}
