import Link from "next/link";
import { ShieldIcon } from "./Icons";

export default function Footer() {
  return (
    <footer className="footer">
      <div className="container">
        <div className="footer__inner">
          <div className="footer__brand">
            <Link href="/" className="nav__logo">
              <ShieldIcon className="nav__logo-icon" />
              <span>VPN Dan</span>
            </Link>
            <p className="footer__tagline">One tap. Total privacy.</p>
          </div>
          <div className="footer__links">
            <Link href="/privacy">Privacy Policy</Link>
            <Link href="/terms">Terms of Use</Link>
            <a href="mailto:support@vpndan.com">Contact</a>
          </div>
        </div>
        <div className="footer__bottom">
          <p>&copy; {new Date().getFullYear()} VPN Dan. All rights reserved.</p>
        </div>
      </div>
    </footer>
  );
}
