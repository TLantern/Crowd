import SwiftUI
import Lottie

struct LottiePulse: View {
    var size: CGFloat = 60
    
    var body: some View {
        LottieView(name: "pulse", loopMode: .loop, animationSpeed: 1.0)
            .frame(width: size, height: size)
            .allowsHitTesting(false)
    }
}
