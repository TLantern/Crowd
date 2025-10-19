//
//  RegionPickerPill.swift
//  Crowd
//

import SwiftUI

struct RegionPickerPill: View {
    @Binding var selected: CampusRegion
    @State private var show = false

    var body: some View {
        Button {
            withAnimation(.spring()) { show.toggle() }
        } label: {
            GlassPill(text: selected.rawValue, icon: "flame.fill")
        }
        .overlay(alignment: .top) {
            if show {
                VStack(spacing: 8) {
                    ForEach(CampusRegion.allCases) { region in
                        Button {
                            withAnimation(.spring()) {
                                selected = region
                                show = false
                            }
                        } label: {
                            Text(region.rawValue)
                                .padding(.vertical, 8)
                                .frame(maxWidth: .infinity)
                                .background(.ultraThinMaterial,
                                            in: RoundedRectangle(cornerRadius: 16))
                        }
                    }
                }
                .padding(.top, 56)
            }
        }
    }
}
