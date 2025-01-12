import Foundation
import MapKit
import CoreLocation

struct Coordinate: Codable {
    let latitude: Double
    let longitude: Double
}

struct GridCell: Identifiable, Codable {
    let id: UUID
    let coordinate: Coordinate
    var isVisited: Bool
}

struct CountyProgress: Identifiable, Codable {
    let id: String // GEOID from GeoJSON
    let countyName: String
    let stateName: String
    private var visitedCellCoordinates: Set<String>
    var gridCells: [GridCell]
    
    init(id: String, countyName: String, stateName: String, visitedCellCoordinates: Set<String>, gridCells: [GridCell]) {
        self.id = id
        self.countyName = countyName
        self.stateName = stateName
        self.visitedCellCoordinates = visitedCellCoordinates
        self.gridCells = gridCells
        
        // Update the isVisited status of grid cells based on visitedCellCoordinates
        // Create a lookup set of rounded coordinates for faster checking
        let roundedVisitedCoords = visitedCellCoordinates.map { coord -> String in
            let components = coord.components(separatedBy: ",")
            if components.count == 2,
               let lat = Double(components[0]),
               let lon = Double(components[1]) {
                let roundedLat = round(lat * 1000000) / 1000000
                let roundedLon = round(lon * 1000000) / 1000000
                return "\(roundedLat),\(roundedLon)"
            }
            return coord
        }.reduce(into: Set<String>()) { $0.insert($1) }
        
        // Update grid cells in a single pass
        for i in 0..<self.gridCells.count {
            let coordinate = self.gridCells[i].coordinate
            let roundedLat = round(coordinate.latitude * 1000000) / 1000000
            let roundedLon = round(coordinate.longitude * 1000000) / 1000000
            let coordString = "\(roundedLat),\(roundedLon)"
            self.gridCells[i].isVisited = roundedVisitedCoords.contains(coordString)
        }
    }
    
    var visitedCellCount: Int {
        visitedCellCoordinates.count
    }
    
    var totalCellCount: Int {
        gridCells.count
    }
    
    mutating func markCellAsVisited(_ coordinate: Coordinate) {
        let roundedLat = round(coordinate.latitude * 1000000) / 1000000
        let roundedLon = round(coordinate.longitude * 1000000) / 1000000
        let coordString = "\(roundedLat),\(roundedLon)"
        visitedCellCoordinates.insert(coordString)
        
        // Update the corresponding grid cell's isVisited status
        for i in 0..<gridCells.count {
            let cell = gridCells[i]
            let cellLat = round(cell.coordinate.latitude * 1000000) / 1000000
            let cellLon = round(cell.coordinate.longitude * 1000000) / 1000000
            let cellCoordString = "\(cellLat),\(cellLon)"
            
            if cellCoordString == coordString {
                gridCells[i].isVisited = true
                break
            }
        }
    }
    
    func isCellVisited(_ coordinate: Coordinate) -> Bool {
        let roundedLat = round(coordinate.latitude * 1000000) / 1000000
        let roundedLon = round(coordinate.longitude * 1000000) / 1000000
        let coordString = "\(roundedLat),\(roundedLon)"
        return visitedCellCoordinates.contains(coordString)
    }
}

class CountyProgressManager: ObservableObject {
    @Published private var visitedCells: [String: Set<String>] = [:] {
        didSet {
            saveProgress()
        }
    }
    @Published var countyProgress: [String: CountyProgress] = [:]
    
    private let saveKey = "VisitedCells"
    
    init() {
        loadProgress()
    }
    
    private func saveProgress() {
        if let encoded = try? JSONEncoder().encode(visitedCells) {
            UserDefaults.standard.set(encoded, forKey: saveKey)
        }
    }
    
    private func loadProgress() {
        if let data = UserDefaults.standard.data(forKey: saveKey),
           let decoded = try? JSONDecoder().decode([String: Set<String>].self, from: data) {
            visitedCells = decoded
        }
    }
    
    func generateGridCells(for polygon: MKPolygon, gridSize: Int = 40) -> [GridCell] {
        let boundingBox = polygon.boundingMapRect
        let cellWidth = boundingBox.size.width / Double(gridSize)
        let cellHeight = boundingBox.size.height / Double(gridSize)
        
        var cells: [GridCell] = []
        
        for row in 0..<gridSize {
            for col in 0..<gridSize {
                let x = boundingBox.origin.x + (Double(col) * cellWidth) + (cellWidth / 2)
                let y = boundingBox.origin.y + (Double(row) * cellHeight) + (cellHeight / 2)
                let mapPoint = MKMapPoint(x: x, y: y)
                let coordinate = mapPoint.coordinate
                
                // Only add the cell if it's inside the polygon
                let renderer = MKPolygonRenderer(polygon: polygon)
                let point = renderer.point(for: mapPoint)
                if renderer.path.contains(point) {
                    // Round coordinates to 6 decimal places for consistency
                    let roundedLat = round(coordinate.latitude * 1000000) / 1000000
                    let roundedLon = round(coordinate.longitude * 1000000) / 1000000
                    let coordString = "\(roundedLat),\(roundedLon)"
                    
                    cells.append(GridCell(
                        id: UUID(),
                        coordinate: Coordinate(latitude: roundedLat, longitude: roundedLon),
                        isVisited: false
                    ))
                }
            }
        }
        
        return cells
    }
    
    func initializeCounty(geoid: String, name: String, state: String, polygon: MKPolygon) {
        let cells = generateGridCells(for: polygon)
        var progress = CountyProgress(id: geoid, countyName: name, stateName: state, visitedCellCoordinates: [], gridCells: cells)
        
        // Restore visited state
        if let visited = visitedCells[geoid] {
            for coordinate in visited {
                let components = coordinate.components(separatedBy: ",")
                if components.count == 2,
                   let lat = Double(components[0]),
                   let lon = Double(components[1]) {
                    progress.markCellAsVisited(Coordinate(latitude: lat, longitude: lon))
                }
            }
        }
        
        countyProgress[geoid] = progress
    }
    
    func updateVisitedCells(for coordinate: CLLocationCoordinate2D, radius: Double = 100) {
        for (geoid, var county) in countyProgress {
            var hasChanges = false
            
            for cell in county.gridCells {
                let cellCoord = CLLocationCoordinate2D(
                    latitude: cell.coordinate.latitude,
                    longitude: cell.coordinate.longitude
                )
                
                let distance = MKMapPoint(coordinate).distance(to: MKMapPoint(cellCoord))
                if distance <= radius && !county.isCellVisited(cell.coordinate) {
                    county.markCellAsVisited(cell.coordinate)
                    if visitedCells[geoid] == nil {
                        visitedCells[geoid] = []
                    }
                    visitedCells[geoid]?.insert("\(cell.coordinate.latitude),\(cell.coordinate.longitude)")
                    hasChanges = true
                }
            }
            
            if hasChanges {
                countyProgress[geoid] = county
                objectWillChange.send()
            }
        }
    }
    
    func markCellAsVisited(in countyId: String, at coordinate: Coordinate) {
        print("Attempting to mark cell as visited in county \(countyId)")
        guard var county = countyProgress[countyId] else {
            print("⚠️ No county found with ID \(countyId)")
            return
        }
        
        // Mark the cell as visited in the county
        county.markCellAsVisited(coordinate)
        
        // Update the visited cells storage
        if visitedCells[countyId] == nil {
            visitedCells[countyId] = []
            print("Created new visited cells set for county \(countyId)")
        }
        visitedCells[countyId]?.insert("\(coordinate.latitude),\(coordinate.longitude)")
        print("Updated visited cells for county \(countyId): \(visitedCells[countyId] ?? [])")
        
        // Update the county progress
        countyProgress[countyId] = county
        
        // Notify observers
        objectWillChange.send()
        print("County progress updated and observers notified")
    }
} 