import SwiftUI
import PhotosUI

struct SessionCompleteView: View {
    let activity: ActivityType
    let distance: Double
    let duration: Int
    let calories: Int
    @Binding var showSessionComplete: Bool
    @Binding var isPresented: Bool
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var authViewModel: AuthViewModel
    
    @State private var title: String = ""
    @State private var description: String = ""
    @State private var sessionImage: UIImage?
    @State private var selectedItem: PhotosPickerItem?
    @State private var isSaving = false
    
    var body: some View {
        ZStack {
            Color(.systemBackground).ignoresSafeArea()
            
            VStack(spacing: 0) {
                HStack {
                    Button(action: {
                        showSessionComplete = false
                    }) {
                        Image(systemName: "chevron.left")
                            .foregroundColor(.black)
                    }
                    Spacer()
                    Text("Slutför pass")
                        .font(.headline)
                    Spacer()
                    Button(action: {}) {
                        Image(systemName: "xmark")
                            .foregroundColor(.black)
                    }
                }
                .padding(16)
                
                ScrollView {
                    VStack(spacing: 20) {
                        ActivitySummaryCard(activity: activity, distance: distance, duration: duration)
                        
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Rubrik")
                                .font(.headline)
                            TextField("Ge ditt pass en titel", text: $title)
                                .padding(12)
                                .background(Color(.systemGray6))
                                .cornerRadius(8)
                        }
                        .padding(.horizontal, 16)
                        
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Beskrivning")
                                .font(.headline)
                            TextEditor(text: $description)
                                .frame(height: 100)
                                .padding(8)
                                .background(Color(.systemGray6))
                                .cornerRadius(8)
                        }
                        .padding(.horizontal, 16)
                        
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Bild")
                                .font(.headline)
                            
                            if let sessionImage = sessionImage {
                                Image(uiImage: sessionImage)
                                    .resizable()
                                    .scaledToFill()
                                    .frame(height: 200)
                                    .cornerRadius(8)
                                    .clipped()
                            } else {
                                PhotosPicker(selection: $selectedItem, matching: .images) {
                                    VStack(spacing: 12) {
                                        Image(systemName: "photo.on.rectangle")
                                            .font(.system(size: 32))
                                            .foregroundColor(.gray)
                                        Text("Lägg till bild")
                                            .foregroundColor(.gray)
                                    }
                                    .frame(maxWidth: .infinity)
                                    .frame(height: 150)
                                    .background(Color(.systemGray6))
                                    .cornerRadius(8)
                                }
                            }
                        }
                        .padding(.horizontal, 16)
                        
                        Button(action: saveWorkout) {
                            if isSaving {
                                ProgressView()
                                    .tint(.white)
                            } else {
                                Text("Spara pass")
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .padding(14)
                        .background(Color.black)
                        .foregroundColor(.white)
                        .cornerRadius(25)
                        .font(.headline)
                        .disabled(isSaving || title.isEmpty)
                        .padding(16)
                    }
                }
            }
        }
        .onChange(of: selectedItem) { oldValue, newValue in
            Task {
                if let data = try? await newValue?.loadTransferable(type: Data.self) {
                    if let uiImage = UIImage(data: data) {
                        sessionImage = uiImage
                    }
                }
            }
        }
    }
    
    func saveWorkout() {
        isSaving = true
        
        // Konvertera bild till base64
        var imageBase64: String? = nil
        if let image = sessionImage, let imageData = image.jpegData(compressionQuality: 0.7) {
            imageBase64 = imageData.base64EncodedString()
        }
        
        let post = WorkoutPost(
            userId: authViewModel.currentUser?.id ?? "",
            activityType: activity.rawValue,
            title: title,
            description: description,
            distance: distance,
            duration: duration,
            calories: calories,
            imageData: imageBase64
        )
        
        Task {
            do {
                try await WorkoutService.shared.saveWorkoutPost(post)
                print("✅ Workout saved successfully")
                
                DispatchQueue.main.async {
                    isSaving = false
                    showSessionComplete = false
                    isPresented = true
                    dismiss()
                }
            } catch {
                print("❌ Error saving workout: \(error)")
                DispatchQueue.main.async {
                    isSaving = false
                }
            }
        }
    }
}

struct ActivitySummaryCard: View {
    let activity: ActivityType
    let distance: Double
    let duration: Int
    
    var body: some View {
        HStack {
            Image(systemName: activity.icon)
                .font(.system(size: 24))
                .foregroundColor(Color(red: 0.1, green: 0.6, blue: 0.8))
            
            VStack(alignment: .leading, spacing: 4) {
                Text(activity.rawValue)
                    .font(.headline)
                Text(String(format: "%.2f km • %@", distance, formattedDuration(duration)))
                    .font(.caption)
                    .foregroundColor(.gray)
            }
            
            Spacer()
        }
        .padding(16)
        .background(Color(.systemGray6))
        .cornerRadius(12)
        .padding(.horizontal, 16)
    }
    
    func formattedDuration(_ seconds: Int) -> String {
        let hours = seconds / 3600
        let minutes = (seconds % 3600) / 60
        if hours > 0 {
            return String(format: "%dh %dm", hours, minutes)
        } else {
            return String(format: "%dm", minutes)
        }
    }
}

#Preview {
    SessionCompleteView(activity: .running, distance: 5.2, duration: 1800, calories: 300, showSessionComplete: .constant(true), isPresented: .constant(false))
        .environmentObject(AuthViewModel())
}
