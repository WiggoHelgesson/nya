import SwiftUI

struct WorkoutLibraryPopup: View {
    @Binding var isPresented: Bool
    @ObservedObject var viewModel: GymSessionViewModel
    let onSelectWorkout: (SavedGymWorkout) -> Void
    
    var body: some View {
        ZStack {
            // Dimmed background - tap anywhere to dismiss
            Color.black.opacity(0.4)
                .ignoresSafeArea()
                .onTapGesture {
                    withAnimation(.easeOut(duration: 0.2)) {
                        isPresented = false
                    }
                }
            
            // Popup content
            VStack(spacing: 0) {
                // Header with close button
                HStack {
                    Spacer()
                    Button(action: {
                        withAnimation(.easeOut(duration: 0.2)) {
                            isPresented = false
                        }
                    }) {
                        Image(systemName: "xmark")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(.gray)
                            .frame(width: 32, height: 32)
                            .background(Color(.systemGray6))
                            .clipShape(Circle())
                    }
                }
                .padding()
                
                ScrollView {
                    VStack(alignment: .leading, spacing: 24) {
                        // Dina pass section
                        VStack(alignment: .leading, spacing: 16) {
                            Text(L.t(sv: "Dina pass", nb: "Dine økter"))
                                .font(.system(size: 24, weight: .bold))
                                .foregroundColor(.primary)
                            
                            if viewModel.savedWorkouts.isEmpty {
                                Text(L.t(sv: "Du har inga gym rutiner ännu.", nb: "Du har ingen gymrutiner ennå."))
                                    .font(.system(size: 15))
                                    .foregroundColor(.secondary)
                                    .padding(.vertical, 8)
                            } else {
                                VStack(spacing: 12) {
                                    ForEach(viewModel.savedWorkouts) { workout in
                                        Button(action: {
                                            onSelectWorkout(workout)
                                            withAnimation(.easeOut(duration: 0.2)) {
                                                isPresented = false
                                            }
                                        }) {
                                            HStack {
                                                VStack(alignment: .leading, spacing: 4) {
                                                    Text(workout.name)
                                                        .font(.system(size: 16, weight: .semibold))
                                                        .foregroundColor(.primary)
                                                    
                                                    Text(L.t(sv: "\(workout.exercises.count) övningar", nb: "\(workout.exercises.count) øvelser"))
                                                        .font(.system(size: 14))
                                                        .foregroundColor(.secondary)
                                                }
                                                
                                                Spacer()
                                                
                                                Image(systemName: "chevron.right")
                                                    .font(.system(size: 14))
                                                    .foregroundColor(.gray)
                                            }
                                            .padding(16)
                                            .background(Color(.secondarySystemBackground))
                                            .cornerRadius(12)
                                        }
                                        .buttonStyle(PlainButtonStyle())
                                    }
                                }
                            }
                        }
                        
                        // Divider
                        Rectangle()
                            .fill(Color(.systemGray5))
                            .frame(height: 1)
                            .padding(.vertical, 8)
                        
                        // Utforska våra pass section
                        VStack(alignment: .leading, spacing: 16) {
                            Text(L.t(sv: "Utforska våra pass", nb: "Utforsk våre økter"))
                                .font(.system(size: 24, weight: .bold))
                                .foregroundColor(.primary)
                            
                            Text(L.t(sv: "Kommer snart...", nb: "Kommer snart..."))
                                .font(.system(size: 15))
                                .foregroundColor(.secondary)
                                .padding(.vertical, 8)
                            
                            // Placeholder for future predefined workouts
                            // ForEach(predefinedWorkouts) { workout in ... }
                        }
                    }
                    .padding(24)
                }
            }
            .frame(maxWidth: 500)
            .frame(height: UIScreen.main.bounds.height * 0.7)
            .background(Color(.systemBackground))
            .cornerRadius(24)
            .shadow(color: Color.black.opacity(0.3), radius: 20, x: 0, y: 10)
            .padding(.horizontal, 24)
        }
    }
}

