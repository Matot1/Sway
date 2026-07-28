import SwiftUI

struct NotchRootView: View {
    @ObservedObject var viewModel: NotchViewModel

    var body: some View {
        ZStack {
            CollapsedNotchView()
            HoveringNotchView()
                .opacity(viewModel.notchState == .hovering ? 1 : 0)
            ExpandedNotchView(viewModel: viewModel)
                .opacity(viewModel.notchState == .expanded ? 1 : 0)
        }
        .animation(.spring(response: 0.35, dampingFraction: 0.8, blendDuration: 0.2), value: viewModel.notchState)
    }
}

struct HoveringNotchView: View {
    @AppStorage("theme") private var theme: String = "dark"

    var body: some View {
        Rectangle()
            .fill(ThemeColors.background(theme))
            .clipShape(BottomRoundedRect(radius: 16))
    }
}

struct CollapsedNotchView: View {
    var body: some View {
        Rectangle()
            .fill(.clear)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

struct BottomRoundedRect: Shape {
    let radius: CGFloat

    func path(in rect: CGRect) -> Path {
        Path { path in
            path.move(to: CGPoint(x: rect.minX, y: rect.minY))
            path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
            path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY - radius))
            path.addArc(tangent1End: CGPoint(x: rect.maxX, y: rect.maxY),
                        tangent2End: CGPoint(x: rect.maxX - radius, y: rect.maxY),
                        radius: radius)
            path.addLine(to: CGPoint(x: rect.minX + radius, y: rect.maxY))
            path.addArc(tangent1End: CGPoint(x: rect.minX, y: rect.maxY),
                        tangent2End: CGPoint(x: rect.minX, y: rect.maxY - radius),
                        radius: radius)
            path.closeSubpath()
        }
    }
}

struct VisualEffectView: NSViewRepresentable {
    let material: NSVisualEffectView.Material
    let blendingMode: NSVisualEffectView.BlendingMode

    func makeNSView(context: Context) -> NSVisualEffectView {
        let view = NSVisualEffectView()
        view.material = material
        view.blendingMode = blendingMode
        view.state = .active
        view.wantsLayer = true
        view.layer?.cornerRadius = 10
        view.layer?.maskedCorners = [.layerMinXMaxYCorner, .layerMaxXMaxYCorner]
        return view
    }

    func updateNSView(_ nsView: NSVisualEffectView, context: Context) {
        nsView.material = material
        nsView.blendingMode = blendingMode
    }
}
