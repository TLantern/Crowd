import SwiftUI
import Lottie

struct LottieView: UIViewRepresentable {
    let name: String
    let loopMode: LottieLoopMode

    func makeUIView(context: Context) -> UIView {
        let container = UIView()
        container.backgroundColor = UIColor.clear

        // Load animation using dotLottieName - this works with asset catalog datasets
        let animationView = LottieAnimationView(dotLottieName: name)

        animationView.loopMode = loopMode
        animationView.contentMode = .scaleAspectFit
        animationView.translatesAutoresizingMaskIntoConstraints = false
        animationView.backgroundColor = UIColor.clear

        container.addSubview(animationView)

        NSLayoutConstraint.activate([
            animationView.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            animationView.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            animationView.topAnchor.constraint(equalTo: container.topAnchor),
            animationView.bottomAnchor.constraint(equalTo: container.bottomAnchor)
        ])

        // Play animation after a small delay to ensure view is ready
        DispatchQueue.main.async {
            animationView.play()
            
            // Debug logs at the end
            print("🔥 LottieView: Creating view with name: '\(name)'")
            if animationView.animation == nil {
                print("⚠️ LottieView: Animation is nil for '\(name)'")
            } else {
                print("✅ LottieView: Animation loaded successfully for '\(name)'")
            }
            print("🎬 LottieView: Attempting to play animation '\(name)'")
            print("🎬 LottieView: Animation playing: \(animationView.isAnimationPlaying)")
        }

        return container
    }

    func updateUIView(_ uiView: UIView, context: Context) {
        // Ensure animation keeps playing on update
        for subview in uiView.subviews {
            if let animationView = subview as? LottieAnimationView {
                if !animationView.isAnimationPlaying {
                    animationView.play()
                    print("🔄 LottieView: Restarting animation '\(name)' in updateUIView - Playing: \(animationView.isAnimationPlaying)")
                }
            }
        }
    }
}

struct LottieFire: View {
    var size: CGFloat = 28
    
    var body: some View {
        LottieView(name: "Fire animation", loopMode: .loop)
            .frame(width: size, height: size)
    }
}
