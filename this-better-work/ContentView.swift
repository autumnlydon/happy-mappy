import SwiftUI
import MapKit
import CoreLocation

// Step 1: Define a custom wrapper for CLLocationCoordinate2D that conforms to Equatable
struct EquatableLocation: Equatable {
    var coordinate: CLLocationCoordinate2D

    static func == (lhs: EquatableLocation, rhs: EquatableLocation) -> Bool {
        return lhs.coordinate.latitude == rhs.coordinate.latitude &&
               lhs.coordinate.longitude == rhs.coordinate.longitude
    }
}

// Step 2: Implement the LocationManager class to handle location updates
class LocationManager: NSObject, ObservableObject, CLLocationManagerDelegate {
    private let manager = CLLocationManager()
    @Published var userLocation: EquatableLocation?

    override init() {
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyBest
        manager.requestWhenInUseAuthorization()
        manager.startUpdatingLocation()
    }

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        if let location = locations.last {
            DispatchQueue.main.async {
                self.userLocation = EquatableLocation(coordinate: location.coordinate)
            }
        }
    }
}

// Step 3: Define the ContentView struct
struct ContentView: View {
    @StateObject private var locationManager = LocationManager()
    @State private var region = MKCoordinateRegion(
        center: CLLocationCoordinate2D(latitude: 40.7128, longitude: -74.0060),
        span: MKCoordinateSpan(latitudeDelta: 0.05, longitudeDelta: 0.05)
    )
    @State private var overlays: [MKOverlay] = []
    @State private var annotations: [MKAnnotation] = []

    var body: some View {
        MapView(region: $region, overlays: $overlays, annotations: $annotations)
            .edgesIgnoringSafeArea(.all)
            .overlay(
                MapUserLocationButton()
                    .padding()
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
            )
            .onAppear {
                loadCountyBoundaries()
            }
            .onChange(of: locationManager.userLocation) { newLocation in
                if let location = newLocation {
                    updateRegion(for: location.coordinate)
                    updateCurrentCounty(for: location.coordinate)
                }
            }
    }

    // Step 4: Load county boundaries from a GeoJSON file
    func loadCountyBoundaries() {
        print("Starting to load county boundaries...")
        
        guard let url = Bundle.main.url(forResource: "counties", withExtension: "geojson") else {
            print("❌ Failed to find counties.geojson in bundle")
            return
        }
        
        print("Found GeoJSON file at: \(url.path)")
        
        do {
            let data = try Data(contentsOf: url)
            print("Successfully loaded GeoJSON data: \(data.count) bytes")
            
            let decoder = MKGeoJSONDecoder()
            let features = try decoder.decode(data)
            print("Successfully decoded GeoJSON with \(features.count) features")
            
            var allPolygons: [MKPolygon] = []
            var countyLabels: [CountyLabel] = []
            
            for feature in features {
                guard let geoFeature = feature as? MKGeoJSONFeature,
                      let geometry = geoFeature.geometry.first,
                      let properties = geoFeature.properties,
                      let propertyData = try? JSONSerialization.jsonObject(with: properties) as? [String: Any],
                      let countyName = propertyData["NAME"] as? String else {
                    continue
                }
                
                var polygonsForFeature: [MKPolygon] = []
                if let polygon = geometry as? MKPolygon {
                    polygonsForFeature = [polygon]
                } else if let multiPolygon = geometry as? MKMultiPolygon {
                    polygonsForFeature = multiPolygon.polygons
                }
                
                allPolygons.append(contentsOf: polygonsForFeature)
                
                // Create label for the county
                if let polygon = polygonsForFeature.first {
                    let center = polygon.coordinate
                    let label = CountyLabel(coordinate: center, title: countyName)
                    countyLabels.append(label)
                }
            }
            
            print("Created \(allPolygons.count) polygon overlays")
            overlays = allPolygons
            annotations = countyLabels
            
        } catch {
            print("❌ Error processing GeoJSON: \(error)")
            if let dataString = try? String(contentsOf: url, encoding: .utf8) {
                print("First 200 characters of file: \(String(dataString.prefix(200)))")
            }
        }
    }

    // Step 5: Update the map region based on the user's location
    func updateRegion(for coordinate: CLLocationCoordinate2D) {
        region = MKCoordinateRegion(
            center: coordinate,
            span: MKCoordinateSpan(latitudeDelta: 0.05, longitudeDelta: 0.05)
        )
    }

    // Step 6: Determine the current county based on the user's location
    func updateCurrentCounty(for coordinate: CLLocationCoordinate2D) {
        for overlay in overlays {
            if let polygon = overlay as? MKPolygon {
                let renderer = MKPolygonRenderer(polygon: polygon)
                let mapPoint = MKMapPoint(coordinate)
                let point = renderer.point(for: mapPoint)
                if renderer.path.contains(point) {
                    // User is within this county polygon
                    // Implement logic to render grid cells and track progress
                    break
                }
            }
        }
    }
}

// Step 7: Define the MapView struct using UIViewRepresentable
struct MapView: UIViewRepresentable {
    @Binding var region: MKCoordinateRegion
    @Binding var overlays: [MKOverlay]
    @Binding var annotations: [MKAnnotation]

    func makeUIView(context: Context) -> MKMapView {
        let mapView = MKMapView()
        mapView.delegate = context.coordinator
        mapView.showsUserLocation = true
        mapView.setRegion(region, animated: false)
        return mapView
    }

    func updateUIView(_ mapView: MKMapView, context: Context) {
        mapView.setRegion(region, animated: true)
        mapView.removeOverlays(mapView.overlays)
        mapView.removeAnnotations(mapView.annotations)
        mapView.addOverlays(overlays)
        mapView.addAnnotations(annotations)
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    class Coordinator: NSObject, MKMapViewDelegate {
        var parent: MapView

        init(_ parent: MapView) {
            self.parent = parent
        }

        func mapView(_ mapView: MKMapView, rendererFor overlay: MKOverlay) -> MKOverlayRenderer {
            if let polygon = overlay as? MKPolygon {
                let renderer = MKPolygonRenderer(polygon: polygon)
                renderer.strokeColor = .black
                renderer.lineWidth = 1
                renderer.fillColor = .clear
                return renderer
            }
            return MKOverlayRenderer(overlay: overlay)
        }
    }
}

// Add this class for county labels
class CountyLabel: NSObject, MKAnnotation {
    var coordinate: CLLocationCoordinate2D
    var title: String?
    
    init(coordinate: CLLocationCoordinate2D, title: String) {
        self.coordinate = coordinate
        self.title = title
        super.init()
    }
}
