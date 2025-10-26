//
//  LocationSearchField.swift
//  Crowd
//
//  Created by Teni Owojori on 10/26/25.
//

import SwiftUI
import MapKit

struct LocationSearchField: View {
    @Binding var locationName: String
    @Binding var coordinate: CLLocationCoordinate2D
    
    @StateObject private var searchCompleter = LocationSearchCompleter()
    @State private var isShowingSuggestions = false
    @FocusState private var isFocused: Bool
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            TextField("Search location...", text: $locationName)
                .focused($isFocused)
                .textFieldStyle(.plain)
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
                .background(Color(.systemGray6))
                .cornerRadius(8)
                .onChange(of: locationName) { _, newValue in
                    searchCompleter.queryFragment = newValue
                    isShowingSuggestions = !newValue.isEmpty
                }
                .onChange(of: isFocused) { _, focused in
                    if focused && !locationName.isEmpty {
                        isShowingSuggestions = true
                    }
                }
            
            if isShowingSuggestions && !searchCompleter.results.isEmpty {
                VStack(alignment: .leading, spacing: 0) {
                    ForEach(searchCompleter.results, id: \.self) { result in
                        Button(action: {
                            selectLocation(result)
                        }) {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(result.title)
                                    .font(.system(size: 15))
                                    .foregroundColor(.primary)
                                if !result.subtitle.isEmpty {
                                    Text(result.subtitle)
                                        .font(.system(size: 13))
                                        .foregroundColor(.secondary)
                                }
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 10)
                        }
                        .buttonStyle(.plain)
                        
                        if result != searchCompleter.results.last {
                            Divider()
                        }
                    }
                }
                .background(Color(.systemBackground))
                .cornerRadius(8)
                .shadow(color: .black.opacity(0.1), radius: 5, x: 0, y: 2)
                .padding(.top, 4)
            }
        }
    }
    
    private func selectLocation(_ result: MKLocalSearchCompletion) {
        let searchRequest = MKLocalSearch.Request(completion: result)
        let search = MKLocalSearch(request: searchRequest)
        
        search.start { response, error in
            guard let response = response,
                  let item = response.mapItems.first else {
                return
            }
            
            coordinate = item.placemark.coordinate
            locationName = result.title
            isShowingSuggestions = false
            isFocused = false
        }
    }
}

// MARK: - Location Search Completer
class LocationSearchCompleter: NSObject, ObservableObject, MKLocalSearchCompleterDelegate {
    @Published var results: [MKLocalSearchCompletion] = []
    private let completer = MKLocalSearchCompleter()
    
    // UNT Denton coordinates: 33.2098° N, 97.1526° W
    private let dentonCenter = CLLocationCoordinate2D(latitude: 33.2098, longitude: -97.1526)
    
    var queryFragment: String = "" {
        didSet {
            completer.queryFragment = queryFragment
        }
    }
    
    override init() {
        super.init()
        completer.delegate = self
        completer.resultTypes = .address
        
        // Set region to Denton, TX area (approximately 10km radius covering UNT and surrounding Denton)
        let dentonRegion = MKCoordinateRegion(
            center: dentonCenter,
            latitudinalMeters: 20000,  // ~10km radius
            longitudinalMeters: 20000
        )
        completer.region = dentonRegion
    }
    
    func completerDidUpdateResults(_ completer: MKLocalSearchCompleter) {
        results = completer.results
    }
    
    func completer(_ completer: MKLocalSearchCompleter, didFailWithError error: Error) {
        print("Location search error: \(error.localizedDescription)")
    }
}

