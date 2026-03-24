import type { Metadata } from "next";

export const metadata: Metadata = {
  title: "Privacy Policy",
  description:
    "VPN Dan privacy policy. Learn how we protect your data and respect your privacy.",
};

export default function Privacy() {
  return (
    <section className="legal">
      <div className="container legal__inner">
        <h1 className="legal__title">Privacy Policy</h1>
        <p className="legal__updated">Last updated: March 24, 2026</p>

        <div className="legal__body">
          <h2>1. Introduction</h2>
          <p>
            VPN Dan (&quot;we&quot;, &quot;our&quot;, or &quot;us&quot;) is
            committed to protecting your privacy. This Privacy Policy explains
            how we collect, use, and safeguard your information when you use our
            VPN service and mobile application.
          </p>

          <h2>2. Information We Collect</h2>

          <h3>2.1 Account Information</h3>
          <p>When you create an account, we collect:</p>
          <ul>
            <li>
              <strong>Email address</strong> — used for account identification,
              authentication, and essential service communications.
            </li>
          </ul>

          <h3>2.2 Information We Do NOT Collect</h3>
          <p>
            We are a strict no-logs VPN. We do <strong>not</strong> collect,
            store, or monitor:
          </p>
          <ul>
            <li>Your browsing history or traffic data</li>
            <li>DNS queries</li>
            <li>IP addresses assigned to you</li>
            <li>Connection timestamps or session duration</li>
            <li>Your original IP address</li>
            <li>Bandwidth usage per session</li>
          </ul>

          <h3>2.3 Technical Data</h3>
          <p>
            We may collect minimal, non-identifying technical data to maintain
            service quality:
          </p>
          <ul>
            <li>
              Aggregate server load metrics (not linked to individual users)
            </li>
            <li>App crash reports (via Apple&apos;s standard crash reporting)</li>
          </ul>

          <h2>3. How We Use Your Information</h2>
          <p>We use the information we collect to:</p>
          <ul>
            <li>Provide and maintain the VPN service</li>
            <li>Authenticate your account</li>
            <li>
              Send essential service communications (e.g., security alerts)
            </li>
            <li>Improve our service and fix bugs</li>
          </ul>

          <h2>4. Data Security</h2>
          <p>
            We implement industry-standard security measures to protect your
            data:
          </p>
          <ul>
            <li>
              <strong>Encryption in transit</strong> — All VPN traffic is
              encrypted using WireGuard&apos;s modern cryptographic protocols
              (ChaCha20, Poly1305, Curve25519, BLAKE2s).
            </li>
            <li>
              <strong>Encrypted storage</strong> — Account credentials are
              stored using bcrypt hashing. Tokens are stored securely on your
              device&apos;s Keychain.
            </li>
            <li>
              <strong>Infrastructure security</strong> — Our servers run
              hardened Linux with minimal attack surface.
            </li>
          </ul>

          <h2>5. Data Sharing</h2>
          <p>
            We do <strong>not</strong> sell, trade, or otherwise transfer your
            personal information to third parties. We may disclose information
            only if required by law, and even then, we can only share what we
            have — which, due to our no-logs policy, is limited to your email
            address.
          </p>

          <h2>6. Data Retention</h2>
          <p>
            We retain your account information (email) for as long as your
            account is active. VPN connection data is never stored and therefore
            cannot be retained. When you delete your account, all associated
            data is permanently removed from our systems.
          </p>

          <h2>7. Your Rights</h2>
          <p>You have the right to:</p>
          <ul>
            <li>
              <strong>Access</strong> your personal data
            </li>
            <li>
              <strong>Delete</strong> your account and all associated data
            </li>
            <li>
              <strong>Export</strong> your account information
            </li>
            <li>
              <strong>Opt out</strong> of non-essential communications
            </li>
          </ul>

          <h2>8. Children&apos;s Privacy</h2>
          <p>
            VPN Dan is not intended for use by individuals under the age of 18.
            We do not knowingly collect personal information from children. If
            you believe we have collected data from a minor, please contact us
            immediately.
          </p>

          <h2>9. Changes to This Policy</h2>
          <p>
            We may update this Privacy Policy from time to time. We will notify
            you of any material changes by posting the new policy on this page
            and updating the &quot;Last updated&quot; date. Your continued use of
            the service after changes constitutes acceptance of the updated
            policy.
          </p>

          <h2>10. Contact Us</h2>
          <p>
            If you have questions about this Privacy Policy, contact us at:
          </p>
          <p>
            <a href="mailto:privacy@vpndan.com">privacy@vpndan.com</a>
          </p>
        </div>
      </div>
    </section>
  );
}
