import Foundation
import MapKit
import CoreLocation

class MapSnapshotService {
    static let shared = MapSnapshotService()
    
    private init() {}
    
    func generateRouteSnapshot(routeCoordinates: [CLLocationCoordinate2D], userLocation: CLLocationCoordinate2D?, activity: ActivityType? = nil, completion: @escaping (UIImage?) -> Void) {
        // Always create a snapshot, even if there are no coordinates
        let hasCoordinates = routeCoordinates.count > 1
        
        // Calculate bounding box for the route (or use user's current location)
        let boundingBox: (center: CLLocationCoordinate2D, latitudeDelta: CLLocationDegrees, longitudeDelta: CLLocationDegrees)
        
        if hasCoordinates {
            boundingBox = calculateBoundingBox(for: routeCoordinates)
        } else if let userLocation = userLocation {
            // Use user's actual current location if no route coordinates
            print("✅ No route coordinates, using user's current location for map snapshot")
            boundingBox = (
                center: userLocation,
                latitudeDelta: 0.01,
                longitudeDelta: 0.01
            )
        } else {
            // Fallback to default location (Stockholm) only if user location is also unavailable
            print("⚠️ No route coordinates or user location, using default location for map snapshot")
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
            
            // Determine if we should fill the polygon based on activity
            let shouldFill: Bool
            if let activity = activity {
                switch activity {
                case .running, .golf, .hiking, .skiing:
                    shouldFill = true
                default:
                    shouldFill = false
                }
            } else {
                shouldFill = false
            }
            
            // Draw the route on the snapshot
            let image = self.drawRoute(on: snapshot, with: routeCoordinates, shouldFill: shouldFill, activity: activity)
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
    
    private func drawRoute(on snapshot: MKMapSnapshotter.Snapshot, with coordinates: [CLLocationCoordinate2D], shouldFill: Bool, activity: ActivityType?) -> UIImage {
        let image = snapshot.image
        
        return image.withRenderer { context in
            // Draw the base map
            image.draw(at: .zero)
            
            // Only draw route if we have coordinates
            guard coordinates.count > 1 else {
                return
            }
            
            // If filling polygon (territory mode)
            if shouldFill {
                let fillBaseColor = activity?.territoryUIColor ?? UIColor.systemGreen
                context.saveGState()
                
                let fillPath = CGMutablePath()
                
                // Convert all coordinates to points
                var points: [CGPoint] = []
                for coordinate in coordinates {
                    points.append(snapshot.point(for: coordinate))
                }
                
                // Close the loop back to start for the fill
                if let firstCoordinate = coordinates.first {
                    points.append(snapshot.point(for: firstCoordinate))
                }
                
                // Create path from points
                if let first = points.first {
                    fillPath.move(to: first)
                    for point in points.dropFirst() {
                        fillPath.addLine(to: point)
                    }
                    fillPath.closeSubpath()
                }
                
                context.addPath(fillPath)
                
                // Fill with semi-transparent green
                context.setFillColor(fillBaseColor.withAlphaComponent(0.3).cgColor)
                context.fillPath()
                
                // Draw dashed border
                context.addPath(fillPath)
                context.setLineWidth(2)
                context.setLineCap(.round)
                context.setLineJoin(.round)
                context.setStrokeColor(fillBaseColor.cgColor)
                context.setLineDash(phase: 0, lengths: [5, 5])
                context.strokePath()
                
                context.restoreGState()
            }
            
            // Draw the actual route line (solid black)
            context.setLineWidth(4)
            context.setLineCap(.round)
            context.setLineJoin(.round)
            context.setStrokeColor(UIColor.black.cgColor)
            
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
                // White border for start point
                context.setStrokeColor(UIColor.white.cgColor)
                context.setLineWidth(2)
                context.strokeEllipse(in: CGRect(x: startPoint.x - 6, y: startPoint.y - 6, width: 12, height: 12))
            }
            
            // Draw end point (red) - only if not filling (if filling, the whole area is the focus)
            if !shouldFill, let lastCoordinate = coordinates.last {
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

extension ActivityType {
    var territoryUIColor: UIColor {
        switch self {
        case .running:
            return .systemOrange
        case .golf:
            return .systemBlue
        case .skiing:
            return .systemTeal
        case .hiking:
            return .systemBrown
        case .walking:
            return .systemRed
        }
    }
}

