import Foundation

// MARK: - Localization Helper

/// Centralized localization strings for the app.
/// All user-facing strings should be defined here for easy translation.
enum L10n {

    // MARK: - Common
    enum Common {
        static let done = String(localized: "common.done", defaultValue: "Done")
        static let cancel = String(localized: "common.cancel", defaultValue: "Cancel")
        static let ok = String(localized: "common.ok", defaultValue: "OK")
        static let or = String(localized: "common.or", defaultValue: "or")
        static let on = String(localized: "common.on", defaultValue: "On")
        static let off = String(localized: "common.off", defaultValue: "Off")
        static let add = String(localized: "common.add", defaultValue: "Add")
        static let tryAgain = String(localized: "common.tryAgain", defaultValue: "Try Again")
        static let comingSoon = String(localized: "common.comingSoon", defaultValue: "Coming soon")
        static let notAvailable = String(localized: "common.notAvailable", defaultValue: "Not available")
    }

    // MARK: - Tabs
    enum Tabs {
        static let home = String(localized: "tabs.home", defaultValue: "Home")
        static let servers = String(localized: "tabs.servers", defaultValue: "Servers")
        static let settings = String(localized: "tabs.settings", defaultValue: "Settings")
    }

    // MARK: - Auth
    enum Auth {
        static let appName = String(localized: "auth.appName", defaultValue: "VPN DAN")
        static let email = String(localized: "auth.email", defaultValue: "Email")
        static let enterEmail = String(localized: "auth.enterEmail", defaultValue: "Enter your email to sign in or create an account")
        static let continueButton = String(localized: "auth.continue", defaultValue: "Continue")
        static let checkEmail = String(localized: "auth.checkEmail", defaultValue: "We sent a 6-digit code to")
        static let codePlaceholder = String(localized: "auth.codePlaceholder", defaultValue: "000000")
        static let verifyCode = String(localized: "auth.verifyCode", defaultValue: "Verify")
        static let resendCode = String(localized: "auth.resendCode", defaultValue: "Resend code")
        static let changeEmail = String(localized: "auth.changeEmail", defaultValue: "Change email")
    }

    // MARK: - Home
    enum Home {
        static let statusConnected = String(localized: "home.statusConnected", defaultValue: "You're invisible.")
        static let statusConnecting = String(localized: "home.statusConnecting", defaultValue: "Going dark...")
        static let statusDisconnected = String(localized: "home.statusDisconnected", defaultValue: "You're exposed.")
        static let statusDisconnecting = String(localized: "home.statusDisconnecting", defaultValue: "Reconnecting...")
        static let connectionError = String(localized: "home.connectionError", defaultValue: "Connection Error")
        static let connectionFailed = String(localized: "home.connectionFailed", defaultValue: "Connection failed. Please try again.")
        static let unableToLoadServers = String(localized: "home.unableToLoadServers", defaultValue: "Unable to load servers.\nCheck your connection.")
    }

    // MARK: - VPN Status
    enum VPNStatus {
        static let protected = String(localized: "vpnStatus.protected", defaultValue: "Protected")
        static let connecting = String(localized: "vpnStatus.connecting", defaultValue: "Connecting")
        static let notProtected = String(localized: "vpnStatus.notProtected", defaultValue: "Not Protected")
        static let disconnecting = String(localized: "vpnStatus.disconnecting", defaultValue: "Disconnecting")
        static func accessibilityLabel(_ status: String) -> String {
            "VPN status: \(status)"
        }
    }

    // MARK: - Server Card
    enum ServerCard {
        static let noServerSelected = String(localized: "serverCard.noServerSelected", defaultValue: "No Server Selected")
        static let tapToChoose = String(localized: "serverCard.tapToChoose", defaultValue: "Tap to choose a server")
        static let change = String(localized: "serverCard.change", defaultValue: "Change")
    }

    // MARK: - Connection Details
    enum ConnectionDetails {
        static let title = String(localized: "connectionDetails.title", defaultValue: "Connection details")
        static let connectionQuality = String(localized: "connectionDetails.connectionQuality", defaultValue: "Connection Quality")
        static let download = String(localized: "connectionDetails.download", defaultValue: "Download")
        static let upload = String(localized: "connectionDetails.upload", defaultValue: "Upload")
        static let duration = String(localized: "connectionDetails.duration", defaultValue: "Duration")
        static let yourIP = String(localized: "connectionDetails.yourIP", defaultValue: "Your IP")
        static let notConnected = String(localized: "connectionDetails.notConnected", defaultValue: "Not connected")
    }

    // MARK: - Server Row
    enum ServerRow {
        static let connected = String(localized: "serverRow.connected", defaultValue: "Connected")
    }

    // MARK: - Latency
    enum Latency {
        static let excellent = String(localized: "latency.excellent", defaultValue: "Excellent")
        static let good = String(localized: "latency.good", defaultValue: "Good")
        static let fair = String(localized: "latency.fair", defaultValue: "Fair")
        static let poor = String(localized: "latency.poor", defaultValue: "Poor")
    }

    // MARK: - Servers
    enum Servers {
        static let searchPlaceholder = String(localized: "servers.searchPlaceholder", defaultValue: "Search servers...")
        static let noServersFound = String(localized: "servers.noServersFound", defaultValue: "No servers found")
        static let tryDifferentSearch = String(localized: "servers.tryDifferentSearch", defaultValue: "Try a different search or region filter")
        static let favorites = String(localized: "servers.favorites", defaultValue: "Favorites")
        static let allServers = String(localized: "servers.allServers", defaultValue: "All Servers")
        static let results = String(localized: "servers.results", defaultValue: "Results")
        static let selectServer = String(localized: "servers.selectServer", defaultValue: "Select Server")
        static func serverCount(_ count: Int) -> String {
            "\(count) servers"
        }
        static func sortLabel(_ option: String) -> String {
            "Sort: \(option)"
        }

        // Region filters
        static let regionAll = String(localized: "servers.region.all", defaultValue: "All")
        static let regionAmericas = String(localized: "servers.region.americas", defaultValue: "Americas")
        static let regionEurope = String(localized: "servers.region.europe", defaultValue: "Europe")
        static let regionAsia = String(localized: "servers.region.asia", defaultValue: "Asia")
        static let regionOceania = String(localized: "servers.region.oceania", defaultValue: "Oceania")

        // Sort options
        static let sortName = String(localized: "servers.sort.name", defaultValue: "Name")
        static let sortStatus = String(localized: "servers.sort.status", defaultValue: "Status")
        static let sortLatency = String(localized: "servers.sort.latency", defaultValue: "Latency")
    }

    // MARK: - Settings
    enum Settings {
        // Sections
        static let account = String(localized: "settings.account", defaultValue: "Account")
        static let connection = String(localized: "settings.connection", defaultValue: "Connection")
        static let appearance = String(localized: "settings.appearance", defaultValue: "Appearance")
        static let support = String(localized: "settings.support", defaultValue: "Support")

        // Account
        static let plan = String(localized: "settings.plan", defaultValue: "Plan")
        static let planFree = String(localized: "settings.planFree", defaultValue: "Free")

        // Connection
        static let autoConnect = String(localized: "settings.autoConnect", defaultValue: "Auto-Connect")
        static let autoConnectSubtitle = String(localized: "settings.autoConnectSubtitle", defaultValue: "Connect on app launch")
        static let killSwitch = String(localized: "settings.killSwitch", defaultValue: "Kill Switch")
        static let killSwitchSubtitle = String(localized: "settings.killSwitchSubtitle", defaultValue: "Block traffic if VPN drops")
        static let bypassVPN = String(localized: "settings.bypassVPN", defaultValue: "Bypass VPN")

        // Appearance
        static let theme = String(localized: "settings.theme", defaultValue: "Theme")

        // Support
        static let helpCenter = String(localized: "settings.helpCenter", defaultValue: "Help Center")
        static let privacyPolicy = String(localized: "settings.privacyPolicy", defaultValue: "Privacy Policy")
        static let termsOfService = String(localized: "settings.termsOfService", defaultValue: "Terms of Service")

        // Sign Out
        static let signOut = String(localized: "settings.signOut", defaultValue: "Sign Out")
        static let signOutConfirmConnected = String(localized: "settings.signOutConfirmConnected", defaultValue: "You are currently connected. Signing out will disconnect you.")
        static let signOutConfirm = String(localized: "settings.signOutConfirm", defaultValue: "Are you sure you want to sign out?")

        // Delete Account
        static let deleteAccount = String(localized: "settings.deleteAccount", defaultValue: "Delete Account")
        static let deleteAccountConfirm = String(localized: "settings.deleteAccountConfirm", defaultValue: "This will permanently delete your account and all associated data. This action cannot be undone.")
        static let deleteAccountConfirmConnected = String(localized: "settings.deleteAccountConfirmConnected", defaultValue: "You are currently connected. Deleting your account will disconnect you and permanently remove all your data.")
        static let deleteAccountButton = String(localized: "settings.deleteAccountButton", defaultValue: "Delete Permanently")

        static func appVersion(_ version: String) -> String {
            "VPN Dan v\(version)"
        }
    }

    // MARK: - Onboarding
    enum Onboarding {
        static let skip = String(localized: "onboarding.skip", defaultValue: "Skip")
        static let next = String(localized: "onboarding.next", defaultValue: "Next")
        static let getStarted = String(localized: "onboarding.getStarted", defaultValue: "Get Started")

        // Page 1 — Welcome
        static let welcomeTitle = String(localized: "onboarding.welcomeTitle", defaultValue: "Total Privacy.\nOne Tap.")
        static let welcomeSubtitle = String(localized: "onboarding.welcomeSubtitle", defaultValue: "VPN Dan encrypts your connection\nand hides your identity from everyone.")

        // Page 2 — Permission
        static let permissionTitle = String(localized: "onboarding.permissionTitle", defaultValue: "VPN Permission")
        static let permissionSubtitle = String(localized: "onboarding.permissionSubtitle", defaultValue: "VPN Dan needs permission to create a secure tunnel. Your data never leaves your device unencrypted.")
        static let featureEncryption = String(localized: "onboarding.featureEncryption", defaultValue: "Modern encryption")
        static let featureNoLogs = String(localized: "onboarding.featureNoLogs", defaultValue: "No activity logging")
        static let featureProtocol = String(localized: "onboarding.featureProtocol", defaultValue: "WireGuard protocol")

        // Page 3 — Personalization
        static let priorityTitle = String(localized: "onboarding.priorityTitle", defaultValue: "What's Your\nPriority?")
        static let prioritySubtitle = String(localized: "onboarding.prioritySubtitle", defaultValue: "We'll optimize your experience accordingly.")

        static let priorityPrivacy = String(localized: "onboarding.priorityPrivacy", defaultValue: "Privacy")
        static let priorityPrivacySub = String(localized: "onboarding.priorityPrivacySub", defaultValue: "Hide my identity")
        static let priorityAccess = String(localized: "onboarding.priorityAccess", defaultValue: "Access")
        static let priorityAccessSub = String(localized: "onboarding.priorityAccessSub", defaultValue: "Unlock content worldwide")
        static let prioritySpeed = String(localized: "onboarding.prioritySpeed", defaultValue: "Speed")
        static let prioritySpeedSub = String(localized: "onboarding.prioritySpeedSub", defaultValue: "Fastest connection possible")
    }

    // MARK: - Help Center
    enum HelpCenter {
        static let title = String(localized: "helpCenter.title", defaultValue: "Help Center")
        static let searchPlaceholder = String(localized: "helpCenter.searchPlaceholder", defaultValue: "Search help articles...")
        static let noResults = String(localized: "helpCenter.noResults", defaultValue: "No results found")
        static let noResultsHint = String(localized: "helpCenter.noResultsHint", defaultValue: "Try a different search term or browse the categories below.")
        static let stillNeedHelp = String(localized: "helpCenter.stillNeedHelp", defaultValue: "Still need help?")
        static let contactPrompt = String(localized: "helpCenter.contactPrompt", defaultValue: "Reach out to us and we'll get back to you as soon as possible.")
        static let contactSupport = String(localized: "helpCenter.contactSupport", defaultValue: "Contact Support")

        // Categories
        static let catGettingStarted = String(localized: "helpCenter.catGettingStarted", defaultValue: "Getting Started")
        static let catConnection = String(localized: "helpCenter.catConnection", defaultValue: "Connection")
        static let catPrivacy = String(localized: "helpCenter.catPrivacy", defaultValue: "Privacy & Security")
        static let catAccount = String(localized: "helpCenter.catAccount", defaultValue: "Account")

        // Getting Started
        static let helpConnectQ = String(localized: "helpCenter.helpConnectQ", defaultValue: "How do I connect to a VPN server?")
        static let helpConnectA = String(localized: "helpCenter.helpConnectA", defaultValue: "Tap the power button on the home screen to connect to the selected server. You can change servers by tapping \"Change\" on the server card or visiting the Servers tab.")
        static let helpChooseServerQ = String(localized: "helpCenter.helpChooseServerQ", defaultValue: "Which server should I choose?")
        static let helpChooseServerA = String(localized: "helpCenter.helpChooseServerA", defaultValue: "For the best speed, choose a server close to your physical location — look for the lowest latency (ms) value. For accessing content from a specific region, pick a server in that country.")
        static let helpAccountQ = String(localized: "helpCenter.helpAccountQ", defaultValue: "Do I need to create an account?")
        static let helpAccountA = String(localized: "helpCenter.helpAccountA", defaultValue: "Yes, an account is required to use VPN Dan. Your account lets us manage your VPN connection securely without storing any browsing activity.")

        // Connection
        static let helpSlowQ = String(localized: "helpCenter.helpSlowQ", defaultValue: "Why is my connection slow?")
        static let helpSlowA = String(localized: "helpCenter.helpSlowA", defaultValue: "Try switching to a server closer to your location for lower latency. Server load can also affect speed — if a server shows high latency, try another one in the same region.")
        static let helpLatencyQ = String(localized: "helpCenter.helpLatencyQ", defaultValue: "What does the latency number mean?")
        static let helpLatencyA = String(localized: "helpCenter.helpLatencyA", defaultValue: "Latency (measured in milliseconds) is the time it takes for data to travel between your device and the server. Lower is better — under 50ms is excellent, 50–100ms is good, and over 100ms may feel slower.")
        static let helpBypassQ = String(localized: "helpCenter.helpBypassQ", defaultValue: "What is Bypass VPN (Split Tunneling)?")
        static let helpBypassA = String(localized: "helpCenter.helpBypassA", defaultValue: "Bypass VPN lets certain apps, websites, or IP addresses skip the VPN tunnel and connect directly. This is useful for services that block VPN traffic, like banking apps, or for local network access.")
        static let helpDisconnectQ = String(localized: "helpCenter.helpDisconnectQ", defaultValue: "The VPN keeps disconnecting. What should I do?")
        static let helpDisconnectA = String(localized: "helpCenter.helpDisconnectA", defaultValue: "Make sure you have a stable internet connection. Try switching to a different server. If the issue persists, sign out and sign back in to refresh your session.")

        // Privacy
        static let helpLogsQ = String(localized: "helpCenter.helpLogsQ", defaultValue: "Does VPN Dan log my activity?")
        static let helpLogsA = String(localized: "helpCenter.helpLogsA", defaultValue: "No. VPN Dan does not log your browsing activity, DNS queries, or traffic data. We only store the minimum information needed to maintain your account and connection.")
        static let helpProtocolQ = String(localized: "helpCenter.helpProtocolQ", defaultValue: "What VPN protocol does VPN Dan use?")
        static let helpProtocolA = String(localized: "helpCenter.helpProtocolA", defaultValue: "VPN Dan uses WireGuard, a modern VPN protocol known for its speed, simplicity, and strong cryptography. It's faster and more secure than older protocols like OpenVPN or IPSec.")
        static let helpEncryptedQ = String(localized: "helpCenter.helpEncryptedQ", defaultValue: "Is my data encrypted?")
        static let helpEncryptedA = String(localized: "helpCenter.helpEncryptedA", defaultValue: "Yes. All traffic between your device and the VPN server is encrypted using state-of-the-art cryptography provided by the WireGuard protocol, including ChaCha20 for encryption and Curve25519 for key exchange.")

        // Account
        static let helpPasswordQ = String(localized: "helpCenter.helpPasswordQ", defaultValue: "How do I sign in?")
        static let helpPasswordA = String(localized: "helpCenter.helpPasswordA", defaultValue: "Enter your email address and we'll send you a 6-digit verification code. No password needed — just check your inbox and enter the code.")
        static let helpMultiDeviceQ = String(localized: "helpCenter.helpMultiDeviceQ", defaultValue: "Can I use my account on multiple devices?")
        static let helpMultiDeviceA = String(localized: "helpCenter.helpMultiDeviceA", defaultValue: "Currently, VPN Dan supports one active connection per account. Connecting from a new device will disconnect the previous one.")
        static let helpDeleteQ = String(localized: "helpCenter.helpDeleteQ", defaultValue: "How do I delete my account?")
        static let helpDeleteA = String(localized: "helpCenter.helpDeleteA", defaultValue: "Go to Settings and tap \"Delete Account\" at the bottom of the page. This will permanently remove your account and all associated data.")
    }

    // MARK: - Split Tunnel
    enum SplitTunnel {
        static let title = String(localized: "splitTunnel.title", defaultValue: "Bypass VPN")
        static let subtitle = String(localized: "splitTunnel.subtitle", defaultValue: "Let certain apps and sites skip the VPN")
        static let presets = String(localized: "splitTunnel.presets", defaultValue: "Presets")
        static let bypassByCountry = String(localized: "splitTunnel.bypassByCountry", defaultValue: "Bypass by Country")
        static let noCountries = String(localized: "splitTunnel.noCountries", defaultValue: "No countries selected")
        static let addCountry = String(localized: "splitTunnel.addCountry", defaultValue: "Add Country")
        static let selectCountries = String(localized: "splitTunnel.selectCountries", defaultValue: "Select Countries")
        static let searchCountries = String(localized: "splitTunnel.searchCountries", defaultValue: "Search countries")
        static let excludedDomainsIPs = String(localized: "splitTunnel.excludedDomainsIPs", defaultValue: "Excluded Domains & IPs")
        static let noExclusions = String(localized: "splitTunnel.noExclusions", defaultValue: "No exclusions added")
        static let addDomainOrIP = String(localized: "splitTunnel.addDomainOrIP", defaultValue: "Add Domain or IP")
        static let excludeTitle = String(localized: "splitTunnel.excludeTitle", defaultValue: "Exclude Domain or IP")
        static let excludePlaceholder = String(localized: "splitTunnel.excludePlaceholder", defaultValue: "e.g. google.com or 192.168.1.0/24")
        static let excludeHint = String(localized: "splitTunnel.excludeHint", defaultValue: "Enter a domain name (e.g. google.com) or IP range in CIDR notation (e.g. 10.0.0.0/8).")
        static let infoText = String(localized: "splitTunnel.infoText", defaultValue: "Bypassed sites and addresses will use your regular internet connection instead of the VPN.")
        static let changesOnReconnect = String(localized: "splitTunnel.changesOnReconnect", defaultValue: "Changes will take effect on next connection.")
        static let domain = String(localized: "splitTunnel.domain", defaultValue: "Domain")
        static let ipRange = String(localized: "splitTunnel.ipRange", defaultValue: "IP Range")
        static func ipRangesCount(_ count: Int) -> String {
            "\(count) IP ranges"
        }

        // Presets
        static let localNetwork = String(localized: "splitTunnel.localNetwork", defaultValue: "Local Network")
        static let localNetworkSub = String(localized: "splitTunnel.localNetworkSub", defaultValue: "Bypass VPN for local network traffic")
        static let lanServices = String(localized: "splitTunnel.lanServices", defaultValue: "LAN Services")
        static let lanServicesSub = String(localized: "splitTunnel.lanServicesSub", defaultValue: "Access printers, AirPlay, Chromecast")
    }

    // MARK: - API Errors
    enum Errors {
        static let invalidURL = String(localized: "errors.invalidURL", defaultValue: "Invalid URL")
        static let unauthorized = String(localized: "errors.unauthorized", defaultValue: "Authentication failed. Please try again.")
        static let serverUnavailable = String(localized: "errors.serverUnavailable", defaultValue: "Server unavailable. Please select another.")
        static let serverAtCapacity = String(localized: "errors.serverAtCapacity", defaultValue: "Server is at capacity. Try another server.")
        static let serverError = String(localized: "errors.serverError", defaultValue: "Something went wrong. Please try again.")
        static let networkError = String(localized: "errors.networkError", defaultValue: "Unable to connect. Check your internet connection.")
        static let decodingError = String(localized: "errors.decodingError", defaultValue: "Unexpected response from server.")
        static let sessionExpired = String(localized: "errors.sessionExpired", defaultValue: "Session expired. Please log in again.")
        static let vpnPermissionRequired = String(localized: "errors.vpnPermissionRequired", defaultValue: "VPN permission is required to connect. You can enable it in Settings > General > VPN & Device Management.")
        static let vpnConnectionFailed = String(localized: "errors.vpnConnectionFailed", defaultValue: "Connection failed. Please try again.")
    }
}
