import SwiftUI

// MARK: - Data Model

struct LegalSection: Identifiable {
    let id = UUID()
    let title: String
    let subsections: [LegalSubsection]?
    let paragraphs: [LegalParagraph]

    init(title: String, paragraphs: [LegalParagraph], subsections: [LegalSubsection]? = nil) {
        self.title = title
        self.paragraphs = paragraphs
        self.subsections = subsections
    }
}

struct LegalSubsection: Identifiable {
    let id = UUID()
    let title: String
    let paragraphs: [LegalParagraph]
}

struct LegalParagraph: Identifiable {
    let id = UUID()
    let text: String
    let bullets: [LegalBullet]?

    init(_ text: String, bullets: [LegalBullet]? = nil) {
        self.text = text
        self.bullets = bullets
    }
}

struct LegalBullet: Identifiable {
    let id = UUID()
    let text: String
    let bold: String?

    init(_ text: String, bold: String? = nil) {
        self.text = text
        self.bold = bold
    }
}

struct LegalDocument {
    let title: String
    let lastUpdated: String
    let sections: [LegalSection]
    let contactEmail: String
}

// MARK: - Legal Document View

struct LegalDocumentView: View {
    @Environment(\.dismiss) private var dismiss
    let document: LegalDocument

    var body: some View {
        NavigationStack {
            ZStack {
                Color.vpnBackground.ignoresSafeArea()

                ScrollView {
                    VStack(alignment: .leading, spacing: 0) {
                        // Last updated
                        Text("Last updated: \(document.lastUpdated)")
                            .vpnTextStyle(.caption, color: .vpnTextTertiary)
                            .padding(.bottom, VPNSpacing.xl)

                        // Sections
                        ForEach(document.sections) { section in
                            sectionView(section)
                        }
                    }
                    .padding(.horizontal, VPNSpacing.md)
                    .padding(.top, VPNSpacing.md)
                    .padding(.bottom, VPNSpacing.xxl)
                }
                .scrollIndicators(.hidden)
            }
            .navigationTitle(document.title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(L10n.Common.done) { dismiss() }
                        .foregroundStyle(Color.vpnPrimary)
                }
            }
        }
    }

    // MARK: - Section

    @ViewBuilder
    private func sectionView(_ section: LegalSection) -> some View {
        Text(section.title)
            .font(.system(size: 18, weight: .bold))
            .foregroundStyle(Color.vpnTextPrimary)
            .padding(.top, VPNSpacing.lg)
            .padding(.bottom, VPNSpacing.sm)

        ForEach(section.paragraphs) { paragraph in
            paragraphView(paragraph)
        }

        if let subsections = section.subsections {
            ForEach(subsections) { sub in
                Text(sub.title)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(Color.vpnTextPrimary)
                    .padding(.top, VPNSpacing.md)
                    .padding(.bottom, VPNSpacing.xs)

                ForEach(sub.paragraphs) { paragraph in
                    paragraphView(paragraph)
                }
            }
        }
    }

    // MARK: - Paragraph

    @ViewBuilder
    private func paragraphView(_ paragraph: LegalParagraph) -> some View {
        Text(paragraph.text)
            .font(.system(size: 15, weight: .regular))
            .foregroundStyle(Color.vpnTextSecondary)
            .lineSpacing(6)
            .padding(.bottom, VPNSpacing.sm)

        if let bullets = paragraph.bullets {
            VStack(alignment: .leading, spacing: VPNSpacing.sm) {
                ForEach(bullets) { bullet in
                    HStack(alignment: .top, spacing: VPNSpacing.sm) {
                        Text("•")
                            .foregroundStyle(Color.vpnTextTertiary)

                        if let bold = bullet.bold {
                            Text("\(Text(bold).font(.system(size: 15, weight: .semibold)).foregroundColor(.vpnTextPrimary)) — \(bullet.text)")
                                .font(.system(size: 15, weight: .regular))
                                .foregroundStyle(Color.vpnTextSecondary)
                                .lineSpacing(5)
                        } else {
                            Text(bullet.text)
                                .font(.system(size: 15, weight: .regular))
                                .foregroundStyle(Color.vpnTextSecondary)
                                .lineSpacing(5)
                        }
                    }
                }
            }
            .padding(.leading, VPNSpacing.md)
            .padding(.bottom, VPNSpacing.sm)
        }
    }
}

// MARK: - Terms of Use Content

extension LegalDocument {
    static let termsOfUse = LegalDocument(
        title: "Terms of Use",
        lastUpdated: "April 1, 2026",
        sections: [
            LegalSection(
                title: "1. Acceptance of Terms",
                paragraphs: [
                    LegalParagraph("By downloading, installing, or using VPN Dan (\"the Service\"), you agree to be bound by these Terms of Use. If you do not agree to these terms, do not use the Service.")
                ]
            ),
            LegalSection(
                title: "2. Description of Service",
                paragraphs: [
                    LegalParagraph("VPN Dan provides a virtual private network (VPN) service that encrypts your internet traffic and routes it through secure servers using the WireGuard protocol. The Service is available as a mobile application for iOS devices.")
                ]
            ),
            LegalSection(
                title: "3. Eligibility",
                paragraphs: [
                    LegalParagraph("You must be at least 18 years old to use the Service. By using VPN Dan, you represent and warrant that you meet this age requirement.")
                ]
            ),
            LegalSection(
                title: "4. Account Registration",
                paragraphs: [
                    LegalParagraph("To use the Service, you must create an account with a valid email address. Authentication is handled via one-time verification codes sent to your email. You are responsible for:", bullets: [
                        LegalBullet("Maintaining access to the email address associated with your account"),
                        LegalBullet("All activities that occur under your account"),
                        LegalBullet("Notifying us immediately of any unauthorized use of your account"),
                    ])
                ]
            ),
            LegalSection(
                title: "5. Acceptable Use",
                paragraphs: [
                    LegalParagraph("You agree not to use the Service to:", bullets: [
                        LegalBullet("Violate any applicable local, state, national, or international law"),
                        LegalBullet("Transmit any material that is unlawful, harmful, threatening, abusive, harassing, defamatory, or otherwise objectionable"),
                        LegalBullet("Distribute malware, viruses, or other harmful software"),
                        LegalBullet("Engage in any activity that interferes with or disrupts the Service"),
                        LegalBullet("Attempt to gain unauthorized access to our systems"),
                        LegalBullet("Use the Service for any form of illegal file sharing or distribution"),
                        LegalBullet("Send spam or unsolicited communications"),
                        LegalBullet("Engage in any activity that could damage, disable, or impair the Service"),
                    ])
                ]
            ),
            LegalSection(
                title: "6. Intellectual Property",
                paragraphs: [
                    LegalParagraph("The Service, including its design, code, graphics, and content, is owned by VPN Dan and protected by intellectual property laws. You may not copy, modify, distribute, or reverse engineer any part of the Service without our express written permission.")
                ]
            ),
            LegalSection(
                title: "7. Privacy",
                paragraphs: [
                    LegalParagraph("Your use of the Service is also governed by our Privacy Policy, which is incorporated into these Terms by reference.")
                ]
            ),
            LegalSection(
                title: "8. Service Availability",
                paragraphs: [
                    LegalParagraph("We strive to maintain high availability but do not guarantee uninterrupted access to the Service. We may temporarily suspend the Service for maintenance, updates, or other operational reasons. We are not liable for any loss or damage arising from service interruptions.")
                ]
            ),
            LegalSection(
                title: "9. Limitation of Liability",
                paragraphs: [
                    LegalParagraph("To the maximum extent permitted by law, VPN Dan shall not be liable for any indirect, incidental, special, consequential, or punitive damages, including but not limited to loss of profits, data, or other intangible losses, resulting from:", bullets: [
                        LegalBullet("Your use or inability to use the Service"),
                        LegalBullet("Any unauthorized access to or alteration of your data"),
                        LegalBullet("Any third-party conduct on the Service"),
                        LegalBullet("Any other matter relating to the Service"),
                    ])
                ]
            ),
            LegalSection(
                title: "10. Disclaimer of Warranties",
                paragraphs: [
                    LegalParagraph("The Service is provided \"as is\" and \"as available\" without warranties of any kind, either express or implied. We do not warrant that the Service will be error-free, secure, or available at all times.")
                ]
            ),
            LegalSection(
                title: "11. Termination",
                paragraphs: [
                    LegalParagraph("We reserve the right to suspend or terminate your account at any time if you violate these Terms. You may delete your account at any time from the Settings screen within the app. Upon deletion, all your data is permanently removed and your right to use the Service ceases immediately.")
                ]
            ),
            LegalSection(
                title: "12. Changes to Terms",
                paragraphs: [
                    LegalParagraph("We may modify these Terms at any time. We will notify you of material changes by posting the updated Terms on our website and updating the \"Last updated\" date. Continued use of the Service after changes constitutes acceptance of the modified Terms.")
                ]
            ),
            LegalSection(
                title: "13. Governing Law",
                paragraphs: [
                    LegalParagraph("These Terms shall be governed by and construed in accordance with applicable laws, without regard to conflict of law principles.")
                ]
            ),
            LegalSection(
                title: "14. Contact",
                paragraphs: [
                    LegalParagraph("For questions about these Terms, contact us at legal@vpndan.com.")
                ]
            ),
        ],
        contactEmail: "legal@vpndan.com"
    )

    // MARK: - Privacy Policy Content

    static let privacyPolicy = LegalDocument(
        title: "Privacy Policy",
        lastUpdated: "April 1, 2026",
        sections: [
            LegalSection(
                title: "1. Introduction",
                paragraphs: [
                    LegalParagraph("VPN Dan (\"we\", \"our\", or \"us\") is committed to protecting your privacy. This Privacy Policy explains how we collect, use, and safeguard your information when you use our VPN service and mobile application.")
                ]
            ),
            LegalSection(
                title: "2. Information We Collect",
                paragraphs: [],
                subsections: [
                    LegalSubsection(
                        title: "2.1 Account Information",
                        paragraphs: [
                            LegalParagraph("When you create an account, we collect:", bullets: [
                                LegalBullet("used for account identification, authentication, and essential service communications.", bold: "Email address"),
                            ])
                        ]
                    ),
                    LegalSubsection(
                        title: "2.2 Information We Do NOT Collect",
                        paragraphs: [
                            LegalParagraph("We are a strict no-logs VPN. We do not collect, store, or monitor:", bullets: [
                                LegalBullet("Your browsing history or traffic data"),
                                LegalBullet("DNS queries"),
                                LegalBullet("IP addresses assigned to you"),
                                LegalBullet("Connection timestamps or session duration"),
                                LegalBullet("Your original IP address"),
                                LegalBullet("Bandwidth usage per session"),
                            ])
                        ]
                    ),
                    LegalSubsection(
                        title: "2.3 Technical Data",
                        paragraphs: [
                            LegalParagraph("We may collect minimal, non-identifying technical data to maintain service quality:", bullets: [
                                LegalBullet("Aggregate server load metrics (not linked to individual users)"),
                                LegalBullet("App crash reports (via Apple's standard crash reporting)"),
                            ])
                        ]
                    ),
                ]
            ),
            LegalSection(
                title: "3. How We Use Your Information",
                paragraphs: [
                    LegalParagraph("We use the information we collect to:", bullets: [
                        LegalBullet("Provide and maintain the VPN service"),
                        LegalBullet("Authenticate your account"),
                        LegalBullet("Send essential service communications (e.g., security alerts)"),
                        LegalBullet("Improve our service and fix bugs"),
                    ])
                ]
            ),
            LegalSection(
                title: "4. Data Security",
                paragraphs: [
                    LegalParagraph("We implement industry-standard security measures to protect your data:", bullets: [
                        LegalBullet("All VPN traffic is encrypted using WireGuard's modern cryptographic protocols (ChaCha20, Poly1305, Curve25519, BLAKE2s).", bold: "Encryption in transit"),
                        LegalBullet("Account credentials are stored using bcrypt hashing. Tokens are stored securely on your device's Keychain.", bold: "Encrypted storage"),
                        LegalBullet("Our servers run hardened Linux with minimal attack surface.", bold: "Infrastructure security"),
                    ])
                ]
            ),
            LegalSection(
                title: "5. Data Sharing",
                paragraphs: [
                    LegalParagraph("We do not sell, trade, or otherwise transfer your personal information to third parties. We may disclose information only if required by law, and even then, we can only share what we have — which, due to our no-logs policy, is limited to your email address.")
                ]
            ),
            LegalSection(
                title: "6. Data Retention",
                paragraphs: [
                    LegalParagraph("We retain your account information (email) for as long as your account is active. VPN connection data is never stored and therefore cannot be retained. You can delete your account at any time from the Settings screen in the app. When you delete your account, all associated data — including your email, VPN peer records, and any active connections — is permanently removed from our systems. A confirmation email is sent to notify you of the deletion.")
                ]
            ),
            LegalSection(
                title: "7. Your Rights",
                paragraphs: [
                    LegalParagraph("You have the right to:", bullets: [
                        LegalBullet("your personal data", bold: "Access"),
                        LegalBullet("your account and all associated data directly from the app's Settings screen", bold: "Delete"),
                        LegalBullet("your account information", bold: "Export"),
                        LegalBullet("of non-essential communications", bold: "Opt out"),
                    ])
                ]
            ),
            LegalSection(
                title: "8. Children's Privacy",
                paragraphs: [
                    LegalParagraph("VPN Dan is not intended for use by individuals under the age of 18. We do not knowingly collect personal information from children. If you believe we have collected data from a minor, please contact us immediately.")
                ]
            ),
            LegalSection(
                title: "9. Changes to This Policy",
                paragraphs: [
                    LegalParagraph("We may update this Privacy Policy from time to time. We will notify you of any material changes by posting the new policy on this page and updating the \"Last updated\" date. Your continued use of the service after changes constitutes acceptance of the updated policy.")
                ]
            ),
            LegalSection(
                title: "10. Contact Us",
                paragraphs: [
                    LegalParagraph("If you have questions about this Privacy Policy, contact us at privacy@vpndan.com.")
                ]
            ),
        ],
        contactEmail: "privacy@vpndan.com"
    )
}

// MARK: - Previews

#Preview("Terms of Use") {
    LegalDocumentView(document: .termsOfUse)
}

#Preview("Privacy Policy") {
    LegalDocumentView(document: .privacyPolicy)
}
