//
//  CrowdHomeView.swift
//  Crowd
//
//  Created by Teni Owojori on 10/19/25.
//

import SwiftUI
import MapKit

struct CrowdHomeView: View {
    // MARK: - Region & camera
    @State private var selectedRegion: CampusRegion = .mainCampus
    @State private var cameraPosition: MapCameraPosition = .automatic
    @State private var currentCamera = MapCamera(
        centerCoordinate: .init(latitude: 33.210081, longitude: -97.147700),
        distance: 1200
    )

    // MARK: - UI state
    @State private var showHostSheet = false
    @State private var hostedEvents: [CrowdEvent] = []

    // MARK: - Bottom overlay routing
    enum OverlayRoute { case none, profile, leaderboard }
    @State private var route: OverlayRoute = .none
    @State private var overlayPresented = false
    @State private var overlaySnapIndex = 0 // 0 = peek, 1 = open

    // MARK: - Floating button navigation
    @State private var showMessages = false
    @State private var showCalendar = false

    var body: some View {
        NavigationStack {
            ZStack {
                // === MAP ===
                Map(position: $cameraPosition)
                    .mapControls { MapCompass() }
                    .ignoresSafeArea()
                    .onAppear { snapTo(selectedRegion) }
                    .onChange(of: selectedRegion) { _, new in snapTo(new) }
                    .onMapCameraChange { ctx in
                        currentCamera = ctx.camera
                        let spec = selectedRegion.spec
                        let clamped = min(max(ctx.camera.distance, spec.minZoom), spec.maxZoom)
                        if abs(clamped - ctx.camera.distance) > 1 {
                            cameraPosition = .camera(
                                MapCamera(
                                    centerCoordinate: ctx.camera.centerCoordinate,
                                    distance: clamped,
                                    heading: ctx.camera.heading,
                                    pitch: ctx.camera.pitch
                                )
                            )
                        }
                    }

                // === OVERLAYS & CONTROLS ===
                GeometryReader { geo in
                    // Panel metrics shared by panel and floating buttons
                    let panelWidth  = min(geo.size.width * 0.84, 520)
                    let panelHeight: CGFloat = 140

                    VStack(spacing: 0) {
                        // === Top region selector pill (moved higher without affecting bottom glass) ===
                        HStack {
                            Spacer()

                            Menu {
                                ForEach(CampusRegion.allCases) { region in
                                    Button(region.rawValue) { selectedRegion = region }
                                }
                            } label: {
                                GlassPill(height: 48, horizontalPadding: 20) {
                                    HStack(spacing: 10) {
                                        Text("🔥")
                                        Text(selectedRegion.rawValue)
                                            .font(.system(size: 16, weight: .semibold))
                                            .foregroundStyle(.black)
                                            .lineLimit(1)
                                        Image(systemName: "chevron.down")
                                            .font(.system(size: 14, weight: .semibold))
                                            .foregroundStyle(.black.opacity(0.8))
                                    }
                                    .padding(.horizontal, 12)
                                }
                            }
                            .fixedSize()
                            .frame(maxWidth: geo.size.width * 0.9)

                            Spacer()
                        }
                        .padding(.top, 0)
                        .offset(y: -18) // raise just the navbar; tweak -10…-28 to taste
                        .zIndex(5)

                        Spacer(minLength: 0)

                        // Bottom frosted panel + FAB cluster
                        ZStack {
                            // Frosted base
                            RoundedRectangle(cornerRadius: 32, style: .continuous)
                                .fill(.ultraThinMaterial)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 32, style: .continuous)
                                        .stroke(.white.opacity(0.12), lineWidth: 1)
                                )
                                .background(
                                    RoundedRectangle(cornerRadius: 32, style: .continuous)
                                        .fill(Color.white.opacity(0.08))
                                )
                                .shadow(color: .black.opacity(0.12), radius: 14, x: 0, y: 8)
                                .frame(width: panelWidth, height: panelHeight)
                                .allowsHitTesting(false)

                            VStack(spacing: 10) {
                                let fabSize: CGFloat = 72
                                let centerYOffset: CGFloat = -14
                                let spread = panelWidth * 0.35
                                let sideYOffset: CGFloat = panelHeight * 0.16

                                ZStack {
                                    // Center FAB — Host
                                    FABPlusButton(size: fabSize, color: Color(hex: 0x02853E)) {
                                        showHostSheet = true
                                        Haptics.light()
                                    }
                                    .offset(y: centerYOffset)

                                    // Left — Profile (open at 3/4 screen)
                                    FrostedIconButton(
                                        systemName: "person",
                                        baseSize: 54,
                                        targetSize: 72,
                                        frostOpacity: 0.22,
                                        iconBaseColor: .black,
                                        highlightColor: Color(red: 0.63, green: 0.82, blue: 1.0)
                                    ) {
                                        route = .profile
                                        overlaySnapIndex = 1
                                        overlayPresented = true
                                        Haptics.light()
                                    }
                                    .accessibilityLabel("Open profile")
                                    .offset(x: -spread, y: sideYOffset)

                                    // Right — Leaderboard
                                    FrostedIconButton(
                                        systemName: "trophy",
                                        baseSize: 54,
                                        targetSize: 72,
                                        frostOpacity: 0.22,
                                        iconBaseColor: .black,
                                        highlightColor: .yellow
                                    ) {
                                        route = .leaderboard
                                        overlaySnapIndex = 0
                                        overlayPresented = true
                                        Haptics.light()
                                    }
                                    .accessibilityLabel("Open leaderboard")
                                    .offset(x: spread, y: sideYOffset)
                                }

                                Text("Start a Crowd")
                                    .font(.system(size: 16, weight: .bold))
                                    .foregroundStyle(.black.opacity(0.78))
                                    .padding(.top, -8)
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.bottom, 20)
                    }

                    // === FLOATING GLASS BUTTONS ===
                    VStack(alignment: .trailing, spacing: 16) {
                        GlassIconButton(systemName: "message.fill") { showMessages = true }
                        GlassIconButton(systemName: "calendar") { showCalendar = true }
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomTrailing)
                    .padding(.trailing, 24)
                    // sit above the panel regardless of screen height
                    .padding(.bottom, panelHeight + 28)
                }

                // === BOTTOM SHEET OVER MAP ===
                BottomOverlay(
                    isPresented: $overlayPresented,
                    snapIndex: $overlaySnapIndex,
                    snapFractions: [0.25, 0.75],
                    onDismiss: { route = .none }
                ) {
                    switch route {
                    case .profile:
                        ProfileView(viewModel: ProfileViewModel.mock)
                            .padding(.horizontal, 16)
                            .padding(.top, 2)
                    case .leaderboard:
                        LeaderboardView(viewModel: LeaderboardViewModel())
                            .padding(.horizontal, 16)
                            .padding(.top, 2)
                    case .none:
                        EmptyView()
                    }
                }
                .ignoresSafeArea(edges: .bottom)
                .onChange(of: route) { _, r in
                    if r == .profile { overlaySnapIndex = 1 }
                }
                .fullScreenCover(isPresented: $showMessages) { MessagesView() }
                .fullScreenCover(isPresented: $showCalendar) { CalenderView() }
            }
        }
        .sheet(isPresented: $showHostSheet) {
            HostEventSheet(defaultRegion: selectedRegion) { hostedEvents.append($0) }
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
        }
    }

    // MARK: - Camera snap helper
    private func snapTo(_ region: CampusRegion) {
        withAnimation(.easeInOut(duration: 0.35)) {
            cameraPosition = MapCameraController.position(from: region.spec)
        }
    }
}

// MARK: - Tiny haptics helper
enum Haptics {
    static func light() { UIImpactFeedbackGenerator(style: .light).impactOccurred() }
}

// MARK: - Reusable Bottom Overlay
private struct BottomOverlay<Content: View>: View {
    @Binding var isPresented: Bool
    @Binding var snapIndex: Int                 // 0 = peek, 1 = open
    var snapFractions: [CGFloat] = [0.35, 0.70] // of available height
    var onDismiss: () -> Void = {}
    @ViewBuilder var content: () -> Content

    @State private var translation: CGFloat = 0

    var body: some View {
        GeometryReader { geo in
            let totalH = geo.size.height
            let peekH  = totalH * (snapFractions[safe: 0] ?? 0.35)
            let openH  = totalH * (snapFractions[safe: 1] ?? 0.70)
            let targets = [peekH, openH]

            if isPresented {
                Color.black
                    .opacity(backdropOpacity(targets: targets))
                    .ignoresSafeArea()
                    .onTapGesture { dismiss() }
                    .accessibilityLabel("Close")
            }

            VStack(spacing: 0) {
                RoundedRectangle(cornerRadius: 3, style: .continuous)
                    .fill(.primary.opacity(0.35))
                    .frame(width: 36, height: 6)
                    .padding(.top, 8)
                    .padding(.bottom, 6)

                content()
                    .padding(.bottom, 16)
                    .frame(maxHeight: .infinity, alignment: .top)
                    .clipped()
            }
            .frame(height: currentHeight(targets: targets))
            .frame(maxWidth: .infinity)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .strokeBorder(.white.opacity(0.12), lineWidth: 1)
            )
            .shadow(color: .black.opacity(0.12), radius: 14, x: 0, y: 8)
            .frame(maxHeight: .infinity, alignment: .bottom)
            .offset(y: isPresented ? 0 : totalH)
            .animation(.interactiveSpring(response: 0.28, dampingFraction: 0.88, blendDuration: 0.15), value: isPresented)
            .gesture(dragGesture(targets: targets))
            .onChange(of: isPresented) { _, new in
                if !new { translation = 0 }
            }
        }
        .allowsHitTesting(isPresented)
        .accessibilityAddTraits(.isModal)
    }

    private func currentHeight(targets: [CGFloat]) -> CGFloat {
        guard isPresented else { return 0 }
        let base = targets[clamped: snapIndex]
        return max(0, base - translation)
    }

    private func dragGesture(targets: [CGFloat]) -> some Gesture {
        DragGesture(minimumDistance: 2, coordinateSpace: .global)
            .onChanged { value in
                let dy = value.translation.height
                translation = max(0, dy)
            }
            .onEnded { _ in
                defer { translation = 0 }
                let base = targets[clamped: snapIndex]
                if translation > base * 0.4 {
                    if snapIndex == 0 {
                        dismiss()
                    } else {
                        snapIndex = max(0, snapIndex - 1)
                    }
                } else {
                    snapIndex = min(snapIndex + 1, targets.count - 1)
                }
                Haptics.light()
            }
    }

    private func dismiss() {
        withAnimation(.spring(response: 0.28, dampingFraction: 0.95)) {
            isPresented = false
        }
        onDismiss()
    }

    private func backdropOpacity(targets: [CGFloat]) -> Double {
        guard isPresented else { return 0 }
        let open = (targets.last ?? 1)
        let visible = min(1, currentHeight(targets: targets) / open)
        return Double(0.45 * visible)
    }
}

// MARK: - Safe indexing helpers
private extension Array where Element == CGFloat {
    subscript(safe index: Int) -> CGFloat? {
        indices.contains(index) ? self[index] : nil
    }
    subscript(clamped index: Int) -> CGFloat {
        if isEmpty { return 0 }
        return self[Swift.max(0, Swift.min(index, count - 1))]
    }
}

#Preview { CrowdHomeView() }
