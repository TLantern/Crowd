import SwiftUI
import TenorAPIKit
import SDWebImageSwiftUI

struct TenorGifPickerSheet: View {
    let key: String
    let onSelect: (TenorGifSelection) -> Void
    @Environment(\.dismiss) private var dismiss
    
    @State private var searchText = ""
    @State private var isLoading = false
    @State private var gifs: [TenorGifSelection] = []
    @State private var suggestions: [String] = []
    @State private var pos: String?
    
    private let service = TenorService()
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 12) {
                HStack(spacing: 10) {
                    TextField("Search GIFs", text: $searchText)
                        .textFieldStyle(.roundedBorder)
                        .onSubmit { search() }
                    
                    Button("Search") { search() }
                        .disabled(searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isLoading)
                }
                .padding(.horizontal, 16)
                .padding(.top, 8)
                
                if !suggestions.isEmpty && searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(suggestions, id: \.self) { term in
                                Button(term) {
                                    searchText = term
                                    search()
                                }
                                .buttonStyle(.bordered)
                            }
                        }
                        .padding(.horizontal, 16)
                    }
                }
                
                ScrollView {
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 110), spacing: 10)], spacing: 10) {
                        ForEach(gifs.indices, id: \.self) { idx in
                            let gif = gifs[idx]
                            Button {
                                onSelect(gif)
                                dismiss()
                            } label: {
                                WebImage(url: URL(string: gif.preview))
                                    .resizable()
                                    .indicator(.activity)
                                    .transition(.fade(duration: 0.15))
                                    .scaledToFill()
                                    .background(Color(uiColor: .secondarySystemBackground))
                                .frame(height: 110)
                                .clipShape(RoundedRectangle(cornerRadius: 10))
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.bottom, 16)
                }
            }
            .navigationTitle("GIFs")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Close") { dismiss() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    if isLoading { ProgressView().controlSize(.small) }
                }
            }
            .task { loadTrending() }
        }
    }
    
    private func loadTrending() {
        isLoading = true
        
        service.getCategories(key: key) { _ in }
        
        service.getTrendingTags(key: key, limit: 10) { terms in
            DispatchQueue.main.async {
                self.suggestions = Self.extractStrings(from: terms)
            }
        }
        
        service.getTrendingGifs(key: key, limit: 30, pos: nil) { tenorResults in
            DispatchQueue.main.async {
                self.isLoading = false
                guard let tenorResults else { return }
                self.pos = Self.extractString(from: tenorResults, keys: ["next", "pos"])
                self.gifs = Self.extractGifs(from: tenorResults)
            }
        }
    }
    
    private func search() {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { return }
        isLoading = true
        
        service.getSearchSuggestions(key: key, searchKey: query, limit: 10, pos: nil) { terms in
            DispatchQueue.main.async {
                self.suggestions = Self.extractStrings(from: terms)
            }
        }
        
        service.getAutocompleteTags(key: key, query: query, limit: 5) { _ in }
        
        service.searchGifs(key: key, searchKey: query, limit: 30, pos: nil) { results in
            DispatchQueue.main.async {
                self.isLoading = false
                guard let results else { return }
                self.pos = Self.extractString(from: results, keys: ["next", "pos"])
                self.gifs = Self.extractGifs(from: results)
            }
        }
    }
    
    private static func extractStrings(from any: Any) -> [String] {
        if let arr = any as? [Any] {
            return arr.compactMap { extractString(from: $0) }.filter { !$0.isEmpty }
        }
        return []
    }
    
    private static func extractGifs(from results: Any) -> [TenorGifSelection] {
        guard let arr = extractAnyArray(from: results, keys: ["results", "gifs"]) else { return [] }
        return arr.compactMap { anyGif in
            guard let url = extractHttpString(from: anyGif, keys: ["url", "gifUrl", "sourceUrl", "gif"]),
                  let preview = extractHttpString(from: anyGif, keys: ["preview", "previewUrl", "thumbnailUrl", "tinygif", "nanogif", "mediumgif", "gif"]),
                  !url.isEmpty, !preview.isEmpty
            else { return nil }
            
            return TenorGifSelection(
                url: url,
                preview: preview,
                width: extractInt(from: anyGif, keys: ["width", "w"]) ?? 0,
                height: extractInt(from: anyGif, keys: ["height", "h"]) ?? 0,
                tags: extractStringArray(from: anyGif, keys: ["tags"]) ?? [],
                isNsfw: extractBool(from: anyGif, keys: ["isNsfw", "nsfw"]) ?? false
            )
        }
    }
    
    private static func extractAnyArray(from any: Any, keys: [String]) -> [Any]? {
        for key in keys {
            if let arr = mirrorValue(any, key: key) as? [Any] { return arr }
        }
        if let arr = any as? [Any] { return arr }
        return nil
    }
    
    private static func extractString(from any: Any, keys: [String]? = nil) -> String? {
        if let s = any as? String { return s }
        if let keys {
            for key in keys {
                if let s = mirrorValue(any, key: key) as? String { return s }
            }
        }
        let m = Mirror(reflecting: any)
        for child in m.children {
            if let s = child.value as? String { return s }
        }
        return nil
    }
    
    private static func extractHttpString(from any: Any, keys: [String]) -> String? {
        for key in keys {
            if let s = mirrorValue(any, key: key) as? String, isDirectMediaUrl(s) { return s }
        }
        for key in keys {
            if let v = mirrorValue(any, key: key), let s = extractFirstHttpDeep(v, depth: 4), isDirectMediaUrl(s) { return s }
        }
        return extractFirstHttpDeep(any, depth: 4)
    }
    
    private static func extractFirstHttpDeep(_ any: Any, depth: Int) -> String? {
        guard depth > 0 else { return nil }
        if let s = any as? String, isDirectMediaUrl(s) { return s }
        for child in Mirror(reflecting: any).children {
            if let s = extractFirstHttpDeep(child.value, depth: depth - 1) { return s }
        }
        return nil
    }
    
    private static func isHttpUrl(_ s: String) -> Bool {
        s.hasPrefix("http://") || s.hasPrefix("https://")
    }
    
    private static func isDirectMediaUrl(_ s: String) -> Bool {
        guard isHttpUrl(s), let url = URL(string: s) else { return false }
        if let host = url.host?.lowercased() {
            // Tenor direct assets live here; page URLs (tenor.com/view/...) are HTML.
            if host.contains("media.tenor.com") || host.hasSuffix("tenor.com") == false { /* allow other cdns */ }
        }
        let lower = s.lowercased()
        if lower.contains("tenor.com/view/") { return false }
        if lower.contains("tenor.com/search/") { return false }
        if lower.contains("tenor.com/") && !lower.contains("media.tenor.com") { return false }
        let ext = url.pathExtension.lowercased()
        if ["gif", "webp", "png", "jpg", "jpeg"].contains(ext) { return true }
        // Some Tenor media URLs omit extensions but are still direct assets.
        if (url.host ?? "").lowercased().contains("media.tenor.com") { return true }
        return false
    }
    
    private static func extractInt(from any: Any, keys: [String]) -> Int? {
        for key in keys {
            if let v = mirrorValue(any, key: key) as? Int { return v }
            if let v = mirrorValue(any, key: key) as? Double { return Int(v) }
            if let v = mirrorValue(any, key: key) as? String, let i = Int(v) { return i }
        }
        return nil
    }
    
    private static func extractBool(from any: Any, keys: [String]) -> Bool? {
        for key in keys {
            if let v = mirrorValue(any, key: key) as? Bool { return v }
            if let v = mirrorValue(any, key: key) as? Int { return v != 0 }
            if let v = mirrorValue(any, key: key) as? String { return (v as NSString).boolValue }
        }
        return nil
    }
    
    private static func extractStringArray(from any: Any, keys: [String]) -> [String]? {
        for key in keys {
            if let v = mirrorValue(any, key: key) as? [String] { return v }
            if let v = mirrorValue(any, key: key) as? [Any] {
                return v.compactMap { $0 as? String }
            }
        }
        return nil
    }
    
    private static func mirrorValue(_ any: Any, key: String) -> Any? {
        for child in Mirror(reflecting: any).children {
            if child.label == key { return child.value }
        }
        return nil
    }
}

