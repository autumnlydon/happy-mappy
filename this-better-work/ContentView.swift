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
    @StateObject private var userState = UserState.shared
    @State private var email = ""
    @State private var password = ""
    @State private var isLoading = false
    @State private var showError = false
    @State private var errorMessage = ""
    
    var body: some View {
        VStack(spacing: 20) {
            Text("Welcome to County Explorer")
                .font(.largeTitle)
                .fontWeight(.bold)
            
            Text("Track your adventures across counties")
                .font(.title2)
                .foregroundColor(.gray)
            
            Image(systemName: "map.fill")
                .resizable()
                .scaledToFit()
                .frame(width: 100, height: 100)
                .foregroundColor(.blue)
                .padding(.vertical, 30)
            
            if !userState.isAuthenticated {
                // Login Form
                TextField("Email", text: $email)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .autocapitalization(.none)
                    .padding(.horizontal)
                
                SecureField("Password", text: $password)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .padding(.horizontal)
                
                HStack(spacing: 20) {
                    Button("Sign In") {
                        login()
                    }
                    .buttonStyle(.borderedProminent)
                    
                    Button("Sign Up") {
                        signUp()
                    }
                    .buttonStyle(.bordered)
                }
                .disabled(isLoading)
            } else {
                Text("Explore counties, track visited areas,\nand discover new places!")
                    .multilineTextAlignment(.center)
                    .padding()
                
                Button(action: {
                    withAnimation {
                        showMap = true
                    }
                }) {
                    Text("Start Exploring")
                        .font(.headline)
                        .foregroundColor(.white)
                        .padding()
                        .frame(width: 200)
                        .background(Color.blue)
                        .cornerRadius(10)
                }
                .padding(.top, 20)
                
                Button("Sign Out") {
                    signOut()
                }
                .padding(.top)
            }
        }
        .padding()
        .alert("Error", isPresented: $showError) {
            Button("OK") { }
        } message: {
            Text(errorMessage)
        }
    }
    
    private func login() {
        isLoading = true
        Task {
            do {
                try await userState.signIn(email: email, password: password)
            } catch {
                await MainActor.run {
                    errorMessage = error.localizedDescription
                    showError = true
                }
            }
            await MainActor.run {
                isLoading = false
            }
        }
    }
    
    private func signUp() {
        isLoading = true
        Task {
            do {
                try await userState.signUp(email: email, password: password)
            } catch {
                await MainActor.run {
                    errorMessage = error.localizedDescription
                    showError = true
                }
            }
            await MainActor.run {
                isLoading = false
            }
        }
    }
    
    private func signOut() {
        Task {
            do {
                try await userState.signOut()
            } catch {
                await MainActor.run {
                    errorMessage = error.localizedDescription
                    showError = true
                }
            }
        }
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
                
                // Add back button
                VStack {
                    Button(action: {
                        withAnimation {
                            showMap = false
                        }
                    }) {
                        Image(systemName: "chevron.left")
                            .font(.title2)
                            .foregroundColor(.blue)
                            .padding(10)
                            .background(Color(.systemBackground))
                            .clipShape(Circle())
                            .shadow(radius: 2)
                    }
                    .padding()
                    .frame(maxWidth: .infinity, alignment: .leading)
                    
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
            HomePage(showMap: $showMap)
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
        guard let county = selectedCounty else {
            print("No county selected for grid cells")
            return []
        }
        
        print("Creating grid cells for \(county.countyName) county")
        print("Number of grid cells: \(county.gridCells.count)")
        
        return county.gridCells.map { cell in
            let center = CLLocationCoordinate2D(
                latitude: cell.coordinate.latitude,
                longitude: cell.coordinate.longitude
            )
            
            // Create a small square around the cell center
            let squareSize = 0.005 // Increased size for visibility
            let topLeft = CLLocationCoordinate2D(
                latitude: center.latitude + squareSize,
                longitude: center.longitude - squareSize
            )
            let topRight = CLLocationCoordinate2D(
                latitude: center.latitude + squareSize,
                longitude: center.longitude + squareSize
            )
            let bottomLeft = CLLocationCoordinate2D(
                latitude: center.latitude - squareSize,
                longitude: center.longitude - squareSize
            )
            let bottomRight = CLLocationCoordinate2D(
                latitude: center.latitude - squareSize,
                longitude: center.longitude + squareSize
            )
            
            let coordinates = [topLeft, topRight, bottomRight, bottomLeft]
            return MKPolygon(coordinates: coordinates, count: 4)
        }
    }

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
        
        // First add county overlays
        print("Adding \(overlays.count) county overlays")
        mapView.addOverlays(overlays)
        
        // Only add grid cells if a county is selected
        if selectedCounty != nil {
            let cells = gridOverlays
            print("Adding \(cells.count) grid cell overlays")
            mapView.addOverlays(cells)
        }
        
        print("Adding \(annotations.count) annotations")
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
                
                // If this is a grid cell (smaller polygon)
                if polygon.pointCount == 4 {
                    // Make grid cells more visible
                    renderer.fillColor = UIColor.red.withAlphaComponent(0.3)  // More opacity
                    renderer.strokeColor = UIColor.black.withAlphaComponent(0.5)  // More visible borders
                    renderer.lineWidth = 1.0  // Thicker borders
                    
                    // If we have visited data, update the color
                    if let selectedCounty = parent.selectedCounty {
                        let center = polygon.coordinate
                        let cellCoordinate = Coordinate(latitude: center.latitude, longitude: center.longitude)
                        
                        if selectedCounty.isCellVisited(cellCoordinate) {
                            renderer.fillColor = UIColor.green.withAlphaComponent(0.4)
                        }
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
            if let county = parent.progressManager.countyProgress[countyAnnotation.geoid] {
                parent.selectedCounty = county
            }
        }
        
        func mapView(_ mapView: MKMapView, didDeselect annotation: MKAnnotation) {
            parent.selectedCounty = nil
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
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
    }
}
