//
//  LeaderboardView.swift
//  Crowd
//

import SwiftUI

struct LeaderboardView: View {
    @ObservedObject var viewModel: LeaderboardViewModel

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                header
                timeframePicker
                
                if viewModel.entries.count >= 3 {
                    podium
                        .padding(.vertical, 20)
                    
                    if viewModel.entries.count > 3 {
                        Divider()
                            .padding(.vertical, 8)
                    }
                }
                
                entriesList
            }
            .padding(16)
        }
    }

    // MARK: - Sections

    private var header: some View {
        VStack(alignment: .center, spacing: 4) {
            Text("Leaderboard").font(.title3.bold())
            Text("Earn Aura by hosting and joining crowds.")
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
        .padding(.top, 4)
    }

    private var timeframePicker: some View {
        HStack(spacing: 8) {
            ForEach(LeaderboardViewModel.Timeframe.allCases) { tf in
                Button {
                    withAnimation(.spring(response: 0.25, dampingFraction: 0.9)) {
                        viewModel.switchTo(tf)
                    }
                } label: {
                    Text(tf.displayName)
                        .font(.footnote.weight(.semibold))
                        .padding(.vertical, 8)
                        .padding(.horizontal, 12)
                        .background(
                            RoundedRectangle(cornerRadius: 10, style: .continuous)
                                .fill(viewModel.timeframe == tf ? Color.primary.opacity(0.12) : .clear)
                        )
                }
            }
        }
        .frame(maxWidth: .infinity)
    }

    private var podium: some View {
        let top3 = Array(viewModel.entries.prefix(3))
        let first = top3[0]
        let second = top3.count > 1 ? top3[1] : nil
        let third = top3.count > 2 ? top3[2] : nil
        
        return HStack(alignment: .bottom, spacing: 16) {
            // 2nd Place (Left)
            if let second = second {
                VStack(spacing: 8) {
                    Text("2")
                        .font(.system(size: 20, weight: .bold))
                        .foregroundColor(.secondary)
                    
                    Circle()
                        .fill(second.tint.opacity(0.25))
                        .overlay(
                            Text(initials(from: second.name))
                                .font(.system(size: 18, weight: .bold))
                        )
                        .frame(width: 60, height: 60)
                    
                    Text(second.name)
                        .font(.system(size: 14, weight: .semibold))
                        .lineLimit(1)
                    
                    Text("\(second.points)")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(.orange)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(Color(.systemBackground))
                .cornerRadius(16)
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(.white.opacity(0.12), lineWidth: 1)
                )
            }
            
            // 1st Place (Center - Highest)
            VStack(spacing: 8) {
                Text("👑")
                    .font(.system(size: 32))
                
                Circle()
                    .fill(first.tint.opacity(0.25))
                    .overlay(
                        Text(initials(from: first.name))
                            .font(.system(size: 22, weight: .bold))
                    )
                    .frame(width: 80, height: 80)
                
                Text(first.name)
                    .font(.system(size: 16, weight: .bold))
                    .lineLimit(1)
                
                Text("\(first.points)")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundColor(.yellow)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 20)
            .background(Color(.systemBackground))
            .cornerRadius(16)
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(.yellow.opacity(0.4), lineWidth: 2)
            )
            .shadow(color: .yellow.opacity(0.3), radius: 10, y: 5)
            
            // 3rd Place (Right)
            if let third = third {
                VStack(spacing: 8) {
                    Text("3")
                        .font(.system(size: 20, weight: .bold))
                        .foregroundColor(.secondary)
                    
                    Circle()
                        .fill(third.tint.opacity(0.25))
                        .overlay(
                            Text(initials(from: third.name))
                                .font(.system(size: 18, weight: .bold))
                        )
                        .frame(width: 60, height: 60)
                    
                    Text(third.name)
                        .font(.system(size: 14, weight: .semibold))
                        .lineLimit(1)
                    
                    Text("\(third.points)")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(.orange)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(Color(.systemBackground))
                .cornerRadius(16)
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(.white.opacity(0.12), lineWidth: 1)
                )
            }
        }
    }
    
    private var entriesList: some View {
        VStack(spacing: 8) {
            ForEach(viewModel.entries.dropFirst(3)) { e in
                row(e)
            }
        }
    }

    // MARK: - Row (mirrors Profile cards)

    private func row(_ e: LeaderboardEntry) -> some View {
        HStack(spacing: 12) {
            Text("#\(e.rank)")
                .font(.system(size: 16, weight: .semibold))
                .frame(width: 32, alignment: .leading)

            Circle()
                .fill(e.tint.opacity(0.25))
                .overlay(
                    Text(initials(from: e.name))
                        .font(.footnote.weight(.bold))   // FIX
                )
                .frame(width: 36, height: 36)

            VStack(alignment: .leading, spacing: 2) {
                Text(e.isYou ? "\(e.name) (You)" : e.name)
                    .font(.system(size: 16, weight: .semibold))
                Text(e.handle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 2) {
                Text("\(e.points)").font(.system(size: 16, weight: .semibold))
                Text("Aura").font(.caption).foregroundStyle(.secondary)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(
            Color(.systemBackground),
            in: RoundedRectangle(cornerRadius: 14, style: .continuous)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(.white.opacity(0.12), lineWidth: 1)
        )
    }

    // MARK: - Helpers

    private func initials(from name: String) -> String {
        let parts = name.split(separator: " ")
        return String(parts.prefix(2).compactMap { $0.first })
    }
}

#Preview {
    LeaderboardView(viewModel: .init())   // uses mockEntries from your VM
}
