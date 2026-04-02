import {
  AppleIcon,
  ShieldFeatureIcon,
  SpeedIcon,
  GlobeIcon,
  PhoneShieldIcon,
} from "@/components/Icons";

const APP_STORE_URL = process.env.NEXT_PUBLIC_APP_STORE_URL || "#";

export default function Home() {
  return (
    <>
      {/* Hero */}
      <section className="hero">
        <div className="hero__bg" />
        <div className="container hero__inner">
          <div className="hero__content">
            <h1 className="hero__title">
              One tap.
              <br />
              <span className="gradient-text">Total privacy.</span>
            </h1>
            <p className="hero__subtitle">
              WireGuard-powered VPN for iOS. Modern encryption, blazing
              speeds, and servers worldwide. Go invisible in one tap.
            </p>
            <div className="hero__actions">
              <a href={APP_STORE_URL} className="btn btn--lg">
                <AppleIcon className="btn__icon" />
                Download for iOS
              </a>
            </div>
          </div>
          <div className="hero__visual">
            <div className="phone-frame">
              <div className="phone-screen">
                <div className="phone-status">Protected</div>
                <div className="phone-shield">
                  <PhoneShieldIcon />
                </div>
                <div className="phone-label">You&apos;re invisible.</div>
              </div>
            </div>
          </div>
        </div>
      </section>

      {/* Features */}
      <section className="features" id="features">
        <div className="container">
          <h2 className="section-title">Why VPN Dan?</h2>
          <div className="features__grid">
            <div className="feature-card">
              <div className="feature-card__icon">
                <ShieldFeatureIcon />
              </div>
              <h3 className="feature-card__title">Modern Encryption</h3>
              <p className="feature-card__text">
                Built on WireGuard — the most modern, audited VPN protocol. Your
                data is locked down with state-of-the-art cryptography.
              </p>
            </div>
            <div className="feature-card">
              <div className="feature-card__icon">
                <SpeedIcon />
              </div>
              <h3 className="feature-card__title">Lightning Fast</h3>
              <p className="feature-card__text">
                WireGuard runs circles around legacy VPN protocols. Stream, game,
                and browse without the slowdown you&apos;ve come to expect.
              </p>
            </div>
            <div className="feature-card">
              <div className="feature-card__icon">
                <GlobeIcon />
              </div>
              <h3 className="feature-card__title">Global Network</h3>
              <p className="feature-card__text">
                Connect to servers worldwide. Access content from anywhere,
                bypass restrictions, and always find a fast, nearby server.
              </p>
            </div>
          </div>
        </div>
      </section>

      {/* How it works */}
      <section className="how-it-works">
        <div className="container">
          <h2 className="section-title">How It Works</h2>
          <div className="steps">
            <div className="step">
              <div className="step__number">1</div>
              <h3 className="step__title">Download</h3>
              <p className="step__text">
                Get VPN Dan from the App Store. No account setup, no lengthy
                forms.
              </p>
            </div>
            <div className="step__connector" />
            <div className="step">
              <div className="step__number">2</div>
              <h3 className="step__title">Pick a Server</h3>
              <p className="step__text">
                Choose from servers around the globe. Or let us pick the fastest
                one for you.
              </p>
            </div>
            <div className="step__connector" />
            <div className="step">
              <div className="step__number">3</div>
              <h3 className="step__title">Go Invisible</h3>
              <p className="step__text">
                One tap and you&apos;re protected. Your traffic is encrypted and
                your identity is hidden.
              </p>
            </div>
          </div>
        </div>
      </section>

      {/* CTA */}
      <section className="cta">
        <div className="container cta__inner">
          <h2 className="cta__title">
            Ready to go <span className="gradient-text">invisible</span>?
          </h2>
          <p className="cta__subtitle">
            Download VPN Dan and take control of your privacy today.
          </p>
          <a href={APP_STORE_URL} className="btn btn--lg">
            <AppleIcon className="btn__icon" />
            Download for iOS
          </a>
        </div>
      </section>
    </>
  );
}
