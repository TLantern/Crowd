//
//  OptionsListView.swift
//  Crowd
//
//  Created by Cursor on 12/19/25.
//

import SwiftUI

struct OptionsListView: View {
    let optionsString: String
    let onOptionSelected: ((String) -> Void)?
    
    @State private var visibleOptions: [OptionItem] = []
    @State private var visibleIndices: Set<Int> = []
    
    struct OptionItem: Identifiable {
        let id = UUID()
        let text: String
        let emoji: String?
    }
    
    init(optionsString: String, onOptionSelected: ((String) -> Void)? = nil) {
        self.optionsString = optionsString
        self.onOptionSelected = onOptionSelected
    }
    
    var body: some View {
        VStack(alignment: .center, spacing: 16) {
            ForEach(Array(visibleOptions.enumerated()), id: \.element.id) { index, option in
                BadgeView(
                    title: option.text,
                    emoji: option.emoji,
                    onTap: onOptionSelected != nil ? {
                        onOptionSelected?(option.text)
                    } : nil
                )
                .opacity(visibleIndices.contains(index) ? 1.0 : 0.0)
                .offset(y: visibleIndices.contains(index) ? 0 : -30)
                .animation(
                    .easeOut(duration: 0.4)
                    .delay(Double(index) * 0.1),
                    value: visibleIndices.contains(index)
                )
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 16)
        .padding(.top, 10)
        .padding(.bottom, 12)
        .onAppear {
            parseOptions()
            // Trigger animations with delays for each item
            Task { @MainActor in
                for index in 0..<visibleOptions.count {
                    try? await Task.sleep(nanoseconds: UInt64(Double(index) * 0.1 * 1_000_000_000))
                    visibleIndices.insert(index)
                }
            }
        }
    }
    
    private func parseOptions() {
        let options = optionsString
            .split(separator: ",")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        
        visibleOptions = options.map { option in
            // Extract emoji if present (emoji characters are typically at the start)
            let emojiPattern = #"^[\p{Emoji}]+\s*"#
            if let emojiRange = option.range(of: emojiPattern, options: .regularExpression) {
                let emoji = String(option[emojiRange]).trimmingCharacters(in: .whitespaces)
                let text = String(option[emojiRange.upperBound...]).trimmingCharacters(in: .whitespaces)
                return OptionItem(text: text.isEmpty ? option : text, emoji: emoji.isEmpty ? nil : emoji)
            } else {
                return OptionItem(text: option, emoji: nil)
            }
        }
    }
}

#Preview {
    ScrollView {
        OptionsListView(
            optionsString: "🎉 Party, 🔥 Fire, 🎵 Music, 🍕 Food, 🎮 Games",
            onOptionSelected: { option in
                print("Selected: \(option)")
            }
        )
    }
    .background(Color(.systemBackground))
}

