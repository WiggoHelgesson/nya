import SwiftUI

// MARK: - Improved Front Body View med rundare former och 3D-effekt

struct ImprovedFrontBodyView: View {
    let muscleProgress: [MuscleLevel]
    
    var body: some View {
        GeometryReader { geo in
            ZStack {
                let w = geo.size.width
                let h = geo.size.height
                
                // Bröst (Chest) - Rundare form med gradient
                Path { path in
                    // Vänster bröstmuskel
                    path.addEllipse(in: CGRect(x: w * 0.35, y: h * 0.20, width: w * 0.12, height: h * 0.10))
                    // Höger bröstmuskel
                    path.addEllipse(in: CGRect(x: w * 0.53, y: h * 0.20, width: w * 0.12, height: h * 0.10))
                }
                .fill(
                    RadialGradient(
                        colors: [
                            colorForMuscle("Bröst").opacity(0.9),
                            colorForMuscle("Bröst")
                        ],
                        center: .center,
                        startRadius: 5,
                        endRadius: 30
                    )
                )
                .shadow(color: colorForMuscle("Bröst").opacity(0.5), radius: 8, x: 0, y: 0)
                .overlay(
                    Path { path in
                        path.addEllipse(in: CGRect(x: w * 0.35, y: h * 0.20, width: w * 0.12, height: h * 0.10))
                        path.addEllipse(in: CGRect(x: w * 0.53, y: h * 0.20, width: w * 0.12, height: h * 0.10))
                    }
                    .stroke(Color.white.opacity(0.3), lineWidth: 1.5)
                )
                
                // Axlar (Shoulders) - Rundare
                Path { path in
                    // Vänster axel
                    path.addEllipse(in: CGRect(x: w * 0.18, y: h * 0.16, width: w * 0.18, height: h * 0.09))
                    // Höger axel
                    path.addEllipse(in: CGRect(x: w * 0.64, y: h * 0.16, width: w * 0.18, height: h * 0.09))
                }
                .fill(
                    RadialGradient(
                        colors: [
                            colorForMuscle("Axlar").opacity(0.9),
                            colorForMuscle("Axlar")
                        ],
                        center: .center,
                        startRadius: 5,
                        endRadius: 25
                    )
                )
                .shadow(color: colorForMuscle("Axlar").opacity(0.5), radius: 6, x: 0, y: 0)
                .overlay(
                    Path { path in
                        path.addEllipse(in: CGRect(x: w * 0.18, y: h * 0.16, width: w * 0.18, height: h * 0.09))
                        path.addEllipse(in: CGRect(x: w * 0.64, y: h * 0.16, width: w * 0.18, height: h * 0.09))
                    }
                    .stroke(Color.white.opacity(0.3), lineWidth: 1.5)
                )
                
                // Mage (Abs) - Sex-pack med rundare former
                VStack(spacing: 3) {
                    // Övre rad
                    HStack(spacing: 8) {
                        RoundedRectangle(cornerRadius: 6)
                            .fill(
                                LinearGradient(
                                    colors: [
                                        colorForMuscle("Mage").opacity(0.9),
                                        colorForMuscle("Mage")
                                    ],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .frame(width: w * 0.09, height: h * 0.05)
                        
                        RoundedRectangle(cornerRadius: 6)
                            .fill(
                                LinearGradient(
                                    colors: [
                                        colorForMuscle("Mage").opacity(0.9),
                                        colorForMuscle("Mage")
                                    ],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .frame(width: w * 0.09, height: h * 0.05)
                    }
                    
                    // Mellan rad
                    HStack(spacing: 8) {
                        RoundedRectangle(cornerRadius: 6)
                            .fill(
                                LinearGradient(
                                    colors: [
                                        colorForMuscle("Mage").opacity(0.9),
                                        colorForMuscle("Mage")
                                    ],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .frame(width: w * 0.09, height: h * 0.05)
                        
                        RoundedRectangle(cornerRadius: 6)
                            .fill(
                                LinearGradient(
                                    colors: [
                                        colorForMuscle("Mage").opacity(0.9),
                                        colorForMuscle("Mage")
                                    ],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .frame(width: w * 0.09, height: h * 0.05)
                    }
                    
                    // Nedre rad
                    HStack(spacing: 8) {
                        RoundedRectangle(cornerRadius: 6)
                            .fill(
                                LinearGradient(
                                    colors: [
                                        colorForMuscle("Mage").opacity(0.9),
                                        colorForMuscle("Mage")
                                    ],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .frame(width: w * 0.09, height: h * 0.05)
                        
                        RoundedRectangle(cornerRadius: 6)
                            .fill(
                                LinearGradient(
                                    colors: [
                                        colorForMuscle("Mage").opacity(0.9),
                                        colorForMuscle("Mage")
                                    ],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .frame(width: w * 0.09, height: h * 0.05)
                    }
                }
                .shadow(color: colorForMuscle("Mage").opacity(0.5), radius: 5, x: 0, y: 0)
                .position(x: w * 0.5, y: h * 0.42)
                
                // Biceps - Rundare armar
                Path { path in
                    // Vänster bicep
                    path.addEllipse(in: CGRect(x: w * 0.15, y: h * 0.26, width: w * 0.10, height: h * 0.14))
                    // Höger bicep
                    path.addEllipse(in: CGRect(x: w * 0.75, y: h * 0.26, width: w * 0.10, height: h * 0.14))
                }
                .fill(
                    LinearGradient(
                        colors: [
                            colorForMuscle("Biceps").opacity(0.9),
                            colorForMuscle("Biceps")
                        ],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .shadow(color: colorForMuscle("Biceps").opacity(0.5), radius: 5, x: 0, y: 0)
                .overlay(
                    Path { path in
                        path.addEllipse(in: CGRect(x: w * 0.15, y: h * 0.26, width: w * 0.10, height: h * 0.14))
                        path.addEllipse(in: CGRect(x: w * 0.75, y: h * 0.26, width: w * 0.10, height: h * 0.14))
                    }
                    .stroke(Color.white.opacity(0.3), lineWidth: 1.5)
                )
                
                // Ben (Quads) - Rundare lår
                Path { path in
                    // Vänster lår
                    path.addEllipse(in: CGRect(x: w * 0.32, y: h * 0.54, width: w * 0.14, height: h * 0.26))
                    // Höger lår
                    path.addEllipse(in: CGRect(x: w * 0.54, y: h * 0.54, width: w * 0.14, height: h * 0.26))
                }
                .fill(
                    LinearGradient(
                        colors: [
                            colorForMuscle("Ben").opacity(0.9),
                            colorForMuscle("Ben")
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .shadow(color: colorForMuscle("Ben").opacity(0.5), radius: 6, x: 0, y: 0)
                .overlay(
                    Path { path in
                        path.addEllipse(in: CGRect(x: w * 0.32, y: h * 0.54, width: w * 0.14, height: h * 0.26))
                        path.addEllipse(in: CGRect(x: w * 0.54, y: h * 0.54, width: w * 0.14, height: h * 0.26))
                    }
                    .stroke(Color.white.opacity(0.3), lineWidth: 1.5)
                )
                
                // Vader (Calves) - Rundare
                Path { path in
                    // Vänster vad
                    path.addEllipse(in: CGRect(x: w * 0.34, y: h * 0.82, width: w * 0.10, height: h * 0.12))
                    // Höger vad
                    path.addEllipse(in: CGRect(x: w * 0.56, y: h * 0.82, width: w * 0.10, height: h * 0.12))
                }
                .fill(
                    LinearGradient(
                        colors: [
                            colorForMuscle("Vader").opacity(0.9),
                            colorForMuscle("Vader")
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .shadow(color: colorForMuscle("Vader").opacity(0.4), radius: 4, x: 0, y: 0)
                .overlay(
                    Path { path in
                        path.addEllipse(in: CGRect(x: w * 0.34, y: h * 0.82, width: w * 0.10, height: h * 0.12))
                        path.addEllipse(in: CGRect(x: w * 0.56, y: h * 0.82, width: w * 0.10, height: h * 0.12))
                    }
                    .stroke(Color.white.opacity(0.3), lineWidth: 1.5)
                )
                
                // Huvud (outline)
                Circle()
                    .stroke(
                        LinearGradient(
                            colors: [Color.white.opacity(0.5), Color.white.opacity(0.2)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 2
                    )
                    .frame(width: w * 0.18, height: w * 0.18)
                    .position(x: w * 0.5, y: h * 0.09)
            }
        }
    }
    
    private func colorForMuscle(_ muscleName: String) -> Color {
        if let muscle = muscleProgress.first(where: { $0.muscleGroup == muscleName }) {
            let color = muscle.color
            let baseColor = Color(red: color.red, green: color.green, blue: color.blue)
            
            // Add glow for high levels
            if muscle.currentLevel >= 80 {
                return baseColor
            }
            return baseColor
        }
        return Color.gray.opacity(0.3)
    }
}

// MARK: - Improved Back Body View

struct ImprovedBackBodyView: View {
    let muscleProgress: [MuscleLevel]
    
    var body: some View {
        GeometryReader { geo in
            ZStack {
                let w = geo.size.width
                let h = geo.size.height
                
                // Rygg (Back) - Stor V-form med gradient
                Path { path in
                    // Övre rygg (trapezius och lats)
                    path.move(to: CGPoint(x: w * 0.35, y: h * 0.18))
                    path.addLine(to: CGPoint(x: w * 0.65, y: h * 0.18))
                    path.addQuadCurve(
                        to: CGPoint(x: w * 0.58, y: h * 0.45),
                        control: CGPoint(x: w * 0.70, y: h * 0.32)
                    )
                    path.addLine(to: CGPoint(x: w * 0.42, y: h * 0.45))
                    path.addQuadCurve(
                        to: CGPoint(x: w * 0.35, y: h * 0.18),
                        control: CGPoint(x: w * 0.30, y: h * 0.32)
                    )
                }
                .fill(
                    LinearGradient(
                        colors: [
                            colorForMuscle("Rygg").opacity(0.9),
                            colorForMuscle("Rygg")
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .shadow(color: colorForMuscle("Rygg").opacity(0.6), radius: 10, x: 0, y: 0)
                .overlay(
                    Path { path in
                        path.move(to: CGPoint(x: w * 0.35, y: h * 0.18))
                        path.addLine(to: CGPoint(x: w * 0.65, y: h * 0.18))
                        path.addQuadCurve(
                            to: CGPoint(x: w * 0.58, y: h * 0.45),
                            control: CGPoint(x: w * 0.70, y: h * 0.32)
                        )
                        path.addLine(to: CGPoint(x: w * 0.42, y: h * 0.45))
                        path.addQuadCurve(
                            to: CGPoint(x: w * 0.35, y: h * 0.18),
                            control: CGPoint(x: w * 0.30, y: h * 0.32)
                        )
                    }
                    .stroke(Color.white.opacity(0.3), lineWidth: 1.5)
                )
                
                // Axlar (baksida) - Rundare
                Path { path in
                    path.addEllipse(in: CGRect(x: w * 0.18, y: h * 0.16, width: w * 0.18, height: h * 0.09))
                    path.addEllipse(in: CGRect(x: w * 0.64, y: h * 0.16, width: w * 0.18, height: h * 0.09))
                }
                .fill(
                    RadialGradient(
                        colors: [
                            colorForMuscle("Axlar").opacity(0.9),
                            colorForMuscle("Axlar")
                        ],
                        center: .center,
                        startRadius: 5,
                        endRadius: 25
                    )
                )
                .shadow(color: colorForMuscle("Axlar").opacity(0.5), radius: 6, x: 0, y: 0)
                .overlay(
                    Path { path in
                        path.addEllipse(in: CGRect(x: w * 0.18, y: h * 0.16, width: w * 0.18, height: h * 0.09))
                        path.addEllipse(in: CGRect(x: w * 0.64, y: h * 0.16, width: w * 0.18, height: h * 0.09))
                    }
                    .stroke(Color.white.opacity(0.3), lineWidth: 1.5)
                )
                
                // Triceps - Rundare armar
                Path { path in
                    path.addEllipse(in: CGRect(x: w * 0.15, y: h * 0.26, width: w * 0.10, height: h * 0.14))
                    path.addEllipse(in: CGRect(x: w * 0.75, y: h * 0.26, width: w * 0.10, height: h * 0.14))
                }
                .fill(
                    LinearGradient(
                        colors: [
                            colorForMuscle("Triceps").opacity(0.9),
                            colorForMuscle("Triceps")
                        ],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .shadow(color: colorForMuscle("Triceps").opacity(0.5), radius: 5, x: 0, y: 0)
                .overlay(
                    Path { path in
                        path.addEllipse(in: CGRect(x: w * 0.15, y: h * 0.26, width: w * 0.10, height: h * 0.14))
                        path.addEllipse(in: CGRect(x: w * 0.75, y: h * 0.26, width: w * 0.10, height: h * 0.14))
                    }
                    .stroke(Color.white.opacity(0.3), lineWidth: 1.5)
                )
                
                // Rumpa (Glutes) - Rundare
                Path { path in
                    path.addEllipse(in: CGRect(x: w * 0.35, y: h * 0.46, width: w * 0.30, height: h * 0.12))
                }
                .fill(
                    RadialGradient(
                        colors: [
                            colorForMuscle("Rumpa").opacity(0.9),
                            colorForMuscle("Rumpa")
                        ],
                        center: .center,
                        startRadius: 10,
                        endRadius: 40
                    )
                )
                .shadow(color: colorForMuscle("Rumpa").opacity(0.5), radius: 6, x: 0, y: 0)
                .overlay(
                    Path { path in
                        path.addEllipse(in: CGRect(x: w * 0.35, y: h * 0.46, width: w * 0.30, height: h * 0.12))
                    }
                    .stroke(Color.white.opacity(0.3), lineWidth: 1.5)
                )
                
                // Ben (Hamstrings baksida) - Rundare
                Path { path in
                    path.addEllipse(in: CGRect(x: w * 0.32, y: h * 0.60, width: w * 0.14, height: h * 0.20))
                    path.addEllipse(in: CGRect(x: w * 0.54, y: h * 0.60, width: w * 0.14, height: h * 0.20))
                }
                .fill(
                    LinearGradient(
                        colors: [
                            colorForMuscle("Ben").opacity(0.9),
                            colorForMuscle("Ben")
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .shadow(color: colorForMuscle("Ben").opacity(0.5), radius: 6, x: 0, y: 0)
                .overlay(
                    Path { path in
                        path.addEllipse(in: CGRect(x: w * 0.32, y: h * 0.60, width: w * 0.14, height: h * 0.20))
                        path.addEllipse(in: CGRect(x: w * 0.54, y: h * 0.60, width: w * 0.14, height: h * 0.20))
                    }
                    .stroke(Color.white.opacity(0.3), lineWidth: 1.5)
                )
                
                // Vader (Calves baksida) - Rundare
                Path { path in
                    path.addEllipse(in: CGRect(x: w * 0.34, y: h * 0.82, width: w * 0.10, height: h * 0.12))
                    path.addEllipse(in: CGRect(x: w * 0.56, y: h * 0.82, width: w * 0.10, height: h * 0.12))
                }
                .fill(
                    LinearGradient(
                        colors: [
                            colorForMuscle("Vader").opacity(0.9),
                            colorForMuscle("Vader")
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .shadow(color: colorForMuscle("Vader").opacity(0.4), radius: 4, x: 0, y: 0)
                .overlay(
                    Path { path in
                        path.addEllipse(in: CGRect(x: w * 0.34, y: h * 0.82, width: w * 0.10, height: h * 0.12))
                        path.addEllipse(in: CGRect(x: w * 0.56, y: h * 0.82, width: w * 0.10, height: h * 0.12))
                    }
                    .stroke(Color.white.opacity(0.3), lineWidth: 1.5)
                )
                
                // Huvud (outline)
                Circle()
                    .stroke(
                        LinearGradient(
                            colors: [Color.white.opacity(0.5), Color.white.opacity(0.2)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 2
                    )
                    .frame(width: w * 0.18, height: w * 0.18)
                    .position(x: w * 0.5, y: h * 0.09)
            }
        }
    }
    
    private func colorForMuscle(_ muscleName: String) -> Color {
        if let muscle = muscleProgress.first(where: { $0.muscleGroup == muscleName }) {
            let color = muscle.color
            return Color(red: color.red, green: color.green, blue: color.blue)
        }
        return Color.gray.opacity(0.3)
    }
}















