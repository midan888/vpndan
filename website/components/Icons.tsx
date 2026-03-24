export function ShieldIcon({ className }: { className?: string }) {
  return (
    <svg className={className} viewBox="0 0 32 32" fill="none" width={32} height={32}>
      <path
        d="M16 2L4 8v8c0 7.73 5.12 14.96 12 16 6.88-1.04 12-8.27 12-16V8L16 2z"
        fill="url(#sg)" opacity="0.15"
      />
      <path
        d="M16 2L4 8v8c0 7.73 5.12 14.96 12 16 6.88-1.04 12-8.27 12-16V8L16 2z"
        stroke="url(#sg)" strokeWidth="1.5" fill="none"
      />
      <path
        d="M16 9v8M16 17l4-4M16 17l-4-4"
        stroke="url(#sg)" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round"
      />
      <defs>
        <linearGradient id="sg" x1="4" y1="2" x2="28" y2="26" gradientUnits="userSpaceOnUse">
          <stop stopColor="#7B5EFF" />
          <stop offset="1" stopColor="#00D4AA" />
        </linearGradient>
      </defs>
    </svg>
  );
}

export function AppleIcon({ className }: { className?: string }) {
  return (
    <svg className={className} viewBox="0 0 24 24" fill="currentColor" width={20} height={20}>
      <path d="M18.71 19.5c-.83 1.24-1.71 2.45-3.05 2.47-1.34.03-1.77-.79-3.29-.79-1.53 0-2 .77-3.27.82-1.31.05-2.3-1.32-3.14-2.53C4.25 17 2.94 12.45 4.7 9.39c.87-1.52 2.43-2.48 4.12-2.51 1.28-.02 2.5.87 3.29.87.78 0 2.26-1.07 3.8-.91.65.03 2.47.26 3.64 1.98-.09.06-2.17 1.28-2.15 3.81.03 3.02 2.65 4.03 2.68 4.04-.03.07-.42 1.44-1.38 2.83M13 3.5c.73-.83 1.94-1.46 2.94-1.5.13 1.17-.34 2.35-1.04 3.19-.69.85-1.83 1.51-2.95 1.42-.15-1.15.41-2.35 1.05-3.11z" />
    </svg>
  );
}

export function ShieldFeatureIcon() {
  return (
    <svg viewBox="0 0 48 48" fill="none" width={48} height={48}>
      <path d="M24 4L8 12v8c0 11.6 6.84 22.44 16 24 9.16-1.56 16-12.4 16-24v-8L24 4z" stroke="url(#f1)" strokeWidth="2" />
      <path d="M18 24l4 4 8-8" stroke="#00D4AA" strokeWidth="2.5" strokeLinecap="round" strokeLinejoin="round" />
      <defs>
        <linearGradient id="f1" x1="8" y1="4" x2="40" y2="36">
          <stop stopColor="#7B5EFF" /><stop offset="1" stopColor="#00D4AA" />
        </linearGradient>
      </defs>
    </svg>
  );
}

export function SpeedIcon() {
  return (
    <svg viewBox="0 0 48 48" fill="none" width={48} height={48}>
      <path d="M8 24h32" stroke="url(#f2)" strokeWidth="2" strokeLinecap="round" />
      <path d="M28 16l8 8-8 8" stroke="url(#f2)" strokeWidth="2.5" strokeLinecap="round" strokeLinejoin="round" />
      <circle cx="14" cy="24" r="3" stroke="#00D4AA" strokeWidth="2" />
      <defs>
        <linearGradient id="f2" x1="8" y1="16" x2="40" y2="32">
          <stop stopColor="#7B5EFF" /><stop offset="1" stopColor="#00D4AA" />
        </linearGradient>
      </defs>
    </svg>
  );
}

export function GlobeIcon() {
  return (
    <svg viewBox="0 0 48 48" fill="none" width={48} height={48}>
      <circle cx="24" cy="24" r="16" stroke="url(#f3)" strokeWidth="2" />
      <ellipse cx="24" cy="24" rx="8" ry="16" stroke="url(#f3)" strokeWidth="1.5" />
      <path d="M8 24h32M24 8v32" stroke="url(#f3)" strokeWidth="1.5" opacity="0.5" />
      <defs>
        <linearGradient id="f3" x1="8" y1="8" x2="40" y2="40">
          <stop stopColor="#7B5EFF" /><stop offset="1" stopColor="#00D4AA" />
        </linearGradient>
      </defs>
    </svg>
  );
}

export function PhoneShieldIcon() {
  return (
    <svg viewBox="0 0 80 80" fill="none" width={80} height={80}>
      <path
        d="M40 8L12 20v16c0 15.46 10.24 29.92 24 32 13.76-2.08 24-16.54 24-32V20L40 8z"
        fill="url(#ps)" opacity="0.2"
      />
      <path
        d="M40 8L12 20v16c0 15.46 10.24 29.92 24 32 13.76-2.08 24-16.54 24-32V20L40 8z"
        stroke="url(#ps)" strokeWidth="2" fill="none"
      />
      <path d="M32 40l5 5 11-11" stroke="#00D4AA" strokeWidth="3" strokeLinecap="round" strokeLinejoin="round" />
      <defs>
        <linearGradient id="ps" x1="12" y1="8" x2="64" y2="56" gradientUnits="userSpaceOnUse">
          <stop stopColor="#7B5EFF" /><stop offset="1" stopColor="#00D4AA" />
        </linearGradient>
      </defs>
    </svg>
  );
}
