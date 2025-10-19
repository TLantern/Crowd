//
//  LeaderboardView.swift
//  Crowd
//

import SwiftUI

struct LeaderboardView: View {
    @ObservedObject var viewModel: LeaderboardViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            header
            timeframePicker
            entriesList
        }
        .padding(16)
    }

    // MARK: - Sections

    private var header: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Leaderboard")
                .font(.title3.bold())
            Text("Earn Aura by hosting and joining crowds.")
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
        .padding(.top, 4)
    }

    private var timeframePicker: some View {
        HStack(spacing: 8) {
            ForEach(LeaderboardViewModel.Timeframe.allCases, id: \.self) { tf in
                Button {
                    withAnimation(.spring(response: 0.25, dampingFraction: 0.9)) {
                        viewModel.switchTo(tf)
                    }
                } label: {
                    Text(tf.rawValue)
                        .font(.footnote.weight(.semibold))
                        .padding(.vertical, 8)
                        .padding(.horizontal, 12)
                        .background {
                            RoundedRectangle(cornerRadius: 10, style: .continuous)
                                .fill(viewModel.timeframe == tf ? Color.primary.opacity(0.12) : Color.clear)
                        }
                }
            }
            Spacer()
        }
    }

    private var entriesList: some View {
        VStack(spacing: 8) {
            ForEach(viewModel.entries) { e in
                row(e)
            }
        }
    }

    // MARK: - Row (using Apple’s overlay(alignment:content:))

    private func row(_ e: LeaderboardEntry) -> some View {
        HStack(spacing: 12) {
            Text("#\(e.rank)")
                .font(.system(size: 16, weight: .semibold))
                .frame(width: 32, alignment: .leading)

            Circle()
                .fill(e.tint.opacity(0.25))
                .frame(width: 36, height: 36)
                .overlay {
                    Text(initials(from: e.name)).font(.footnote.bold)
                }

            VStack(alignment: .leading, spacing: 2) {
                Text(e.isYou ? "\(e.name) (You)" : e.name)
                    .font(.system(size: 16, weight: .semibold))
                Text(e.handle).font(.caption).foregroundStyle(.secondary)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 2) {
                Text("\(e.points)").font(.system(size: 16, weight: .semibold))
                Text("Aura").font(.caption).foregroundStyle(.secondary)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)

        // Simple + unambiguous:
        .background(.ultraThinMaterial)                                   // concrete View
        .mask(RoundedRectangle(cornerRadius: 14, style: .continuous))     // rounds corners         
    }
    
    // MARK: - Helpers

    private func initials(from name: String) -> String {
        let parts = name.split(separator: " ")
        return String(parts.prefix(2).compactMap { $0.first })
    }
}

#Preview {
    LeaderboardView(viewModel: .init())
}
