//
//  CalenderView.swift
//  Crowd
//
//  Created by Teni Owojori on 10/23/25.
//

import SwiftUI

struct CalenderView: View {
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                Image(systemName: "calendar")
                    .font(.system(size: 64))
                    .foregroundStyle(.gray.opacity(0.5))
                
                Text("Calendar")
                    .font(.system(size: 28, weight: .bold))
                
                Text("Your upcoming events will appear here")
                    .font(.system(size: 16))
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                
                Spacer()
            }
            .padding(.top, 80)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color(.systemBackground))
            .navigationTitle("Calendar")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 24))
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
    }
}

#Preview {
    CalenderView()
}
