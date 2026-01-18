import SwiftUI
import Lottie

struct LottieEyes: View {
    var size: CGFloat = 28
    
    var body: some View {
        LottieEyesView()
            .frame(width: size, height: size)
    }
}

struct LottieEyesView: UIViewRepresentable {
    let loopMode: LottieLoopMode = .loop

    func makeUIView(context: Context) -> UIView {
        let container = UIView()
        container.backgroundColor = UIColor.clear

        // Load animation from bundle
        let animationView = LottieAnimationView(name: "eyes", bundle: .main)

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
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                        