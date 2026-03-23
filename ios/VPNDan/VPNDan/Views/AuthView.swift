import SwiftUI
import AuthenticationServices

struct AuthView: View {
    @State private var selectedTab = 0

    var body: some View {
        ZStack {
            // Background
            Color.vpnBackground.ignoresSafeArea()

            // Gradient orb
            RadialGradient(
                colors: [Color.vpnPrimary.opacity(0.2), Color.clear],
                center: .top,
                startRadius: 20,
                endRadius: 400
            )
            .ignoresSafeArea()

            ScrollView {
                VStack(spacing: VPNSpacing.xl) {
                    // Logo
                    VStack(spacing: VPNSpacing.sm) {
                        Image(systemName: "shield.fill")
                            .font(.system(size: 48))
                            .foregroundStyle(Color.vpnPrimaryGradient)

                        Text("VPN GOD")
                            .font(.system(size: 32, weight: .bold, design: .default))
                            .foregroundStyle(Color.vpnTextPrimary)
                    }
                    .padding(.top, 60)

                    // Segmented control
                    CustomSegmentedControl(selectedTab: $selectedTab)
                        .padding(.horizontal, VPNSpacing.xl)

                    // Forms
                    Group {
                        if selectedTab == 0 {
                            LoginFormView()
                        } else {
                            RegisterFormView()
                        }
                    }
                    .padding(.horizontal, VPNSpacing.xl)
                    .animation(.easeInOut(duration: 0.25), value: selectedTab)
                }
                .padding(.bottom, VPNSpacing.xxl)
            }
            .scrollIndicators(.hidden)
            .scrollDismissesKeyboard(.interactively)
        }
    }
}

// MARK: - Custom Segmented Control

struct CustomSegmentedControl: View {
    @Binding var selectedTab: Int
    private let tabs = ["Sign In", "Create Account"]

    var body: some View {
        HStack(spacing: 0) {
            ForEach(Array(tabs.enumerated()), id: \.offset) { index, title in
                Button {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        selectedTab = index
                    }
                } label: {
                    Text(title)
                        .vpnTextStyle(.buttonText, color: selectedTab == index ? .vpnTextPrimary : .vpnTextTertiary)
                        .frame(maxWidth: .infinity)
                        .frame(height: 44)
                        .background(
                            RoundedRectangle(cornerRadius: VPNRadius.small)
                                .fill(selectedTab == index ? Color.vpnSurfaceLight : Color.clear)
                        )
                }
            }
        }
        .padding(VPNSpacing.xs)
        .background(
            RoundedRectangle(cornerRadius: VPNRadius.small + VPNSpacing.xs)
                .fill(Color.vpnSurface)
        )
        .overlay(
            RoundedRectangle(cornerRadius: VPNRadius.small + VPNSpacing.xs)
                .stroke(Color.vpnBorder, lineWidth: 1)
        )
    }
}

// MARK: - Login Form

struct LoginFormView: View {
    @State private var viewModel = LoginViewModel()
    @Environment(AuthService.self) private var auth
    @State private var shakeError = false

    var body: some View {
        VStack(spacing: VPNSpacing.md) {
            // Error message
            if let error = auth.error {
                errorBanner(error)
            }

            // Fields
            VPNTextField(
                placeholder: "Email",
                text: $viewModel.email,
                textContentType: .emailAddress,
                keyboardType: .emailAddress
            )

            VPNTextField(
                placeholder: "Password",
                text: $viewModel.password,
                isSecure: true,
                textContentType: .password
            )

            // Login button
            GradientButton(
                title: "Sign In",
                isLoading: auth.isLoading,
                isDisabled: !viewModel.isValid
            ) {
                Task { await auth.login(email: viewModel.email, password: viewModel.password) }
            }
            .padding(.top, VPNSpacing.sm)

            // Divider
            dividerRow

            // Apple Sign In
            appleSignInButton

            // Forgot password
            Button {
                // No backend support yet
            } label: {
                Text("Forgot password?")
                    .vpnTextStyle(.caption, color: .vpnPrimary)
            }
            .padding(.top, VPNSpacing.sm)
        }
        .modifier(ShakeModifier(shakes: shakeError ? 2 : 0))
        .onChange(of: auth.error) { _, newError in
            if newError != nil {
                withAnimation(.default) { shakeError = true }
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) { shakeError = false }
            }
        }
        .onDisappear { auth.clearError() }
    }
}

// MARK: - Register Form

struct RegisterFormView: View {
    @State private var viewModel = RegisterViewModel()
    @Environment(AuthService.self) private var auth
    @State private var shakeError = false

    var body: some View {
        VStack(spacing: VPNSpacing.md) {
            // Error message
            if let error = auth.error {
                errorBanner(error)
            }

            // Fields
            VPNTextField(
                placeholder: "Email",
                text: $viewModel.email,
                textContentType: .emailAddress,
                keyboardType: .emailAddress
            )

            VPNTextField(
                placeholder: "Password (min. 8 characters)",
                text: $viewModel.password,
                isSecure: true,
                textContentType: .newPassword
            )

            VPNTextField(
                placeholder: "Confirm Password",
                text: $viewModel.confirmPassword,
                isSecure: true,
                textContentType: .newPassword
            )

            // Password mismatch
            if !viewModel.passwordsMatch && !viewModel.confirmPassword.isEmpty {
                HStack(spacing: VPNSpacing.xs) {
                    Image(systemName: "exclamationmark.circle.fill")
                        .font(.system(size: 12))
                    Text("Passwords don't match")
                        .vpnTextStyle(.statusBadge)
                }
                .foregroundStyle(Color.vpnDisconnected)
                .frame(maxWidth: .infinity, alignment: .leading)
                .transition(.opacity.combined(with: .move(edge: .top)))
            }

            // Register button
            GradientButton(
                title: "Create Account",
                isLoading: auth.isLoading,
                isDisabled: !viewModel.isValid
            ) {
                Task { await auth.register(email: viewModel.email, password: viewModel.password) }
            }
            .padding(.top, VPNSpacing.sm)

            // Divider
            dividerRow

            // Apple Sign In
            appleSignInButton
        }
        .animation(.easeInOut(duration: 0.2), value: viewModel.passwordsMatch)
        .modifier(ShakeModifier(shakes: shakeError ? 2 : 0))
        .onChange(of: auth.error) { _, newError in
            if newError != nil {
                withAnimation(.default) { shakeError = true }
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) { shakeError = false }
            }
        }
        .onDisappear { auth.clearError() }
    }
}

// MARK: - Shared Components

private func errorBanner(_ message: String) -> some View {
    HStack(spacing: VPNSpacing.sm) {
        Image(systemName: "exclamationmark.triangle.fill")
            .font(.system(size: 14))
            .foregroundStyle(Color.vpnDisconnected)

        Text(message)
            .vpnTextStyle(.caption, color: .vpnDisconnected)
            .multilineTextAlignment(.leading)

        Spacer()
    }
    .padding(VPNSpacing.md)
    .background(
        RoundedRectangle(cornerRadius: VPNRadius.small)
            .fill(Color.vpnDisconnected.opacity(0.1))
    )
    .overlay(
        RoundedRectangle(cornerRadius: VPNRadius.small)
            .stroke(Color.vpnDisconnected.opacity(0.3), lineWidth: 1)
    )
    .transition(.opacity.combined(with: .move(edge: .top)))
}

private var dividerRow: some View {
    HStack {
        Rectangle()
            .fill(Color.vpnBorder)
            .frame(height: 1)
        Text("or")
            .vpnTextStyle(.caption, color: .vpnTextTertiary)
        Rectangle()
            .fill(Color.vpnBorder)
            .frame(height: 1)
    }
}

private var appleSignInButton: some View {
    SignInWithAppleButton(.signIn) { request in
        request.requestedScopes = [.email]
    } onCompletion: { _ in
        // Apple Sign In handling — requires backend support
    }
    .signInWithAppleButtonStyle(.white)
    .frame(height: 52)
    .cornerRadius(VPNRadius.button)
}

// MARK: - Shake Animation Modifier

struct ShakeModifier: GeometryEffect {
    var shakes: CGFloat
    var animatableData: CGFloat {
        get { shakes }
        set { shakes = newValue }
    }

    func effectValue(size: CGSize) -> ProjectionTransform {
        ProjectionTransform(
            CGAffineTransform(translationX: 8 * sin(shakes * .pi * 2), y: 0)
        )
    }
}

#Preview {
    AuthView()
        .environment(AuthService.shared)
}
