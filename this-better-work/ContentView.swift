import SwiftUI
import MapKit
import CoreLocation
import _MapKit_SwiftUI

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
struct HomePage: View {
    @Binding var showMap: Bool
    @ObservedObject var progressManager: CountyProgressManager
    
    // Define our custom colors
    private let mutedBlue = Color(red: 137/255, green: 157/255, blue: 192/255)
    private let textGray = Color(red: 128/255, green: 128/255, blue: 128/255)
    
    var body: some View {
        VStack(spacing: 40) {
            // App Logo and Title
            VStack(spacing: 20) {
                Image(systemName: "map.fill")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 65, height: 65)
                    .foregroundColor(mutedBlue)
                    .background(
                        Circle()
                            .fill(Color.white)
                            .frame(width: 100, height: 100)
                            .shadow(color: Color.black.opacity(0.1), radius: 10)
                    )
                    .padding(.top, 60)
                
                Text("yap map")
                    .font(.system(size: 42, weight: .light))
                    .foregroundColor(mutedBlue)
                
                Text("Get out of the house, and explore")
                    .font(.system(size: 20, weight: .light))
                    .foregroundColor(textGray)
            }
            .padding(.bottom, 20)
            
            VStack(spacing: 30) {
                Text("Where have you been?")
                    .font(.system(size: 32, weight: .light))
                    .foregroundColor(mutedBlue)
                    .padding(.bottom, 5)
                
                Text("Keep track of places discovered,\nand counties explored, and celebrate the fact that you left the house!")
                    .font(.system(size: 18))
                    .foregroundColor(textGray)
                    .multilineTextAlignment(.center)
                    .lineSpacing(4)
                    .padding(.bottom, 20)
                
                VStack(spacing: 15) {
                    Button(action: {
                        withAnimation {
                            showMap = true
                        }
                    }) {
                        HStack(spacing: 12) {
                            Image(systemName: "map")
                            Text("Start Exploring")
                        }
                        .font(.headline)
                        .foregroundColor(.white)
                        .frame(width: 250, height: 55)
                        .background(
                            RoundedRectangle(cornerRadius: 27.5)
                                .fill(mutedBlue)
                                .shadow(color: mutedBlue.opacity(0.3), radius: 8, y: 4)
                        )
                    }
                    
                    NavigationLink(destination: VisitedCountiesView(progressManager: progressManager)) {
                        HStack(spacing: 12) {
                            Image(systemName: "chart.bar.fill")
                            Text("Track Exploration")
                        }
                        .font(.headline)
                        .foregroundColor(mutedBlue)
                        .frame(width: 250, height: 55)
                        .background(
                            RoundedRectangle(cornerRadius: 27.5)
                                .stroke(mutedBlue, lineWidth: 2)
                        )
                    }
                }
            }
            .padding(.horizontal, 30)
            
            Spacer()
        }
        .background(Color.white)
    }
}

// Custom ViewModifiers for consistent styling
struct TextFieldModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 15)
                    .fill(Color.white)
                    .shadow(color: Color.black.opacity(0.05), radius: 5, y: 2)
            )
    }
}

struct PrimaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline)
            .foregroundColor(.white)
            .padding(.horizontal, 30)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: 20)
                    .fill(Color(red: 137/255, green: 157/255, blue: 192/255))
                    .shadow(color: Color.black.opacity(0.1), radius: 5, y: 2)
            )
            .scaleEffect(configuration.isPressed ? 0.95 : 1.0)
            .animation(.spring(), value: configuration.isPressed)
    }
}

struct SecondaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline)
            .foregroundColor(Color(red: 137/255, green: 157/255, blue: 192/255))
            .padding(.horizontal, 30)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: 20)
                    .stroke(Color(red: 137/255, green: 157/255, blue: 192/255), lineWidth: 2)
            )
            .scaleEffect(configuration.isPressed ? 0.95 : 1.0)
            .animation(.spring(), value: configuration.isPressed)
    }
}

struct ContentView: View {
    @State private var showMap = false
    @StateObject private var locationManager = LocationManager()
    @StateObject private var progressManager = CountyProgressManager()
    @State private var region = MKCoordinateRegion(
        center: CLLocationCoordinate2D(latitude: 40.7128, longitude: -74.0060),
        span: MKCoordinateSpan(latitudeDelta: 0.05, longitudeDelta: 0.05)
    )
    @State private var overlays: [MKOverlay] = []
    @State private var annotations: [CountyAnnotation] = []
    @State private var selectedCounty: CountyProgress?
    @State private var showingProgress = false

    var body: some View {
        NavigationView {
            if showMap {
                // Map View
                ZStack {
                    MapView(region: $region, 
                           overlays: $overlays, 
                           annotations: $annotations,
                           selectedCounty: $selectedCounty,
                           progressManager: progressManager)
                        .edgesIgnoringSafeArea(.all)
                        .overlay(
                            UserLocationButton(region: $region, userLocation: locationManager.userLocation)
                        )
                    
                    if let county = selectedCounty {
                        VStack {
                            Spacer()
                            CountyProgressView(county: county)
                                .transition(.move(edge: .bottom))
                                .padding()
                        }
                    }
                    
                    // Navigation buttons
                    VStack {
                        HStack {
                            Button(action: {
                                withAnimation {
                                    showMap = false
                                }
                            }) {
                                Image(systemName: "chevron.left")
                                    .font(.title2)
                                    .foregroundColor(Color(red: 137/255, green: 157/255, blue: 192/255))
                                    .padding(10)
                                    .background(Color(.systemBackground))
                                    .clipShape(Circle())
                                    .shadow(radius: 2)
                            }
                            
                            Spacer()
                            
                            NavigationLink(destination: VisitedCountiesView(progressManager: progressManager)) {
                                Image(systemName: "list.bullet")
                                    .font(.title2)
                                    .foregroundColor(Color(red: 137/255, green: 157/255, blue: 192/255))
                                    .padding(10)
                                    .background(Color(.systemBackground))
                                    .clipShape(Circle())
                                    .shadow(radius: 2)
                            }
                        }
                        .padding()
                        
                        Spacer()
                    }
                }
                .onAppear {
                    loadCountyBoundaries()
                }
                .onChange(of: locationManager.userLocation) { newLocation in
                    if let location = newLocation {
                        updateCurrentCounty(for: location.coordinate)
                        progressManager.updateVisitedCells(for: location.coordinate)
                    }
                }
            } else {
                // Home Page
                HomePage(showMap: $showMap, progressManager: progressManager)
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
            var countyAnnotations: [CountyAnnotation] = []
            
            for feature in features {
                guard let geoFeature = feature as? MKGeoJSONFeature,
                      let geometry = geoFeature.geometry.first,
                      let properties = geoFeature.properties,
                      let propertyData = try? JSONSerialization.jsonObject(with: properties) as? [String: Any],
                      let countyName = propertyData["NAME"] as? String,
                      let stateId = propertyData["STATEFP"] as? String,
                      let geoid = propertyData["GEOID"] as? String else {
                    continue
                }
                
                var polygonsForFeature: [MKPolygon] = []
                if let polygon = geometry as? MKPolygon {
                    polygonsForFeature = [polygon]
                } else if let multiPolygon = geometry as? MKMultiPolygon {
                    polygonsForFeature = multiPolygon.polygons
                }
                
                allPolygons.append(contentsOf: polygonsForFeature)
                
                // Initialize county progress
                if let polygon = polygonsForFeature.first {
                    progressManager.initializeCounty(
                        geoid: geoid,
                        name: countyName,
                        state: stateId,
                        polygon: polygon
                    )
                    
                    let annotation = CountyAnnotation(
                        coordinate: polygon.coordinate,
                        title: countyName,
                        geoid: geoid
                    )
                    countyAnnotations.append(annotation)
                }
            }
            
            print("Created \(allPolygons.count) polygon overlays")
            overlays = allPolygons
            annotations = countyAnnotations
            
        } catch {
            print("❌ Error processing GeoJSON: \(error)")
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
    @Binding var annotations: [CountyAnnotation]
    @Binding var selectedCounty: CountyProgress?
    let progressManager: CountyProgressManager
    
    private var gridOverlays: [MKOverlay] {
        guard let county = selectedCounty else { return [] }
        
        var existingCells = Set<String>()
        var overlays: [MKPolygon] = []
        
        for cell in county.gridCells {
            let identifier = "\(cell.coordinate.latitude),\(cell.coordinate.longitude)"
            guard !existingCells.contains(identifier) else { continue }
            existingCells.insert(identifier)
            
            let center = CLLocationCoordinate2D(
                latitude: cell.coordinate.latitude,
                longitude: cell.coordinate.longitude
            )
            
            let squareSize = 0.005
            let coordinates = [
                CLLocationCoordinate2D(latitude: center.latitude + squareSize, longitude: center.longitude - squareSize),
                CLLocationCoordinate2D(latitude: center.latitude + squareSize, longitude: center.longitude + squareSize),
                CLLocationCoordinate2D(latitude: center.latitude - squareSize, longitude: center.longitude + squareSize),
                CLLocationCoordinate2D(latitude: center.latitude - squareSize, longitude: center.longitude - squareSize)
            ]
            
            let polygon = MKPolygon(coordinates: coordinates, count: 4)
            polygon.title = "visited:\(cell.isVisited)"
            overlays.append(polygon)
        }
        
        return overlays
    }

    func makeUIView(context: Context) -> MKMapView {
        let mapView = MKMapView()
        mapView.delegate = context.coordinator
        mapView.showsUserLocation = true
        mapView.setRegion(region, animated: false)
        
        // Add tap gesture recognizer
        let tapGesture = UITapGestureRecognizer(
            target: context.coordinator,
            action: #selector(Coordinator.handleTap(_:))
        )
        mapView.addGestureRecognizer(tapGesture)
        
        return mapView
    }

    func updateUIView(_ mapView: MKMapView, context: Context) {
        mapView.setRegion(region, animated: true)
        
        // Only update overlays if they've changed
        let currentOverlays = Set(mapView.overlays.map { $0.hash })
        let newOverlays = Set(overlays.map { $0.hash })
        
        if currentOverlays != newOverlays {
            mapView.removeOverlays(mapView.overlays)
            mapView.addOverlays(overlays)
        }
        
        // Only add grid cells if a county is selected and they're not already present
        if selectedCounty != nil {
            let cells = gridOverlays
            let existingGridCells = mapView.overlays.filter { $0 is MKPolygon && ($0 as! MKPolygon).pointCount == 4 }
            
            if existingGridCells.count != cells.count {
                mapView.removeOverlays(existingGridCells)
                mapView.addOverlays(cells)
            }
        }
        
        // Update annotations only if they've changed
        let currentAnnotations = Set(mapView.annotations.compactMap { ($0 as? CountyAnnotation)?.geoid })
        let newAnnotations = Set(annotations.map { $0.geoid })
        
        if currentAnnotations != newAnnotations {
            mapView.removeAnnotations(mapView.annotations)
            mapView.addAnnotations(annotations)
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    class Coordinator: NSObject, MKMapViewDelegate {
        var parent: MapView

        init(_ parent: MapView) {
            self.parent = parent
            super.init()
        }

        func mapView(_ mapView: MKMapView, rendererFor overlay: MKOverlay) -> MKOverlayRenderer {
            if let polygon = overlay as? MKPolygon {
                let renderer = MKPolygonRenderer(polygon: polygon)
                
                // If this is a grid cell (smaller polygon)
                if polygon.pointCount == 4 {
                    // Default color for unvisited cells
                    renderer.fillColor = UIColor.red.withAlphaComponent(0.1)
                    renderer.strokeColor = UIColor.black.withAlphaComponent(0.3)
                    renderer.lineWidth = 1.0
                    
                    // Only check visited status if we have associated data
                    if let title = polygon.title,
                       title == "visited:true" {
                        renderer.fillColor = UIColor.green.withAlphaComponent(0.5)
                    }
                } else {
                    // County border
                    renderer.strokeColor = .black
                    renderer.lineWidth = 1
                    renderer.fillColor = .clear
                }
                return renderer
            }
            return MKOverlayRenderer(overlay: overlay)
        }
        
        func mapView(_ mapView: MKMapView, didSelect annotation: MKAnnotation) {
            guard let countyAnnotation = annotation as? CountyAnnotation else { return }
            print("Selected county with GEOID: \(countyAnnotation.geoid)")
            if let county = parent.progressManager.countyProgress[countyAnnotation.geoid] {
                print("Found county: \(county.countyName)")
                print("Visited cell count: \(county.visitedCellCount)")
                print("Total cell count: \(county.totalCellCount)")
                parent.selectedCounty = county
            } else {
                print("⚠️ No county found in progress manager for GEOID: \(countyAnnotation.geoid)")
            }
        }
        
        func mapView(_ mapView: MKMapView, didDeselect annotation: MKAnnotation) {
            parent.selectedCounty = nil
        }

        // Add tap gesture handling
        @objc func handleTap(_ gesture: UITapGestureRecognizer) {
            let mapView = gesture.view as! MKMapView
            let point = gesture.location(in: mapView)
            
            guard let selectedCounty = parent.selectedCounty else { return }
            
            // Convert tap point to coordinate
            let coordinate = mapView.convert(point, toCoordinateFrom: mapView)
            
            // Check if tap is within any grid cell
            for overlay in mapView.overlays {
                guard let polygon = overlay as? MKPolygon,
                      polygon.pointCount == 4 else { continue }
                
                let renderer = MKPolygonRenderer(polygon: polygon)
                let pointInRenderer = renderer.point(for: MKMapPoint(coordinate))
                
                if renderer.path.contains(pointInRenderer) {
                    // Found the tapped cell, mark it as visited
                    let cellCoordinate = Coordinate(
                        latitude: polygon.coordinate.latitude,
                        longitude: polygon.coordinate.longitude
                    )
                    
                    // Mark the cell as visited using the new method
                    parent.progressManager.markCellAsVisited(
                        in: selectedCounty.id,
                        at: cellCoordinate
                    )
                    
                    // Force a refresh of the entire grid by updating the selected county
                    if let updatedCounty = parent.progressManager.countyProgress[selectedCounty.id] {
                        parent.selectedCounty = updatedCounty
                        
                        // Force a complete refresh of the map view
                        DispatchQueue.main.async {
                            mapView.removeOverlays(mapView.overlays)
                            
                            // Re-add county borders
                            for overlay in self.parent.overlays {
                                if let polygon = overlay as? MKPolygon, polygon.pointCount > 4 {
                                    mapView.addOverlay(polygon)
                                }
                            }
                            
                            // Re-add grid cells
                            if let cells = self.parent.gridOverlays as? [MKPolygon] {
                                mapView.addOverlays(cells)
                            }
                        }
                    }
                    break
                }
            }
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

// Add CountyProgressView
struct CountyProgressView: View {
    let county: CountyProgress
    
    var body: some View {
        VStack(spacing: 8) {
            Text("\(county.countyName) County")
                .font(.headline)
            Text("\(county.visitedCellCount)/\(county.totalCellCount) cells visited")
                .font(.subheadline)
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(10)
        .shadow(radius: 5)
    }
}

// Update CountyAnnotation
class CountyAnnotation: NSObject, MKAnnotation {
    let coordinate: CLLocationCoordinate2D
    let title: String?
    let geoid: String
    
    init(coordinate: CLLocationCoordinate2D, title: String, geoid: String) {
        self.coordinate = coordinate
        self.title = title
        self.geoid = geoid
        super.init()
    }
}

// Add UserLocationButton view before ContentView
struct UserLocationButton: View {
    @Binding var region: MKCoordinateRegion
    let userLocation: EquatableLocation?
    
    var body: some View {
        Button(action: {
            if let location = userLocation {
                withAnimation {
                    region.center = location.coordinate
                    region.span = MKCoordinateSpan(latitudeDelta: 0.05, longitudeDelta: 0.05)
                }
            }
        }) {
            Image(systemName: "location.fill")
                .padding(10)
                .background(Color(.systemBackground))
                .clipShape(Circle())
                .shadow(radius: 2)
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomTrailing)
    }
}
