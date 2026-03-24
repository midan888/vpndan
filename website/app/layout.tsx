import type { Metadata } from "next";
import Nav from "@/components/Nav";
import Footer from "@/components/Footer";
import "./globals.css";

export const metadata: Metadata = {
  title: {
    default: "VPN Dan — One Tap. Total Privacy.",
    template: "%s — VPN Dan",
  },
  description:
    "WireGuard-powered VPN for iOS. Military-grade encryption, lightning-fast speeds, global servers. One tap to go invisible.",
  openGraph: {
    siteName: "VPN Dan",
    type: "website",
  },
  twitter: {
    card: "summary_large_image",
  },
};

export default function RootLayout({
  children,
}: {
  children: React.ReactNode;
}) {
  return (
    <html lang="en">
      <body>
        <Nav />
        {children}
        <Footer />
      </body>
    </html>
  );
}
