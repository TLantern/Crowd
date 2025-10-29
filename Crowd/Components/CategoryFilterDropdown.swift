//
//  CategoryFilterDropdown.swift
//  Crowd
//
//  Created by Teni Owojori on 10/27/25.
//

import SwiftUI

struct CategoryFilterDropdown: View {
    @Binding var selectedCategories: Set<EventCategory>
    
    var body: some View {
        Menu {
            // Clear all option
            Button(action: {
                withAnimation(.easeInOut(duration: 0.2)) {
                    selectedCategories.removeAll()
                }
            }) {
                Label("All Events", systemImage: "tag")
            }
            
            Divider()
            
            // Category options
            ForEach(EventCategory.allCases) { category in
                Button(action: {
                    toggleCategory(category)
                }) {
                    HStack {
                        Text(category.displayName)
                        Spacer()
                        if selectedCategories.contains(category) {
                            Image(systemName: "checkmark")
                                .foregroundColor(.accentColor)
                        }
                    }
                }
            }
        } label: {
            HStack(spacing: 8) {
                Image(systemName: "tag")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.secondary)
                
                if selectedCategories.isEmpty {
                    Text("All Events")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(.secondary)
                } else {
                    Text("\(selectedCategories.count) categories")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(.primary)
                }
                
                Spacer()
                
                Image(systemName: "chevron.down")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.secondary)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(.ultraThinMaterial)
            .cornerRadius(6)
        }
        .buttonStyle(PlainButtonStyle())
    }
    
    private func toggleCategory(_ category: EventCategory) {
        withAnimation(.easeInOut(duration: 0.15)) {
            if selectedCategories.contains(category) {
                selectedCategories.remove(category)
            } else {
                selectedCategories.insert(category)
            }
        }
    }
}


#Preview {
    CategoryFilterDropdown(selectedCategories: .constant([]))
        .padding()
}
