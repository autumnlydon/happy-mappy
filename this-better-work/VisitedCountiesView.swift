import SwiftUI

struct VisitedCountiesView: View {
    @ObservedObject var progressManager: CountyProgressManager
    
    var visitedCounties: [CountyProgress] {
        progressManager.countyProgress.values
            .filter { $0.visitedCellCount > 0 }
            .sorted { $0.countyName < $1.countyName }
    }
    
    var body: some View {
        List {
            if visitedCounties.isEmpty {
                Text("No counties visited yet")
                    .foregroundColor(.secondary)
                    .padding()
            } else {
                ForEach(visitedCounties, id: \.id) { county in
                    VStack(alignment: .leading, spacing: 8) {
                        Text(county.countyName)
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
        .navigationTitle("Visited Counties")
        .listStyle(InsetGroupedListStyle())
    }
}

#Preview {
    VisitedCountiesView(progressManager: CountyProgressManager())
} 