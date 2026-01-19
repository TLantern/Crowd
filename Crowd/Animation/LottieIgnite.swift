//
//  LottieIgnite.swift
//  Crowd
//
//  Created by Teni Owojori on 10/19/25.
//

import SwiftUI
import Lottie

struct LottieIgniteView: UIViewRepresentable {
    let size: CGFloat
    let onCompletion: (() -> Void)?
    
    init(size: CGFloat, onCompletion: (() -> Void)? = nil) {
        self.size = size
        self.onCompletion = onCompletion
    }
    
    func makeCoordinator() -> Coordinator {
        return Coordinator()
    }
    
    func makeUIView(context: Context) -> UIView {
        print("🔥 LottieIgnite: makeUIView called")

        let container = UIView(frame: CGRect(x: 0, y: 0, width: size, height: size))
        container.backgroundColor = UIColor.clear

        let animationView: LottieAnimationView
        if let animation = LottieAnimation.named("ignite") {
            animationView = LottieAnimationView(animation: animation)
            print("🔥 LottieIgnite: AnimationView created - animation: ✅ loaded")
        } else {
            print("❌ LOTTIE FAILED TO LOAD: ignite.json")
            animationView = LottieAnimationView()
        }

        animationView.loopMode = .loop
        animationView.contentMode = .scaleAspectFit

        // 🔥 KEY FIX — DO NOT USE AUTO LAYOUT HERE
        animationView.translatesAutoresizingMaskIntoConstraints = true
        animationView.frame = container.bounds
        animationView.autoresizingMask = [.flexibleWidth, .flexibleHeight]

        container.addSubview(animationView)

        context.coordinator.animationView = animationView

        DispatchQueue.main.async {
            print("🔥 LottieIgnite: Calling play()")
            animationView.play { finished in
                print("🔥 LottieIgnite: Play completed - finished: \(finished), progress: \(animationView.currentProgress)")
                onCompletion?()
            }
        }

        return container
    }
    
    func updateUIView(_ uiView: UIView, context: Context) {
        // No-op: animation plays once and completes
    }
    
    class Coordinator: NSObject {
        var animationView: LottieAnimationView?
    }
}

struct LottieIgnite: View {
    var size: CGFloat = 300
    let onCompletion: (() -> Void)?
    
    var body: some View {
        let screenWidth = UIScreen.main.bounds.width
        let screenHeight = UIScreen.main.bounds.height
        let finalSize = min(size, min(screenWidth, screenHeight) - 40)

        return LottieIgniteView(size: finalSize, onCompletion: onCompletion)
            .frame(width: finalSize, height: finalSize)
    }
}

#Preview {
    ZStack {
        Color(hex: 0xF5F7FA)
            .ignoresSafeArea()
        
        LottieIgnite(size: 300) {
            print("Animation completed!")
        }
    }
}
