//
//  InterestFilterDropdown.swift
//  Crowd
//
//  Created by Teni Owojori on 10/26/25.
//

import SwiftUI

struct InterestFilterDropdown: View {
    @Binding var selectedInterests: Set<Interest>
    @State private var isExpanded = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Dropdown Button
            Button(action: {
                withAnimation(.easeInOut(duration: 0.2)) {
                    isExpanded.toggle()
                }
            }) {
                HStack(spacing: 8) {
                    Image(systemName: "tag")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.secondary)
                    
                    if selectedInterests.isEmpty {
                        Text("Vibe")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundColor(.secondary)
                    } else {
                        Text("\(selectedInterests.count)")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundColor(.primary)
                    }
                    
                    Spacer()
                    
                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.secondary)
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(.ultraThinMaterial)
                .cornerRadius(6)
            }
            .buttonStyle(PlainButtonStyle())
            
            // Dropdown Content
            if isExpanded {
                VStack(alignment: .leading, spacing: 0) {
                    Divider()
                        .padding(.vertical, 8)
                    
                    ScrollView {
                        LazyVStack(alignment: .leading, spacing: 4) {
                            ForEach(Interest.allInterests) { interest in
                                InterestFilterRow(
                                    interest: interest,
                                    isSelected: selectedInterests.contains(interest)
                                ) {
                                    toggleInterest(interest)
                                }
                            }
                        }
                        .padding(.horizontal, 4)
                    }
                    .frame(maxHeight: 200)
                }
                .background(.ultraThinMaterial)
                .cornerRadius(8)
                .shadow(color: .black.opacity(0.1), radius: 4, x: 0, y: 2)
                .padding(.top, 4)
            }
        }
        .background(.ultraThinMaterial)
        .cornerRadius(8)
    }
    
    private func toggleInterest(_ interest: Interest) {
        withAnimation(.easeInOut(duration: 0.15)) {
            if selectedInterests.contains(interest) {
                selectedInterests.remove(interest)
            } else {
                selectedInterests.insert(interest)
            }
        }
    }
}

struct InterestFilterRow: View {
    let interest: Interest
    let isSelected: Bool
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 8) {
                Text(interest.emoji)
                    .font(.system(size: 16))
                
                Text(interest.name)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.primary)
                
                Spacer()
                
                if isSelected {
                    Image(systemName: "checkmark")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.accentColor)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .fill(isSelected ? Color.accentColor.opacity(0.1) : Color.clear)
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
}

#Preview {
    InterestFilterDropdown(selectedInterests: .constant([]))
        .padding()
}
