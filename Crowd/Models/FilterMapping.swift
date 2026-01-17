//
//  FilterMapping.swift
//  Crowd
//
//  Maps external tags from Firebase to internal filter categories
//

import Foundation

struct FilterMapping: Codable {
    let source: String
    let external: String
    let internalCategory: String
    
    enum CodingKeys: String, CodingKey {
        case source
        case external
        case internalCategory = "internal"
    }
}

enum FilterCategory: String, CaseIterable, Identifiable {
    case career = "career"
    case study = "study"
    case social = "social"
    case party = "party"
    case music = "music"
    case fitness = "fitness"
    
    var id: String { rawValue }
    
    var displayName: String {
        switch self {
        case .career: return "💼 Career"
        case .study: return "📚 Study"
        case .social: return "💬 Social"
        case .party: return "🎉 Party"
        case .music: return "🎵 Music"
        case .fitness: return "💪 Fitness"
        }
    }
}

class FilterMappingService {
    static let shared = FilterMappingService()
    
    private var mappings: [FilterMapping] = []
    private var externalToInternal: [String: String] = [:]
    private var isLoaded = false
    
    init() {
        loadMappings()
    }
    
    private func ensureLoaded() {
        if !isLoaded {
            loadMappings()
        }
    }
    
    private func loadMappings() {
        guard let url = Bundle.main.url(forResource: "filters", withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let decoded = try? JSONDecoder().decode([FilterMapping].self, from: data) else {
            print("⚠️ Failed to load filters.json")
            return
        }
        
        mappings = decoded
        
        // Build lookup dictionary for fast access
        for mapping in mappings {
            externalToInternal[mapping.external.lowercased()] = mapping.internalCategory
        }
        
        isLoaded = true
        print("✅ Loaded \(mappings.count) filter mappings")
    }
    
    /// Map external tags from Firebase to internal filter category
    func mapTagsToCategory(_ tags: [String]) -> FilterCategory? {
        ensureLoaded()
        
        for tag in tags {
            let lowerTag = tag.lowercased()
            
            // Direct match
            if let internalCategory = externalToInternal[lowerTag] {
                return FilterCategory(rawValue: internalCategory)
            }
            
            // Partial match (tag contains external keyword)
            for (external, internalCategory) in externalToInternal {
                if lowerTag.contains(external) || external.contains(lowerTag) {
                    return FilterCategory(rawValue: internalCategory)
                }
            }
        }
        
        return nil
    }
    
    /// Get all external tags that map to a specific internal category
    func getExternalTags(for category: FilterCategory) -> [String] {
        ensureLoaded()
        return mappings
            .filter { $0.internalCategory == category.rawValue }
            .map { $0.external }
    }
    
    /// Check if any tag matches a specific filter category
    func tagsMatchCategory(_ tags: [String], category: FilterCategory) -> Bool {
        ensureLoaded()
        let externalTags = getExternalTags(for: category)
        let lowerTags = tags.map { $0.lowercased() }
        
        for tag in lowerTags {
            for externalTag in externalTags {
                if tag.contains(externalTag.lowercased()) || externalTag.lowercased().contains(tag) {
                    return true
                }
            }
        }
        
        return false
    }
}
