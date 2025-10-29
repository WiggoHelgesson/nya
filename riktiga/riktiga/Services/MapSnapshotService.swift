import Foundation
import MapKit
import CoreLocation

class MapSnapshotService {
    static let shared = MapSnapshotService()
    
    private init() {}
    
    func generateRouteSnapshot(routeCoordinates: [CLLocationCoordinate2D], completion: @escaping (UIImage?) -> Void) {
        // Always create a snapshot, even if there are no coordinates
        let hasCoordinates = routeCoordinates.count > 1
        
        // Calculate bounding box for the route (or use default location)
        let boundingBox: (center: CLLocationCoordinate2D, latitudeDelta: CLLocationDegrees, longitudeDelta: CLLocationDegrees)
        
        if hasCoordinates {
            boundingBox = calculateBoundingBox(for: routeCoordinates)
        } else {
            // Use default location (Stockholm) if no coordinates
            print("⚠️ No route coordinates, using default location for map snapshot")
            boundingBox = (
                center: CLLocationCoordinate2D(latitude: 59.3293, longitude: 18.0686),
                latitudeDelta: 0.01,
                longitudeDelta: 0.01
            )
        }
        
        // Create options for snapshot
        let options = MKMapSnapshotter.Options()
        options.region = MKCoordinateRegion(
            center: boundingBox.center,
            span: MKCoordinateSpan(
                latitudeDelta: boundingBox.latitudeDelta,
                longitudeDelta: boundingBox.longitudeDelta
            )
        )
        options.size = CGSize(width: 800, height: 600)
        options.scale = UIScreen.main.scale
        options.mapType = .standard
        
        let snapshotter = MKMapSnapshotter(options: options)
        
        snapshotter.start { snapshot, error in
            if let error = error {
                print("❌ Error generating map snapshot: \(error)")
                completion(nil)
                return
            }
            
            guard let snapshot = snapshot else {
                print("❌ No snapshot returned")
                completion(nil)
                return
            }
            
            // Draw the route on the snapshot
            let image = self.drawRoute(on: snapshot, with: routeCoordinates)
            completion(image)
        }
    }
    
    private func calculateBoundingBox(for coordinates: [CLLocationCoordinate2D]) -> (center: CLLocationCoordinate2D, latitudeDelta: CLLocationDegrees, longitudeDelta: CLLocationDegrees) {
        var minLat = coordinates.first!.latitude
        var maxLat = coordinates.first!.latitude
        var minLon = coordinates.first!.longitude
        var maxLon = coordinates.first!.longitude
        
        for coordinate in coordinates {
            minLat = min(minLat, coordinate.latitude)
            maxLat = max(maxLat, coordinate.latitude)
            minLon = min(minLon, coordinate.longitude)
            maxLon = max(maxLon, coordinate.longitude)
        }
        
        let center = CLLocationCoordinate2D(
            latitude: (minLat + maxLat) / 2,
            longitude: (minLon + maxLon) / 2
        )
        
        let latitudeDelta = max(maxLat - minLat, 0.001) * 1.3 // Add 30% padding
        let longitudeDelta = max(maxLon - minLon, 0.001) * 1.3 // Add 30% padding
        
        return (center: center, latitudeDelta: latitudeDelta, longitudeDelta: longitudeDelta)
    }
    
    private func drawRoute(on snapshot: MKMapSnapshotter.Snapshot, with coordinates: [CLLocationCoordinate2D]) -> UIImage {
        let image = snapshot.image
        
        return image.withRenderer { context in
            // Draw the base map
            image.draw(at: .zero)
            
            // Only draw route if we have coordinates
            guard coordinates.count > 1 else {
                return
            }
            
            // Set up drawing attributes
            context.setLineWidth(4)
            context.setLineCap(.round)
            context.setLineJoin(.round)
            context.setStrokeColor(UIColor.brandBlue.cgColor)
            
            // Draw the route line
            let path = CGMutablePath()
            
            for (index, coordinate) in coordinates.enumerated() {
                let point = snapshot.point(for: coordinate)
                
                if index == 0 {
                    path.move(to: point)
                } else {
                    path.addLine(to: point)
                }
            }
            
            context.addPath(path)
            context.strokePath()
            
            // Draw start point (green)
            if let firstCoordinate = coordinates.first {
                let startPoint = snapshot.point(for: firstCoordinate)
                context.setFillColor(UIColor.green.cgColor)
                context.fillEllipse(in: CGRect(x: startPoint.x - 6, y: startPoint.y - 6, width: 12, height: 12))
            }
            
            // Draw end point (red)
            if let lastCoordinate = coordinates.last {
                let endPoint = snapshot.point(for: lastCoordinate)
                context.setFillColor(UIColor.red.cgColor)
                context.fillEllipse(in: CGRect(x: endPoint.x - 6, y: endPoint.y - 6, width: 12, height: 12))
            }
        }
    }
}

// Extension to add withRenderer
extension UIImage {
    func withRenderer(_ closure: (CGContext) -> Void) -> UIImage {
        let format = UIGraphicsImageRendererFormat()
        format.scale = scale
        format.opaque = false
        
        return UIGraphicsImageRenderer(size: size, format: format).image { context in
            draw(at: .zero)
            closure(context.cgContext)
        }
    }
}

// MARK: - UIColor Extension for AppColors
extension UIColor {
    static var brandBlue: UIColor {
        return UIColor(red: 0.0, green: 0.478, blue: 1.0, alpha: 1.0)
    }
}

