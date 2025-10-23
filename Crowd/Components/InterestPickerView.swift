//
//  InterestPickerView.swift
//  Crowd
//
//  Created by Teni Owojori on 10/23/25.
//

import SwiftUI

struct InterestPickerView: View {
    @ObservedObject var viewModel: ProfileViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var searchText = ""
    
    var filteredInterests: [Interest] {
        let available = viewModel.unselectedInterests
        if searchText.isEmpty {
            return available
        }
        return available.filter { interest in
            interest.name.localizedCaseInsensitiveContains(searchText)
        }
    }
    
    var body: some View {
        NavigationView {
            List {
                ForEach(filteredInterests) { interest in
                    Button(action: {
                        viewModel.addInterest(interest)
                        dismiss()
                    }) {
                        HStack(spacing: 12) {
                            Text(interest.emoji)
                                .font(.system(size: 28))
                            
                            Text(interest.name)
                                .font(.system(size: 16))
                                .foregroundStyle(.primary)
                            
                            Spacer()
                            
                            Image(systemName: "plus.circle.fill")
                                .foregroundStyle(Color.accentColor)
                                .font(.system(size: 22))
                        }
                        .padding(.vertical, 4)
                    }
                    .buttonStyle(.plain)
                }
            }
            .searchable(text: $searchText, prompt: "Search interests")
            .navigationTitle("Add Interest")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
        }
    }
}

// MARK: - Preview
#Preview {
    InterestPickerView(viewModel: ProfileViewModel.mock)
}

