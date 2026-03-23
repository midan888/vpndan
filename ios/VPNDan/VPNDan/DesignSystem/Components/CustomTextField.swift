import SwiftUI

struct VPNTextField: View {
    let placeholder: String
    @Binding var text: String
    var isSecure: Bool = false
    var textContentType: UITextContentType?
    var keyboardType: UIKeyboardType = .default
    var autocapitalization: TextInputAutocapitalization = .never

    @FocusState private var isFocused: Bool

    var body: some View {
        Group {
            if isSecure {
                SecureField("", text: $text, prompt: promptText)
                    .textContentType(textContentType)
            } else {
                TextField("", text: $text, prompt: promptText)
                    .textContentType(textContentType)
                    .keyboardType(keyboardType)
                    .textInputAutocapitalization(autocapitalization)
            }
        }
        .focused($isFocused)
        .autocorrectionDisabled()
        .font(.system(size: 15))
        .foregroundStyle(Color.vpnTextPrimary)
        .tint(.vpnPrimary)
        .padding(.horizontal, VPNSpacing.md)
        .frame(height: 52)
        .background(
            RoundedRectangle(cornerRadius: VPNRadius.textField)
                .fill(Color.vpnSurface)
        )
        .overlay(
            RoundedRectangle(cornerRadius: VPNRadius.textField)
                .stroke(
                    isFocused ? Color.vpnPrimary : Color.vpnBorder,
                    lineWidth: isFocused ? 1.5 : 1
                )
        )
        .animation(.easeInOut(duration: 0.2), value: isFocused)
    }

    private var promptText: Text {
        Text(placeholder)
            .foregroundStyle(Color.vpnTextTertiary)
    }
}

#Preview {
    ZStack {
        Color.vpnBackground.ignoresSafeArea()

        VStack(spacing: VPNSpacing.md) {
            VPNTextField(
                placeholder: "Email",
                text: .constant(""),
                textContentType: .emailAddress,
                keyboardType: .emailAddress
            )
            VPNTextField(
                placeholder: "Password",
                text: .constant(""),
                isSecure: true,
                textContentType: .password
            )
            VPNTextField(
                placeholder: "With text",
                text: .constant("user@example.com"),
                textContentType: .emailAddress
            )
        }
        .padding(VPNSpacing.xl)
    }
}
