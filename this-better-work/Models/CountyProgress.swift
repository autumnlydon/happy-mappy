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
    }
    
    var visitedCellCount: Int {
        visitedCellCoordinates.count
    }
    
    var totalCellCount: Int {
        gridCells.count
    }
    
    mutating func markCellAsVisited(_ coordinate: Coordinate) {
        visitedCellCoordinates.insert("\(coordinate.latitude),\(coordinate.longitude)")
    }
    
    func isCellVisited(_ coordinate: Coordinate) -> Bool {
        visitedCellCoordinates.contains("\(coordinate.latitude),\(coordinate.longitude)")
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
                    cells.append(GridCell(
                        id: UUID(),
                        coordinate: Coordinate(latitude: coordinate.latitude, longitude: coordinate.longitude),
                        isVisited: false
                    ))
                }
            }
        }
        
        return cells
    }
    
    func initializeCounty(geoid: String, name: String, state: String, polygon: MKPolygon) {
        let cells = generateGridCells(for: polygon)
        var progress = CountyProgress(id: geoid, countyName: name, stateName: state, visitedCellCoordinates: [], gridCells: [])
        progress.gridCells = cells
        
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
            }
        }
    }
} 