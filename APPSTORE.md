# VPN Dan - App Store Submission Guide

## App Store Connect Metadata

### App Information

| Field | Value |
|-------|-------|
| **App Name** | VPN Dan |
| **Subtitle** | Fast & Secure VPN Protection |
| **Bundle ID** | com.vpndan.VPNDan |
| **SKU** | com.vpndan.vpndan.ios |
| **Primary Language** | English (US) |
| **Category** | Utilities |
| **Secondary Category** | Productivity |
| **Content Rights** | Does not contain third-party content |
| **Age Rating** | 4+ (no objectionable content) |

---

### Version Information

| Field | Value |
|-------|-------|
| **Version** | 1.0.0 |
| **Copyright** | 2026 VPN Dan |
| **Build** | Auto-generated from git commit count |

---

### App Description (4000 char max)

```
VPN Dan protects your internet connection with one tap. Built on the WireGuard protocol, it delivers fast, private, and secure browsing without complexity.

SIMPLE & FAST
Connect in one tap. No settings to configure, no protocols to choose. Just tap the power button and you're protected. WireGuard ensures your connection is faster than legacy VPN protocols.

REAL PRIVACY
Your browsing activity is never logged. VPN Dan uses modern encryption built into the WireGuard protocol to keep your data private from ISPs, hackers, and anyone watching your network.

GLOBAL SERVER NETWORK
Browse servers across Americas, Europe, Asia, and Oceania. See real-time latency for every server so you always pick the fastest option. Save your favorites for quick access.

SPLIT TUNNELING
Choose which apps and websites bypass the VPN. Keep banking apps on your direct connection while everything else stays encrypted. Exclude specific domains or IP ranges with precision.

PASSWORDLESS LOGIN
No passwords to remember. Sign in with your email and a verification code. Simple, secure authentication.

KEY FEATURES
- One-tap VPN connection
- WireGuard protocol for speed and security
- Global server locations with real-time latency
- Split tunneling (Bypass VPN) for apps and domains
- No activity logging
- Passwordless email authentication
- Server favorites and search
- Region filtering (Americas, Europe, Asia, Oceania)
- Live connection stats (speed, duration, IP)
- Built-in Help Center

VPN Dan is designed to be the VPN you actually want to use. No bloat, no upsells, no confusion. Just protection.
```

**Character count:** ~1,250 (well within 4,000 limit)

---

### Promotional Text (170 char max, can be updated without new build)

```
Protect your connection in one tap. Fast WireGuard VPN with global servers, split tunneling, and zero activity logging.
```

---

### Keywords (100 char max, comma-separated)

```
vpn,wireguard,privacy,secure,fast,proxy,encrypt,protect,tunnel,network,split,server,anonymous,ip
```

**Character count:** 94

---

### What's New (Version 1.0.0)

```
Welcome to VPN Dan! This is our first release.

- One-tap VPN connection powered by WireGuard
- Global server network with real-time latency
- Split tunneling for apps and domains
- Passwordless email authentication
- Server favorites and region filtering
- Live connection statistics
- Built-in Help Center
```

---

### Support & Links

| Field | Value |
|-------|-------|
| **Support URL** | https://vpndan.com/support |
| **Marketing URL** | https://vpndan.com |
| **Privacy Policy URL** | https://vpndan.com/privacy |
| **Terms of Service URL** | https://vpndan.com/terms |
| **Support Email** | support@vpndan.com |

---

## Screenshots

### Required Sizes

| Device | Size (pixels) | Required |
|--------|--------------|----------|
| iPhone 6.9" (16 Pro Max) | 1320 x 2868 | Yes (mandatory) |
| iPhone 6.7" (15 Plus/Pro Max) | 1290 x 2796 | Yes (mandatory) |
| iPhone 6.5" (11 Pro Max) | 1242 x 2688 | Optional |
| iPhone 5.5" (8 Plus) | 1242 x 2208 | Optional |

**Minimum:** 3 screenshots per size, **Maximum:** 10
**Recommended:** 5-6 screenshots

### Screenshot Plan (5 screens)

**Screenshot 1 - Hero / Home Screen (Connected State)**
- Show the home screen with power button glowing green/teal
- Status: "You're invisible."
- Server card showing a connected server with flag and latency
- Connection stats visible (download/upload speed, duration)
- **Caption:** "One Tap. Total Privacy."

**Screenshot 2 - Server Selection**
- Full servers view with region filter tabs visible
- Multiple servers listed with country flags, latency badges
- A "Favorites" section at the top with 2-3 starred servers
- **Caption:** "Global Servers. Real-Time Latency."

**Screenshot 3 - Connection Details**
- Home screen showing connection details expanded
- IP address, download/upload speeds, connection duration
- Status badge showing "Protected"
- **Caption:** "Live Stats. Full Transparency."

**Screenshot 4 - Split Tunneling**
- Bypass VPN settings screen
- Show country bypass and domain/IP exclusions
- Some example entries (banking app, local network)
- **Caption:** "Split Tunneling. You Decide What's Protected."

**Screenshot 5 - Passwordless Auth**
- Login screen with email input and verification code
- Clean, dark UI with gradient accents
- **Caption:** "No Passwords. Just Your Email."

### Design Guidelines for Screenshots

- **Background:** Use the app's dark navy (#0A0E1A) or a subtle gradient
- **Device frame:** Optional but recommended (use iPhone 15 Pro frame)
- **Text overlay:** Place caption text above or below the device, using SF Pro Bold, white text
- **Accent colors:** Match the app's violet (#7B5EFF) to teal (#00D4AA) gradient
- **Consistency:** Same text style, same framing, same background across all screenshots
- **Format:** PNG or JPEG, sRGB color space

### Tools for Creating Screenshots

- **Figma** - Design from scratch with templates
- **Screenshots Pro** (macOS app) - Quick device frames + text
- **AppMockUp** (appmockup.io) - Free web-based screenshot builder
- **RocketSim** - Capture directly from simulator with frames

---

## App Preview Video (Optional but Recommended)

| Spec | Value |
|------|-------|
| **Duration** | 15-30 seconds |
| **Format** | H.264, .mp4 or .mov |
| **Resolution** | Match screenshot device sizes |
| **Audio** | Optional (plays muted by default) |

### Suggested Video Flow (20 seconds)

1. **(0-3s)** App opens, onboarding welcome screen: "Total Privacy. One Tap."
2. **(3-7s)** Auth screen - email entered, code verified, logged in
3. **(7-12s)** Home screen - tap power button, VPN connects, status changes to "You're invisible."
4. **(12-17s)** Swipe to servers tab, browse servers, tap a favorite
5. **(17-20s)** Back to home, connected with stats visible. End card: "VPN Dan"

---

## App Review Notes

Paste this in the "Notes for Review" field in App Store Connect:

```
VPN Dan is a WireGuard-based VPN app that requires a backend server for functionality.

HOW TO TEST:
1. Launch the app
2. Enter any valid email address to receive a 6-digit verification code
3. Enter the code to sign in
4. Browse the server list and tap a server to select it
5. Tap the power button on the home screen to connect
6. iOS will prompt for VPN permission on first connection - tap "Allow"
7. The VPN tunnel will establish and status will change to "Protected"
8. Tap the power button again to disconnect

DEMO ACCOUNT (if needed):
Email: review@vpndan.com
(A verification code will be sent to this email)

ADDITIONAL NOTES:
- The app requires the Network Extension (packet-tunnel-provider) entitlement to create VPN tunnels
- The app uses the Personal VPN entitlement
- No third-party analytics or tracking SDKs are used
- The app does not collect or log user browsing activity
- Split tunneling (Bypass VPN) allows users to exclude specific domains/IPs from the VPN tunnel
- The PacketTunnel network extension (com.vpndan.VPNDan.PacketTunnel) handles the actual VPN tunnel
```

---

## Privacy Details (App Privacy on App Store)

### Data Collection Disclosure

Apple requires you to declare what data your app collects. Fill out the App Privacy section in App Store Connect:

#### Data Types Collected

| Data Type | Collected | Purpose | Linked to Identity |
|-----------|-----------|---------|-------------------|
| **Email Address** | Yes | App Functionality (authentication) | Yes |
| **Device ID** | No | - | - |
| **Location** | No | - | - |
| **Browsing History** | No | - | - |
| **Search History** | No | - | - |
| **Usage Data** | No | - | - |
| **Diagnostics** | No | - | - |
| **Purchases** | No | - | - |
| **Financial Info** | No | - | - |
| **Contacts** | No | - | - |
| **Photos or Videos** | No | - | - |

#### Summary for App Store Privacy Label

- **Data Used to Track You:** None
- **Data Linked to You:** Email Address (for authentication only)
- **Data Not Linked to You:** None collected
- **Data Not Collected:** Everything else

---

## Required Legal Pages

You need these pages live on your website before submission:

### Privacy Policy (vpndan.com/privacy) - Must Cover:

- What data is collected (email for account creation)
- What data is NOT collected (browsing history, DNS queries, traffic logs)
- How authentication data is stored (JWT tokens, Keychain)
- WireGuard connection metadata (IP assignment, no traffic logging)
- Data retention and deletion (account deletion via support@vpndan.com)
- Third-party data sharing (none)
- Children's privacy (COPPA compliance)
- Contact information for privacy inquiries

### Terms of Service (vpndan.com/terms) - Must Cover:

- Acceptable use policy (no illegal activity via VPN)
- Account terms (one active connection per account)
- Service availability (no uptime guarantee for free tier)
- Termination conditions
- Limitation of liability
- Governing law
- Contact information

---

## App Store Connect Checklist

### Before You Start

- [ ] **Apple Developer Account** - Active membership ($99/year)
- [ ] **App ID registered** in Apple Developer Portal (com.vpndan.VPNDan)
- [ ] **Network Extension entitlement** approved by Apple (requires manual approval request)
- [ ] **Personal VPN entitlement** enabled
- [ ] **App Group** configured (group.com.vpndan.VPNDan)
- [ ] **Provisioning profiles** created for both targets (VPNDan + PacketTunnel)
- [ ] **Distribution certificate** valid and not expired

### Content & Legal

- [ ] **Privacy Policy** page live at vpndan.com/privacy
- [ ] **Terms of Service** page live at vpndan.com/terms
- [ ] **Support page** live at vpndan.com/support (or support email working)
- [ ] **App description** finalized (see above)
- [ ] **Keywords** finalized (see above)
- [ ] **What's New** text written (see above)
- [ ] **Promotional text** written (see above)

### Visual Assets

- [ ] **App Icon** - 1024x1024 PNG, no alpha, no rounded corners (Apple rounds them)
- [ ] **Screenshots** - Minimum 3 per required device size (6.9" and 6.7")
- [ ] **App Preview video** (optional but recommended)

### Build & Technical

- [ ] **Archive build** created in Xcode (Product > Archive)
- [ ] **Validate** archive passes all checks (no signing issues, no missing entitlements)
- [ ] **Upload** to App Store Connect via Xcode Organizer or Transporter
- [ ] **Build processing** complete (wait for email from Apple, usually 5-30 min)
- [ ] **Export compliance** - Mark as "No" for encryption exemption (WireGuard uses standard encryption, but you ARE using encryption so answer accordingly - see note below)

### Export Compliance (Encryption)

Since VPN Dan uses encryption (WireGuard/ChaCha20), you must:

1. Answer "Yes" to "Does your app use encryption?"
2. Answer "Yes" to "Does your app qualify for any exemptions?"
3. Select: "Your app uses encryption that is exempt because it uses only standard encryption algorithms and protocols"
4. WireGuard uses standard IETF protocols - this qualifies for the exemption
5. Alternatively, submit a self-classification report (CCATS not required for exempt encryption)

### App Store Connect Setup

- [ ] **Create new app** in App Store Connect
- [ ] **Fill in App Information** tab (name, subtitle, category, privacy policy URL)
- [ ] **Fill in Pricing and Availability** (Free, all territories or specific ones)
- [ ] **Fill in App Privacy** section (see privacy details above)
- [ ] **Select build** for the version
- [ ] **Add screenshots** for all required device sizes
- [ ] **Fill in version information** (description, keywords, support URL, etc.)
- [ ] **Add review notes** (see App Review Notes above)
- [ ] **Set release method** - Manual or Automatic after approval

### Testing (Before Submission)

- [ ] **TestFlight internal testing** - Upload build, test with team (min 24-48 hours)
- [ ] **Test on real devices** - iPhone SE, iPhone 15, iPhone 16 Pro Max (various sizes)
- [ ] **Test full user journey:** onboarding > auth > connect > browse servers > disconnect > sign out
- [ ] **Test VPN connection** actually works (traffic routed through server)
- [ ] **Test split tunneling** - excluded domains bypass VPN
- [ ] **Test token refresh** - leave app idle, return, verify auto-refresh works
- [ ] **Test error states** - no network, invalid code, server unavailable
- [ ] **Test kill/restart** - kill app while connected, reopen, verify VPN status
- [ ] **Test orientation** - app should work in portrait (landscape if supported)
- [ ] **Test accessibility** - VoiceOver basic navigation works
- [ ] **Verify Help Center** content loads correctly
- [ ] **Verify Privacy Policy / Terms links** open correctly

### Submission

- [ ] **Submit for review** in App Store Connect
- [ ] **Monitor status** - Waiting for Review > In Review > Approved/Rejected
- [ ] **Respond to rejection** quickly if needed (common VPN rejection reasons below)

---

## Common VPN App Rejection Reasons & How to Avoid

### 1. Missing VPN Entitlement
**Problem:** App uses NetworkExtension without proper entitlement.
**Fix:** Request the Network Extension entitlement from Apple Developer portal. Fill out the request form explaining your VPN service. Allow 1-3 business days for approval.

### 2. Guideline 5.4 - VPN Apps
**Problem:** Apple requires VPN apps to use NEVPNManager or NETunnelProviderManager.
**Fix:** VPN Dan already uses NETunnelProviderManager - this is correct. Make sure the review notes explain the architecture.

### 3. Guideline 5.1.1 - Data Collection and Storage
**Problem:** Privacy policy doesn't match actual data collection.
**Fix:** Ensure privacy policy accurately states: only email collected, no browsing logs, no tracking.

### 4. Guideline 2.1 - App Completeness
**Problem:** Backend servers are down during review.
**Fix:** Ensure your backend is deployed and stable before submitting. Monitor uptime during review period (typically 24-48 hours).

### 5. Guideline 4.0 - Design (Login Required)
**Problem:** Reviewer can't test without an account.
**Fix:** Provide a demo account in the review notes, or ensure the email verification works for any email the reviewer might use.

### 6. Guideline 2.3.1 - Hidden Features
**Problem:** Split tunneling or other features not discoverable.
**Fix:** Ensure all features are accessible through normal UI navigation. No hidden gestures or undocumented features.

---

## Post-Launch Checklist

- [ ] **Monitor App Store Connect** for crash reports
- [ ] **Monitor backend** for increased traffic
- [ ] **Respond to user reviews** within 24 hours
- [ ] **Track key metrics:** downloads, retention, crash-free rate
- [ ] **Plan v1.1:** address any review feedback or user reports
- [ ] **Consider:** App Store Optimization (ASO) based on search ranking data

---

## Quick Reference: App Store Connect Fields

```
App Name:           VPN Dan
Subtitle:           Fast & Secure VPN Protection
Bundle ID:          com.vpndan.VPNDan
SKU:                com.vpndan.vpndan.ios
Version:            1.0.0
Category:           Utilities
Secondary:          Productivity
Price:              Free
Availability:       All territories (or specific)
Rating:             4+
Copyright:          2026 VPN Dan
Support URL:        https://vpndan.com/support
Marketing URL:      https://vpndan.com
Privacy Policy:     https://vpndan.com/privacy
```
