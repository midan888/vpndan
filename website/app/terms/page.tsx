import type { Metadata } from "next";

export const metadata: Metadata = {
  title: "Terms of Use",
  description:
    "VPN Dan terms of use. Read our terms and conditions for using the VPN Dan service.",
};

export default function Terms() {
  return (
    <section className="legal">
      <div className="container legal__inner">
        <h1 className="legal__title">Terms of Use</h1>
        <p className="legal__updated">Last updated: March 24, 2026</p>

        <div className="legal__body">
          <h2>1. Acceptance of Terms</h2>
          <p>
            By downloading, installing, or using VPN Dan (&quot;the
            Service&quot;), you agree to be bound by these Terms of Use. If you
            do not agree to these terms, do not use the Service.
          </p>

          <h2>2. Description of Service</h2>
          <p>
            VPN Dan provides a virtual private network (VPN) service that
            encrypts your internet traffic and routes it through secure servers
            using the WireGuard protocol. The Service is available as a mobile
            application for iOS devices.
          </p>

          <h2>3. Eligibility</h2>
          <p>
            You must be at least 18 years old to use the Service. By using VPN
            Dan, you represent and warrant that you meet this age requirement.
          </p>

          <h2>4. Account Registration</h2>
          <p>
            To use the Service, you must create an account with a valid email
            address and password. You are responsible for:
          </p>
          <ul>
            <li>Maintaining the confidentiality of your account credentials</li>
            <li>All activities that occur under your account</li>
            <li>
              Notifying us immediately of any unauthorized use of your account
            </li>
          </ul>

          <h2>5. Acceptable Use</h2>
          <p>You agree not to use the Service to:</p>
          <ul>
            <li>
              Violate any applicable local, state, national, or international
              law
            </li>
            <li>
              Transmit any material that is unlawful, harmful, threatening,
              abusive, harassing, defamatory, or otherwise objectionable
            </li>
            <li>Distribute malware, viruses, or other harmful software</li>
            <li>
              Engage in any activity that interferes with or disrupts the
              Service
            </li>
            <li>Attempt to gain unauthorized access to our systems</li>
            <li>
              Use the Service for any form of illegal file sharing or
              distribution
            </li>
            <li>Send spam or unsolicited communications</li>
            <li>
              Engage in any activity that could damage, disable, or impair the
              Service
            </li>
          </ul>

          <h2>6. Intellectual Property</h2>
          <p>
            The Service, including its design, code, graphics, and content, is
            owned by VPN Dan and protected by intellectual property laws. You may
            not copy, modify, distribute, or reverse engineer any part of the
            Service without our express written permission.
          </p>

          <h2>7. Privacy</h2>
          <p>
            Your use of the Service is also governed by our{" "}
            <a href="/privacy">Privacy Policy</a>, which is incorporated into
            these Terms by reference.
          </p>

          <h2>8. Service Availability</h2>
          <p>
            We strive to maintain high availability but do not guarantee
            uninterrupted access to the Service. We may temporarily suspend the
            Service for maintenance, updates, or other operational reasons. We
            are not liable for any loss or damage arising from service
            interruptions.
          </p>

          <h2>9. Limitation of Liability</h2>
          <p>
            To the maximum extent permitted by law, VPN Dan shall not be liable
            for any indirect, incidental, special, consequential, or punitive
            damages, including but not limited to loss of profits, data, or
            other intangible losses, resulting from:
          </p>
          <ul>
            <li>Your use or inability to use the Service</li>
            <li>Any unauthorized access to or alteration of your data</li>
            <li>Any third-party conduct on the Service</li>
            <li>Any other matter relating to the Service</li>
          </ul>

          <h2>10. Disclaimer of Warranties</h2>
          <p>
            The Service is provided &quot;as is&quot; and &quot;as
            available&quot; without warranties of any kind, either express or
            implied. We do not warrant that the Service will be error-free,
            secure, or available at all times.
          </p>

          <h2>11. Termination</h2>
          <p>
            We reserve the right to suspend or terminate your account at any
            time if you violate these Terms. You may also terminate your account
            at any time by contacting us. Upon termination, your right to use
            the Service ceases immediately.
          </p>

          <h2>12. Changes to Terms</h2>
          <p>
            We may modify these Terms at any time. We will notify you of
            material changes by posting the updated Terms on our website and
            updating the &quot;Last updated&quot; date. Continued use of the
            Service after changes constitutes acceptance of the modified Terms.
          </p>

          <h2>13. Governing Law</h2>
          <p>
            These Terms shall be governed by and construed in accordance with
            applicable laws, without regard to conflict of law principles.
          </p>

          <h2>14. Contact</h2>
          <p>
            For questions about these Terms, contact us at:
          </p>
          <p>
            <a href="mailto:legal@vpndan.com">legal@vpndan.com</a>
          </p>
        </div>
      </div>
    </section>
  );
}
