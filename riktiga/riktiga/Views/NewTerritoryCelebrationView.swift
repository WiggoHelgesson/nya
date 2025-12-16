import SwiftUI
import MapKit

struct NewTerritoryCelebrationView: View {
    let territory: Territory
    let onComplete: () -> Void
    let onFocusMap: (MKCoordinateRegion) -> Void
    
    @State private var show = false
    
    var body: some View {
        ZStack {
            Color.black.opacity(0.5)
                .ignoresSafeArea()
                .onTapGesture { onComplete() }
            
            VStack(spacing: 16) {
                Text("Nytt område!")
                    .font(.system(size: 28, weight: .black))
                    .foregroundColor(.white)
                
                Text("Du har tagit över ett område.")
                    .foregroundColor(.white.opacity(0.8))
                
                Button {
                    // Focus map roughly at first polygon centroid
                    if let first = territory.polygons.first, let centroid = centroidOf(first) {
                        let region = MKCoordinateRegion(
                            center: centroid,
                            span: MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01)
                        )
                        onFocusMap(region)
                    }
                    onComplete()
                } label: {
                    Text("Visa på kartan")
                        .font(.system(size: 15, weight: .bold))
                        .padding(.horizontal, 20)
                        .padding(.vertical, 10)
                        .background(Color.white)
                        .foregroundColor(.black)
                        .clipShape(Capsule())
                }
                
                Button("Stäng") {
                    onComplete()
                }
                .foregroundColor(.white.opacity(0.8))
            }
            .padding(24)
            .background(Color.black.opacity(0.65))
            .cornerRadius(20)
            .scaleEffect(show ? 1 : 0.9)
            .opacity(show ? 1 : 0)
            .onAppear {
                withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
                    show = true
                }
            }
        }
    }
    
    private func centroidOf(_ coords: [CLLocationCoordinate2D]) -> CLLocationCoordinate2D? {
        guard !coords.isEmpty else { return nil }
        var x = 0.0, y = 0.0
        for c in coords {
            x += c.latitude
            y += c.longitude
        }
        let count = Double(coords.count)
        return CLLocationCoordinate2D(latitude: x / count, longitude: y / count)
    }
}

#Preview {
    let sample = Territory(
        id: UUID(),
        ownerId: "demo",
        activity: .running,
        area: 1000,
        polygons: [[
            CLLocationCoordinate2D(latitude: 59.0, longitude: 18.0),
            CLLocationCoordinate2D(latitude: 59.001, longitude: 18.0),
            CLLocationCoordinate2D(latitude: 59.001, longitude: 18.001),
            CLLocationCoordinate2D(latitude: 59.0, longitude: 18.001),
            CLLocationCoordinate2D(latitude: 59.0, longitude: 18.0)
        ]],
        sessionDistance: nil,
        sessionDuration: nil,
        sessionPace: nil,
        createdAt: nil
    )
    return NewTerritoryCelebrationView(
        territory: sample,
        onComplete: {},
        onFocusMap: { _ in }
    )
}

