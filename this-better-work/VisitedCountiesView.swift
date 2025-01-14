import SwiftUI

struct ProgressSection: View {
    let title: String
    let progress: Double
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.headline)
            
            ProgressView(value: progress)
                .tint(.blue)
            
            Text("\(Int(progress * 100))% Explored")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding(.vertical, 4)
    }
}

struct VisitedCountiesView: View {
    @ObservedObject var progressManager: CountyProgressManager
    
    // FIPS state codes to state names mapping
    private let stateNames: [String: String] = [
        "01": "Alabama",
        "02": "Alaska",
        "04": "Arizona",
        "05": "Arkansas",
        "06": "California",
        "08": "Colorado",
        "09": "Connecticut",
        "10": "Delaware",
        "11": "District of Columbia",
        "12": "Florida",
        "13": "Georgia",
        "15": "Hawaii",
        "16": "Idaho",
        "17": "Illinois",
        "18": "Indiana",
        "19": "Iowa",
        "20": "Kansas",
        "21": "Kentucky",
        "22": "Louisiana",
        "23": "Maine",
        "24": "Maryland",
        "25": "Massachusetts",
        "26": "Michigan",
        "27": "Minnesota",
        "28": "Mississippi",
        "29": "Missouri",
        "30": "Montana",
        "31": "Nebraska",
        "32": "Nevada",
        "33": "New Hampshire",
        "34": "New Jersey",
        "35": "New Mexico",
        "36": "New York",
        "37": "North Carolina",
        "38": "North Dakota",
        "39": "Ohio",
        "40": "Oklahoma",
        "41": "Oregon",
        "42": "Pennsylvania",
        "44": "Rhode Island",
        "45": "South Carolina",
        "46": "South Dakota",
        "47": "Tennessee",
        "48": "Texas",
        "49": "Utah",
        "50": "Vermont",
        "51": "Virginia",
        "53": "Washington",
        "54": "West Virginia",
        "55": "Wisconsin",
        "56": "Wyoming",
        "72": "Puerto Rico"
    ]
    
    var visitedCounties: [CountyProgress] {
        progressManager.countyProgress.values
            .filter { $0.visitedCellCount > 0 }
            .sorted { $0.countyName < $1.countyName }
    }
    
    var stateProgress: [(state: String, progress: Double)] {
        // Group counties by state
        let stateGroups = Dictionary(grouping: progressManager.countyProgress.values) { $0.stateName }
        
        // Calculate progress for each state
        return stateGroups.map { stateCode, counties in
            let totalCells = counties.reduce(0) { $0 + $1.totalCellCount }
            let visitedCells = counties.reduce(0) { $0 + $1.visitedCellCount }
            let progress = totalCells > 0 ? Double(visitedCells) / Double(totalCells) : 0
            return (state: stateNames[stateCode] ?? stateCode, progress: progress)
        }
        .sorted { $0.state < $1.state }
    }
    
    var countryProgress: Double {
        let totalCells = progressManager.countyProgress.values.reduce(0) { $0 + $1.totalCellCount }
        let visitedCells = progressManager.countyProgress.values.reduce(0) { $0 + $1.visitedCellCount }
        return totalCells > 0 ? Double(visitedCells) / Double(totalCells) : 0
    }
    
    var body: some View {
        List {
            Section(header: Text("Country Progress")) {
                ProgressSection(title: "United States", progress: countryProgress)
            }
            
            Section(header: Text("State Progress")) {
                if stateProgress.isEmpty {
                    Text("No states visited yet")
                        .foregroundColor(.secondary)
                } else {
                    ForEach(stateProgress, id: \.state) { state in
                        ProgressSection(title: state.state, progress: state.progress)
                    }
                }
            }
            
            Section(header: Text("County Progress")) {
                if visitedCounties.isEmpty {
                    Text("No counties visited yet")
                        .foregroundColor(.secondary)
                } else {
                    ForEach(visitedCounties) { county in
                        VStack(alignment: .leading, spacing: 8) {
                            Text("\(county.countyName), \(stateNames[county.stateName] ?? county.stateName)")
                                .font(.headline)
                            
                            ProgressView(value: Double(county.visitedCellCount) / Double(county.totalCellCount))
                                .tint(.blue)
                            
                            Text("\(Int((Double(county.visitedCellCount) / Double(county.totalCellCount)) * 100))% Explored")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        .padding(.vertical, 4)
                    }
                }
            }
        }
        .navigationTitle("Exploration Progress")
        .listStyle(InsetGroupedListStyle())
    }
}

#Preview {
    VisitedCountiesView(progressManager: CountyProgressManager())
} 