"use client";

import { useState } from "react";
import Link from "next/link";
import { usePathname } from "next/navigation";
import { ShieldIcon } from "./Icons";

const APP_STORE_URL = process.env.NEXT_PUBLIC_APP_STORE_URL || "#";

export default function Nav() {
  const [open, setOpen] = useState(false);
  const pathname = usePathname();

  return (
    <nav className="nav">
      <div className="container nav__inner">
        <Link href="/" className="nav__logo">
          <ShieldIcon className="nav__logo-icon" />
          <span>VPN Dan</span>
        </Link>
        <div className={`nav__links${open ? " nav__links--open" : ""}`}>
          <Link href="/#features" className="nav__link" onClick={() => setOpen(false)}>
            Features
          </Link>
          <Link
            href="/privacy"
            className={`nav__link${pathname === "/privacy" ? " nav__link--active" : ""}`}
            onClick={() => setOpen(false)}
          >
            Privacy
          </Link>
          <Link
            href="/terms"
            className={`nav__link${pathname === "/terms" ? " nav__link--active" : ""}`}
            onClick={() => setOpen(false)}
          >
            Terms
          </Link>
          <a href={APP_STORE_URL} className="btn btn--sm">
            Download
          </a>
        </div>
        <button
          className="nav__toggle"
          aria-label="Toggle menu"
          onClick={() => setOpen(!open)}
        >
          <span /><span /><span />
        </button>
      </div>
    </nav>
  );
}
