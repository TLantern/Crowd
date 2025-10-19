//
//  ProfileView.swift
//  Crowd
//
//  Created by Teni Owojori on 10/19/25.
//

import SwiftUI

struct ProfileView: View {
    @ObservedObject var viewModel: ProfileViewModel

    var body: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(alignment: .leading, spacing: 16) {
                header
                statsRow
                actions
            }
            .padding(16)
        }
    }

    private var header: some View {
        HStack(spacing: 14) {
            Circle()
                .fill(viewModel.avatarColor.opacity(0.25))
                .overlay(
                    Text(initials(from: viewModel.displayName))
                        .font(.system(size: 22, weight: .bold))
                )
                .frame(width: 56, height: 56)

            VStack(alignment: .leading, spacing: 4) {
                Text(viewModel.displayName)
                    .font(.system(size: 20, weight: .semibold))
                Text(viewModel.handle)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            VStack(alignment: .trailing) {
                Text("\(viewModel.points)")
                    .font(.system(size: 22, weight: .bold))
                Text("Aura")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.top, 4)
    }

    private var statsRow: some View {
        HStack(spacing: 12) {
            statCard(title: "Streak", value: "\(viewModel.weeklyStreak) wk")
            statCard(title: "Joined", value: "\(viewModel.joinedCount)")
            statCard(title: "Hosted", value: "\(viewModel.hostedCount)")
        }
    }

    private func statCard(title: String, value: String) -> some View {
        VStack(spacing: 6) {
            Text(value).font(.system(size: 18, weight: .semibold))
            Text(title).font(.caption).foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 14)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(.white.opacity(0.12), lineWidth: 1))
    }

    private var actions: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Actions")
                .font(.subheadline.bold())
                .foregroundStyle(.secondary)
                .padding(.top, 8)

            Group {
                actionRow(icon: "pencil", title: "Edit Profile")
                actionRow(icon: "bell", title: "Notifications")
                actionRow(icon: "gearshape", title: "Settings")
                actionRow(icon: "rectangle.portrait.and.arrow.right", title: "Log Out")
            }
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 14))
        }
    }

    private func actionRow(icon: String, title: String) -> some View {
        HStack {
            Image(systemName: icon).frame(width: 22)
            Text(title)
            Spacer()
            Image(systemName: "chevron.right")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 12)
    }

    private func initials(from name: String) -> String {
        let parts = name.split(separator: " ")
        return String(parts.prefix(2).compactMap { $0.first })
    }
}

#Preview {
    ProfileView(viewModel: .mock)
}
