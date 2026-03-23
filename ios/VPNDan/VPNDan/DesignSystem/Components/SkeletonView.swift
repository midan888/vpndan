import SwiftUI

// MARK: - Shimmer Modifier

struct ShimmerModifier: ViewModifier {
    @State private var phase: CGFloat = 0

    func body(content: Content) -> some View {
        content
            .overlay(
                LinearGradient(
                    colors: [
                        Color.clear,
                        Color.white.opacity(0.08),
                        Color.clear,
                    ],
                    startPoint: .leading,
                    endPoint: .trailing
                )
                .rotationEffect(.degrees(20))
                .offset(x: phase)
                .clipped()
            )
            .onAppear {
                withAnimation(.linear(duration: 1.5).repeatForever(autoreverses: false)) {
                    phase = 400
                }
            }
    }
}

extension View {
    func shimmer() -> some View {
        modifier(ShimmerModifier())
    }
}

// MARK: - Skeleton Shapes

struct SkeletonRect: View {
    var width: CGFloat? = nil
    var height: CGFloat = 16
    var radius: CGFloat = VPNRadius.small

    var body: some View {
        RoundedRectangle(cornerRadius: radius)
            .fill(Color.vpnSurfaceLight)
            .frame(width: width, height: height)
            .shimmer()
    }
}

struct SkeletonCircle: View {
    var size: CGFloat = 40

    var body: some View {
        Circle()
            .fill(Color.vpnSurfaceLight)
            .frame(width: size, height: size)
            .shimmer()
    }
}

// MARK: - Skeleton Composites

struct SkeletonServerCard: View {
    var body: some View {
        GlassCard {
            HStack(spacing: VPNSpacing.md) {
                SkeletonCircle(size: 36)
                VStack(alignment: .leading, spacing: VPNSpacing.sm) {
                    SkeletonRect(width: 120, height: 14)
                    SkeletonRect(width: 60, height: 10)
                }
                Spacer()
                SkeletonRect(width: 60, height: 28, radius: 14)
            }
        }
    }
}

struct SkeletonStatsRow: View {
    var body: some View {
        GlassCard(padding: VPNSpacing.sm + VPNSpacing.xs) {
            HStack(spacing: 0) {
                skeletonStat
                Rectangle().fill(Color.vpnBorder.opacity(0.5)).frame(width: 1, height: 32)
                skeletonStat
                Rectangle().fill(Color.vpnBorder.opacity(0.5)).frame(width: 1, height: 32)
                skeletonStat
            }
        }
    }

    private var skeletonStat: some View {
        VStack(spacing: VPNSpacing.sm) {
            SkeletonRect(width: 50, height: 14)
            SkeletonRect(width: 40, height: 10)
        }
        .frame(maxWidth: .infinity)
    }
}

struct SkeletonIPCard: View {
    var body: some View {
        GlassCard {
            HStack {
                VStack(alignment: .leading, spacing: VPNSpacing.sm) {
                    SkeletonRect(width: 50, height: 10)
                    SkeletonRect(width: 140, height: 14)
                    SkeletonRect(width: 100, height: 10)
                }
                Spacer()
                SkeletonCircle(size: 32)
            }
        }
    }
}

struct SkeletonServerRow: View {
    var body: some View {
        HStack(spacing: VPNSpacing.md) {
            SkeletonCircle(size: 32)
            VStack(alignment: .leading, spacing: VPNSpacing.sm) {
                SkeletonRect(width: 100, height: 14)
            }
            Spacer()
            SkeletonCircle(size: 8)
        }
        .padding(.vertical, VPNSpacing.sm)
        .padding(.horizontal, VPNSpacing.md)
    }
}

struct SkeletonServerList: View {
    var count: Int = 5

    var body: some View {
        VStack(spacing: 0) {
            ForEach(0..<count, id: \.self) { index in
                SkeletonServerRow()
                if index < count - 1 {
                    Divider()
                        .background(Color.vpnBorder.opacity(0.5))
                        .padding(.leading, 60)
                }
            }
        }
        .background(
            RoundedRectangle(cornerRadius: VPNRadius.card)
                .fill(.ultraThinMaterial)
        )
        .overlay(
            RoundedRectangle(cornerRadius: VPNRadius.card)
                .stroke(Color.vpnBorder.opacity(0.5), lineWidth: 1)
        )
    }
}

// MARK: - Error State View

struct ErrorStateView: View {
    let message: String
    var retryAction: (() -> Void)?

    var body: some View {
        VStack(spacing: VPNSpacing.md) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 40))
                .foregroundStyle(Color.vpnDisconnected.opacity(0.7))

            Text(message)
                .vpnTextStyle(.body, color: .vpnTextSecondary)
                .multilineTextAlignment(.center)

            if let retryAction {
                Button(action: retryAction) {
                    HStack(spacing: VPNSpacing.sm) {
                        Image(systemName: "arrow.clockwise")
                            .font(.system(size: 14, weight: .semibold))
                        Text("Try Again")
                            .vpnTextStyle(.buttonText)
                    }
                    .foregroundStyle(Color.vpnPrimary)
                    .padding(.horizontal, VPNSpacing.lg)
                    .padding(.vertical, VPNSpacing.sm + VPNSpacing.xs)
                    .background(
                        Capsule()
                            .fill(Color.vpnPrimary.opacity(0.15))
                    )
                }
            }
        }
        .padding(VPNSpacing.xl)
    }
}

#Preview("Skeletons") {
    ZStack {
        Color.vpnBackground.ignoresSafeArea()

        ScrollView {
            VStack(spacing: VPNSpacing.md) {
                SkeletonServerCard()
                SkeletonStatsRow()
                SkeletonIPCard()
                SkeletonServerList()
            }
            .padding()
        }
    }
}

#Preview("Error State") {
    ZStack {
        Color.vpnBackground.ignoresSafeArea()
        ErrorStateView(message: "Unable to load servers.\nCheck your connection.", retryAction: {})
    }
}
