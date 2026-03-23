import SwiftUI

struct GradientButton: View {
    let title: String
    var isLoading: Bool = false
    var isDisabled: Bool = false
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Group {
                if isLoading {
                    ProgressView()
                        .tint(.white)
                } else {
                    Text(title)
                        .vpnTextStyle(.buttonText)
                }
            }
            .frame(maxWidth: .infinity)
            .frame(height: 52)
            .background(
                RoundedRectangle(cornerRadius: VPNRadius.button)
                    .fill(
                        isDisabled
                            ? AnyShapeStyle(Color.vpnInactive)
                            : AnyShapeStyle(Color.vpnPrimaryGradient)
                    )
            )
        }
        .disabled(isDisabled || isLoading)
    }
}

// MARK: - Secondary Button Style

struct SecondaryButton: View {
    let title: String
    var isLoading: Bool = false
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Group {
                if isLoading {
                    ProgressView()
                        .tint(.vpnPrimary)
                } else {
                    Text(title)
                        .vpnTextStyle(.buttonText, color: .vpnPrimary)
                }
            }
            .frame(maxWidth: .infinity)
            .frame(height: 52)
            .background(
                RoundedRectangle(cornerRadius: VPNRadius.button)
                    .stroke(Color.vpnPrimary, lineWidth: 1.5)
            )
        }
    }
}

#Preview {
    ZStack {
        Color.vpnBackground.ignoresSafeArea()

        VStack(spacing: VPNSpacing.md) {
            GradientButton(title: "Connect") {}
            GradientButton(title: "Loading...", isLoading: true) {}
            GradientButton(title: "Disabled", isDisabled: true) {}
            SecondaryButton(title: "Secondary Action") {}
        }
        .padding(VPNSpacing.xl)
    }
}
