"use client";

import {
  LogOut,
  Menu,
  Search,
  ShieldCheck,
  X,
} from "lucide-react";
import Image from "next/image";
import Link from "next/link";
import { usePathname, useRouter } from "next/navigation";
import {
  useEffect,
  useMemo,
  useRef,
  useState,
  type ReactNode,
} from "react";
import { toast } from "sonner";

import { useBodyScrollLock } from "@/hooks/use-body-scroll-lock";
import { createBrowserClient } from "@/lib/supabase/client";
import { cn } from "@/lib/utils";

import {
  allNavigationItems,
  navigationItemForPath,
  navigationGroups,
  titleForPath,
} from "./navigation";
import { ThemeToggle } from "./theme-toggle";

type AdminShellProps = {
  children: ReactNode;
  admin: {
    fullName: string;
    email: string;
  };
};

function initials(name: string) {
  const words = name.trim().split(/\s+/).filter(Boolean);
  if (!words.length) return "A";
  return `${words[0][0]}${words.length > 1 ? words.at(-1)?.[0] : ""}`.toUpperCase();
}

export function AdminShell({ children, admin }: AdminShellProps) {
  const pathname = usePathname();
  const currentNavigationItem = navigationItemForPath(pathname);
  const CurrentPageIcon = currentNavigationItem?.icon;
  const router = useRouter();
  const searchRef = useRef<HTMLInputElement>(null);
  const [sidebarOpen, setSidebarOpen] = useState(false);
  const [query, setQuery] = useState("");
  const [searchFocused, setSearchFocused] = useState(false);

  useBodyScrollLock(sidebarOpen);

  useEffect(() => {
    function handleShortcut(event: KeyboardEvent) {
      if ((event.metaKey || event.ctrlKey) && event.key.toLowerCase() === "k") {
        event.preventDefault();
        searchRef.current?.focus();
      }
    }
    window.addEventListener("keydown", handleShortcut);
    return () => window.removeEventListener("keydown", handleShortcut);
  }, []);

  const searchResults = useMemo(() => {
    const normalized = query.trim().toLowerCase();
    if (!normalized) return [];
    return allNavigationItems
      .filter(
        (item) =>
          item.label.toLowerCase().includes(normalized) ||
          item.description.toLowerCase().includes(normalized),
      )
      .slice(0, 6);
  }, [query]);

  async function signOut() {
    try {
      const supabase = createBrowserClient();
      await supabase.auth.signOut();
      router.replace("/login");
      router.refresh();
    } catch {
      toast.error("Could not sign out. Please try again.");
    }
  }

  function openResult(href: string) {
    setQuery("");
    setSearchFocused(false);
    router.push(href);
  }

  return (
    <div className="admin-shell">
      <button
        className={cn("sidebar-backdrop", sidebarOpen && "sidebar-backdrop-open")}
        type="button"
        aria-label="Close navigation"
        onClick={() => setSidebarOpen(false)}
      />

      <aside
        className={cn("admin-sidebar", sidebarOpen && "admin-sidebar-open")}
        aria-label="Primary navigation"
      >
        <div className="sidebar-header">
          <Image
            className="sidebar-logo"
            src="/logo.png"
            width={44}
            height={44}
            priority
            alt="BU Horizon emblem"
          />
          <div className="sidebar-brand">
            <strong>BU Horizon</strong>
            <span>Admin console</span>
          </div>
          <button
            className="sidebar-close"
            type="button"
            aria-label="Close navigation"
            onClick={() => setSidebarOpen(false)}
          >
            <X aria-hidden="true" />
          </button>
        </div>

        <nav className="sidebar-nav">
          {navigationGroups.map((group) => (
            <div className="nav-group" key={group.label}>
              <p className="nav-group-label">{group.label}</p>
              <ul className="nav-list">
                {group.items.map((item) => {
                  const active =
                    item.href === "/"
                      ? pathname === "/"
                      : pathname.startsWith(item.href);
                  const Icon = item.icon;
                  return (
                    <li key={item.href}>
                      <Link
                        className={cn("nav-link", active && "nav-link-active")}
                        href={item.href}
                        aria-current={active ? "page" : undefined}
                        onClick={() => {
                          setSidebarOpen(false);
                          setQuery("");
                        }}
                        title={item.description}
                      >
                        <span className="nav-icon">
                          <Icon aria-hidden="true" />
                        </span>
                        <span className="nav-copy">
                          <strong>{item.label}</strong>
                          <small>{item.description}</small>
                        </span>
                      </Link>
                    </li>
                  );
                })}
              </ul>
            </div>
          ))}
        </nav>

        <div className="sidebar-footer">
          <div className="sidebar-security">
            <ShieldCheck aria-hidden="true" />
            <span>Protected session · MFA verified</span>
          </div>
        </div>
      </aside>

      <div className="admin-main">
        <header className="admin-topbar">
          <div className="topbar-start">
            <button
              className="icon-button menu-button"
              type="button"
              aria-label="Open navigation"
              onClick={() => setSidebarOpen(true)}
            >
              <Menu aria-hidden="true" />
            </button>
            {CurrentPageIcon ? (
              <span className="topbar-page-icon">
                <CurrentPageIcon aria-hidden="true" />
              </span>
            ) : null}
            <div className="topbar-heading">
              <p className="page-eyebrow">Administration workspace</p>
              <h1 className="topbar-title">{titleForPath(pathname)}</h1>
              <p className="topbar-description">
                {currentNavigationItem?.description ?? "BU Horizon administration"}
              </p>
            </div>
          </div>

          <div className="topbar-actions">
            <div className="topbar-search">
              <Search aria-hidden="true" />
              <label className="sr-only" htmlFor="module-search">
                Search admin modules
              </label>
              <input
                id="module-search"
                ref={searchRef}
                type="search"
                placeholder="Search modules…"
                value={query}
                onChange={(event) => setQuery(event.target.value)}
                onFocus={() => setSearchFocused(true)}
                onBlur={() => window.setTimeout(() => setSearchFocused(false), 120)}
                onKeyDown={(event) => {
                  if (event.key === "Enter" && searchResults[0]) {
                    event.preventDefault();
                    openResult(searchResults[0].href);
                  }
                  if (event.key === "Escape") {
                    setQuery("");
                    searchRef.current?.blur();
                  }
                }}
              />
              <kbd className="search-shortcut">⌘K</kbd>
              {searchFocused && query ? (
                <div className="search-results" role="listbox">
                  {searchResults.length ? (
                    searchResults.map((item) => {
                      const Icon = item.icon;
                      return (
                        <button
                          className="search-result"
                          type="button"
                          key={item.href}
                          onMouseDown={(event) => event.preventDefault()}
                          onClick={() => openResult(item.href)}
                        >
                          <Icon aria-hidden="true" />
                          <span>
                            <strong>{item.label}</strong>
                            <small>{item.description}</small>
                          </span>
                        </button>
                      );
                    })
                  ) : (
                    <p className="search-empty">No matching module</p>
                  )}
                </div>
              ) : null}
            </div>

            <ThemeToggle />
            <button
              className="icon-button"
              type="button"
              aria-label="Sign out"
              title="Sign out"
              onClick={signOut}
            >
              <LogOut aria-hidden="true" />
            </button>
            <div className="admin-identity" title={admin.email}>
              <div className="admin-avatar" aria-hidden="true">
                {initials(admin.fullName)}
              </div>
              <div>
                <p className="admin-name">{admin.fullName}</p>
                <p className="admin-role">Super administrator</p>
              </div>
            </div>
          </div>
        </header>

        <main className="admin-content">{children}</main>
      </div>
    </div>
  );
}
