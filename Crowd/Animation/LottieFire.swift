import SwiftUI
import Lottie

struct LottieView: UIViewRepresentable {
    let name: String
    let loopMode: LottieLoopMode
    let animationSpeed: CGFloat

    init(name: String, loopMode: LottieLoopMode, animationSpeed: CGFloat = 1.0) {
        self.name = name
        self.loopMode = loopMode
        self.animationSpeed = animationSpeed
    }

    func makeUIView(context: Context) -> UIView {
        let container = UIView()
        container.backgroundColor = UIColor.clear

        // Load animation from bundle - using name:bundle: like LottieEyes
        let animationView = LottieAnimationView(name: name, bundle: .main)

        animationView.loopMode = loopMode
        animationView.animationSpeed = animationSpeed
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
        }

        return container
    }

    func updateUIView(_ uiView: UIView, context: Context) {
        // Ensure animation keeps playing on update
        for subview in uiView.subviews {
            if let animationView = subview as? LottieAnimationView {
                if !animationView.isAnimationPlaying {
                    animationView.play()
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
