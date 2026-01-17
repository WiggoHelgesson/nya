import SwiftUI
import Supabase

struct ManualFoodEntryView: View {
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var authViewModel: AuthViewModel
    
    @State private var foodName: String = ""
    @State private var calories: String = ""
    @State private var protein: String = ""
    @State private var carbs: String = ""
    @State private var fat: String = ""
    @State private var servingSize: String = "1 portion"
    
    @State private var isSaving = false
    @State private var showSuccess = false
    
    var body: some View {
        NavigationStack {
            ZStack {
                // Background
                Color(.systemGroupedBackground)
                    .ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 24) {
                        // Header icon
                        VStack(spacing: 12) {
                            Image(systemName: "pencil.and.list.clipboard")
                                .font(.system(size: 50))
                                .foregroundColor(.black)
                            
                            Text("Lägg till manuellt")
                                .font(.system(size: 24, weight: .bold))
                                .foregroundColor(.black)
                            
                            Text("Fyll i näringsvärden för din mat")
                                .font(.system(size: 15))
                                .foregroundColor(.gray)
                        }
                        .padding(.top, 20)
                        .padding(.bottom, 10)
                        
                        // Input fields
                        VStack(spacing: 16) {
                            // Food name
                            inputField(
                                title: "Namn på maten",
                                placeholder: "T.ex. Hemlagad pasta",
                                text: $foodName,
                                keyboardType: .default
                            )
                            
                            // Serving size
                            inputField(
                                title: "Portionsstorlek",
                                placeholder: "T.ex. 1 portion, 100g",
                                text: $servingSize,
                                keyboardType: .default
                            )
                            
                            Divider()
                                .padding(.vertical, 8)
                            
                            // Calories
                            inputField(
                                title: "Kalorier",
                                placeholder: "0",
                                text: $calories,
                                keyboardType: .numberPad,
                                unit: "kcal",
                                icon: "flame.fill",
                                iconColor: .orange
                            )
                            
                            // Protein
                            inputField(
                                title: "Protein",
                                placeholder: "0",
                                text: $protein,
                                keyboardType: .numberPad,
                                unit: "g",
                                icon: "fish.fill",
                                iconColor: Color(red: 0.85, green: 0.35, blue: 0.35)
                            )
                            
                            // Carbs
                            inputField(
                                title: "Kolhydrater",
                                placeholder: "0",
                                text: $carbs,
                                keyboardType: .numberPad,
                                unit: "g",
                                icon: "leaf.fill",
                                iconColor: Color(red: 0.75, green: 0.55, blue: 0.25)
                            )
                            
                            // Fat
                            inputField(
                                title: "Fett",
                                placeholder: "0",
                                text: $fat,
                                keyboardType: .numberPad,
                                unit: "g",
                                icon: "drop.fill",
                                iconColor: Color(red: 0.35, green: 0.55, blue: 0.8)
                            )
                        }
                        .padding(.horizontal, 20)
                        
                        Spacer(minLength: 100)
                    }
                }
                
                // Bottom button
                VStack {
                    Spacer()
                    
                    Button {
                        saveFood()
                    } label: {
                        HStack {
                            if isSaving {
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                            } else {
                                Image(systemName: "plus.circle.fill")
                                    .font(.system(size: 18))
                                Text("Lägg till")
                                    .font(.system(size: 17, weight: .semibold))
                            }
                        }
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(isFormValid ? Color.black : Color.gray)
                        .cornerRadius(14)
                    }
                    .disabled(!isFormValid || isSaving)
                    .padding(.horizontal, 20)
                    .padding(.bottom, 30)
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(.black)
                            .frame(width: 36, height: 36)
                            .background(Color.gray.opacity(0.12))
                            .clipShape(Circle())
                    }
                }
            }
            .alert("Tillagt!", isPresented: $showSuccess) {
                Button("OK") {
                    dismiss()
                }
            } message: {
                Text("\(foodName) har lagts till i din dagbok.")
            }
        }
    }
    
    private var isFormValid: Bool {
        !foodName.trimmingCharacters(in: .whitespaces).isEmpty &&
        (Int(calories) ?? 0) > 0
    }
    
    private func inputField(
        title: String,
        placeholder: String,
        text: Binding<String>,
        keyboardType: UIKeyboardType,
        unit: String? = nil,
        icon: String? = nil,
        iconColor: Color = .black
    ) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                if let icon = icon {
                    Image(systemName: icon)
                        .font(.system(size: 14))
                        .foregroundColor(iconColor)
                }
                Text(title)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.gray)
            }
            
            HStack {
                TextField(placeholder, text: text)
                    .font(.system(size: 17))
                    .keyboardType(keyboardType)
                
                if let unit = unit {
                    Text(unit)
                        .font(.system(size: 15))
                        .foregroundColor(.gray)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .background(Color.white)
            .cornerRadius(12)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Color.gray.opacity(0.2), lineWidth: 1)
            )
        }
    }
    
    private func saveFood() {
        guard let userId = authViewModel.currentUser?.id else {
            print("❌ No user logged in")
            return
        }
        
        isSaving = true
        
        Task {
            do {
                let entry = ManualFoodLogInsert(
                    id: UUID().uuidString,
                    userId: userId,
                    name: foodName.trimmingCharacters(in: .whitespaces),
                    calories: Int(calories) ?? 0,
                    protein: Int(protein) ?? 0,
                    carbs: Int(carbs) ?? 0,
                    fat: Int(fat) ?? 0,
                    mealType: "snack",
                    loggedAt: ISO8601DateFormatter().string(from: Date()),
                    imageUrl: nil
                )
                
                try await SupabaseConfig.supabase
                    .from("food_logs")
                    .insert(entry)
                    .execute()
                
                print("✅ Manual food added: \(foodName)")
                
                await MainActor.run {
                    isSaving = false
                    NotificationCenter.default.post(name: NSNotification.Name("RefreshFoodLogs"), object: nil)
                    showSuccess = true
                }
            } catch {
                print("❌ Error saving manual food: \(error)")
                await MainActor.run {
                    isSaving = false
                }
            }
        }
    }
}

struct ManualFoodLogInsert: Codable {
    let id: String
    let userId: String
    let name: String
    let calories: Int
    let protein: Int
    let carbs: Int
    let fat: Int
    let mealType: String
    let loggedAt: String
    let imageUrl: String?
    
    enum CodingKeys: String, CodingKey {
        case id, name, calories, protein, carbs, fat
        case userId = "user_id"
        case mealType = "meal_type"
        case loggedAt = "logged_at"
        case imageUrl = "image_url"
    }
}

#Preview {
    ManualFoodEntryView()
        .environmentObject(AuthViewModel())
}

