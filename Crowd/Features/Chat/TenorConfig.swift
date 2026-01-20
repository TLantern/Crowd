import Foundation

enum TenorConfig {
    static let key: String = {
        let candidates = ["Secretsconfig", "Secrets"]
        for name in candidates {
            if let url = Bundle.main.url(forResource: name, withExtension: "xcconfig"),
               let contents = try? String(contentsOf: url, encoding: .utf8),
               let value = parseXcconfigValue(contents, key: "TENOR_API_KEY"),
               !value.isEmpty {
                return value
            }
        }
        assertionFailure("Missing TENOR_API_KEY in bundled *.xcconfig")
        return ""
    }()
    
    private static func parseXcconfigValue(_ contents: String, key: String) -> String? {
        for rawLine in contents.split(separator: "\n", omittingEmptySubsequences: false) {
            let line = rawLine.split(separator: "/", maxSplits: 1, omittingEmptySubsequences: false).first.map(String.init) ?? ""
            let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty, !trimmed.hasPrefix("//") else { continue }
            guard trimmed.hasPrefix("\(key)") else { continue }
            guard let eq = trimmed.firstIndex(of: "=") else { continue }
            return trimmed[trimmed.index(after: eq)...].trimmingCharacters(in: .whitespacesAndNewlines)
        }
        return nil
    }
}

