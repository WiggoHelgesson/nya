import SwiftUI
import Supabase

struct NutritionSettingsView: View {
    @EnvironmentObject var authViewModel: AuthViewModel
    @Environment(\.dismiss) var dismiss
    
    @State private var caloriesGoal: Int = 2000
    @State private var proteinGoal: Int = 150
    @State private var carbsGoal: Int = 250
    @State private var fatGoal: Int = 70
    @State private var isSaving = false
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    // Header
                    VStack(spacing: 8) {
                        Image(systemName: "flame.fill")
                            .font(.system(size: 40))
                            .foregroundColor(.orange)
                        
                        Text("Näringsmål")
                            .font(.system(size: 28, weight: .bold))
                            .foregroundColor(.black)
                        
                        Text("Justera dina dagliga mål")
                            .font(.system(size: 16))
                            .foregroundColor(.gray)
                    }
                    .padding(.top, 20)
                    
                    // Goal Cards
                    VStack(spacing: 16) {
                        NutritionGoalCard(
                            icon: "flame.fill",
                            iconColor: .black,
                            title: "Kalorier",
                            value: $caloriesGoal,
                            unit: "kcal",
                            range: 1000...5000,
                            step: 50
                        )
                        
                        NutritionGoalCard(
                            icon: "drop.fill",
                            iconColor: .red,
                            title: "Protein",
                            value: $proteinGoal,
                            unit: "g",
                            range: 50...300,
                            step: 5
                        )
                        
                        NutritionGoalCard(
                            icon: "leaf.fill",
                            iconColor: .orange,
                            title: "Kolhydrater",
                            value: $carbsGoal,
                            unit: "g",
                            range: 50...500,
                            step: 10
                        )
                        
                        NutritionGoalCard(
                            icon: "drop.fill",
                            iconColor: .blue,
                            title: "Fett",
                            value: $fatGoal,
                            unit: "g",
                            range: 30...200,
                            step: 5
                        )
                    }
                    .padding(.horizontal, 20)
                    
                    // Save Button
                    Button {
                        saveGoals()
                    } label: {
                        if isSaving {
                            ProgressView()
                                .tint(.white)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 18)
                                .background(Color.black)
                                .clipShape(Capsule())
                        } else {
                            Text("Spara ändringar")
                                .font(.system(size: 18, weight: .semibold))
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 18)
                                .background(Color.black)
                                .clipShape(Capsule())
                        }
                    }
                    .disabled(isSaving)
                    .padding(.horizontal, 20)
                    .padding(.top, 8)
                    
                    Spacer().frame(height: 40)
                }
            }
            .background(Color(.systemGray6))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Avbryt") {
                        dismiss()
                    }
                    .foregroundColor(.black)
                }
            }
        }
        .onAppear {
            loadCurrentGoals()
        }
    }
    
    private func loadCurrentGoals() {
        // Load from NutritionGoalsManager (user-specific)
        guard let userId = authViewModel.currentUser?.id else { return }
        
        if let goals = NutritionGoalsManager.shared.loadGoals(userId: userId) {
            caloriesGoal = goals.calories > 0 ? goals.calories : 2000
            proteinGoal = goals.protein > 0 ? goals.protein : 150
            carbsGoal = goals.carbs > 0 ? goals.carbs : 250
            fatGoal = goals.fat > 0 ? goals.fat : 70
        }
    }
    
    private func saveGoals() {
        isSaving = true
        
        // Save locally (user-specific)
        if let userId = authViewModel.currentUser?.id {
            NutritionGoalsManager.shared.saveGoals(
                calories: caloriesGoal,
                protein: proteinGoal,
                carbs: carbsGoal,
                fat: fatGoal,
                userId: userId
            )
        }
        
        // Save to Supabase
        Task {
            if let userId = authViewModel.currentUser?.id {
                let updateData = NutritionProfileUpdate(
                    daily_calories_goal: caloriesGoal,
                    daily_protein_goal: proteinGoal,
                    daily_carbs_goal: carbsGoal,
                    daily_fat_goal: fatGoal,
                    target_weight: nil,
                    height_cm: nil,
                    weight_kg: nil,
                    gender: nil,
                    fitness_goal: nil,
                    workouts_per_week: nil
                )
                
                do {
                    try await SupabaseConfig.supabase
                        .from("profiles")
                        .update(updateData)
                        .eq("id", value: userId)
                        .execute()
                    print("✅ Nutrition goals saved to Supabase")
                } catch {
                    print("⚠️ Failed to save to Supabase: \(error)")
                }
            }
            
            await MainActor.run {
                NotificationCenter.default.post(name: NSNotification.Name("NutritionGoalsUpdated"), object: nil)
                isSaving = false
                dismiss()
            }
        }
    }
}

struct NutritionGoalCard: View {
    let icon: String
    let iconColor: Color
    let title: String
    @Binding var value: Int
    let unit: String
    let range: ClosedRange<Int>
    let step: Int
    
    var body: some View {
        VStack(spacing: 16) {
            HStack {
                Image(systemName: icon)
                    .font(.system(size: 18))
                    .foregroundColor(iconColor)
                
                Text(title)
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(.black)
                
                Spacer()
                
                Text("\(value) \(unit)")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundColor(.black)
            }
            
            HStack(spacing: 16) {
                Button {
                    if value - step >= range.lowerBound {
                        value -= step
                        hapticFeedback()
                    }
                } label: {
                    Image(systemName: "minus.circle.fill")
                        .font(.system(size: 32))
                        .foregroundColor(value > range.lowerBound ? .black : .gray.opacity(0.3))
                }
                .disabled(value <= range.lowerBound)
                
                Slider(
                    value: Binding(
                        get: { Double(value) },
                        set: { value = Int($0) }
                    ),
                    in: Double(range.lowerBound)...Double(range.upperBound),
                    step: Double(step)
                )
                .tint(iconColor)
                
                Button {
                    if value + step <= range.upperBound {
                        value += step
                        hapticFeedback()
                    }
                } label: {
                    Image(systemName: "plus.circle.fill")
                        .font(.system(size: 32))
                        .foregroundColor(value < range.upperBound ? .black : .gray.opacity(0.3))
                }
                .disabled(value >= range.upperBound)
            }
        }
        .padding(20)
        .background(Color.white)
        .cornerRadius(16)
        .shadow(color: Color.black.opacity(0.05), radius: 8, x: 0, y: 2)
    }
    
    private func hapticFeedback() {
        let generator = UIImpactFeedbackGenerator(style: .light)
        generator.impactOccurred()
    }
}

#Preview {
    NutritionSettingsView()
        .environmentObject(AuthViewModel())
}

