import SwiftUI

struct AdminTrainerApprovalsView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var pending: [GolfTrainer] = []
    @State private var isLoading = false
    @State private var errorMessage: String?
    
    var body: some View {
        NavigationStack {
            Group {
                if isLoading && pending.isEmpty {
                    ProgressView("Laddar ansökningar…")
                } else if let errorMessage = errorMessage {
                    VStack(spacing: 12) {
                        Text("Fel")
                            .font(.headline)
                        Text(errorMessage)
                            .foregroundColor(.secondary)
                        Button("Försök igen") { Task { await load() } }
                            .buttonStyle(.borderedProminent)
                    }
                    .padding()
                } else if pending.isEmpty {
                    Text("Inga väntande ansökningar")
                        .foregroundColor(.secondary)
                } else {
                    List {
                        ForEach(pending) { trainer in
                            AdminTrainerRow(trainer: trainer, onApprove: {
                                Task { await approve(trainer) }
                            }, onReject: {
                                Task { await reject(trainer) }
                            })
                        }
                    }
                }
            }
            .navigationTitle("Admin • Ansökningar")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Stäng") { dismiss() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    if isLoading {
                        ProgressView()
                    } else {
                        Button {
                            Task { await load() }
                        } label: {
                            Image(systemName: "arrow.clockwise")
                        }
                    }
                }
            }
            .task {
                await load()
            }
        }
    }
    
    private func load() async {
        isLoading = true
        errorMessage = nil
        do {
            pending = try await TrainerService.shared.fetchPendingTrainers()
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }
    
    private func approve(_ trainer: GolfTrainer) async {
        do {
            try await TrainerService.shared.approveTrainer(trainerId: trainer.id)
            await load()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
    
    private func reject(_ trainer: GolfTrainer) async {
        do {
            try await TrainerService.shared.rejectTrainer(trainerId: trainer.id)
            await load()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}


private struct AdminTrainerRow: View {
    let trainer: GolfTrainer
    let onApprove: () -> Void
    let onReject: () -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(trainer.name)
                    .font(.headline)
                Spacer()
                Text("\(trainer.hourlyRate) kr/h")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            
            if let city = trainer.city {
                HStack(spacing: 6) {
                    Image(systemName: "mappin.and.ellipse")
                    Text(city)
                }
                .font(.caption)
                .foregroundColor(.secondary)
            }
            
            if let club = trainer.clubAffiliation {
                Text("Klubb: \(club)")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Text(trainer.description)
                .font(.subheadline)
                .lineLimit(2)
            
            HStack(spacing: 12) {
                Button("Godkänn") { onApprove() }
                    .buttonStyle(.borderedProminent)
                Button("Neka", role: .destructive) { onReject() }
                    .buttonStyle(.bordered)
            }
        }
        .padding(.vertical, 6)
    }
}
