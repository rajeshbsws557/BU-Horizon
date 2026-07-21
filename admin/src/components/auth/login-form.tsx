"use client";

import {
  AlertCircle,
  Eye,
  EyeOff,
  LockKeyhole,
  Mail,
  ShieldCheck,
} from "lucide-react";
import Image from "next/image";
import { useRouter } from "next/navigation";
import { useState, type FormEvent } from "react";

import { createBrowserClient } from "@/lib/supabase/client";

type LoginFormProps = {
  nextPath: string;
  initialError?: string;
};

const errorMessages: Record<string, string> = {
  session: "Your session expired. Sign in again to continue.",
  "not-authorized": "This console is restricted to active super administrators.",
  callback: "The authentication link is invalid or has expired.",
};

export function LoginForm({ nextPath, initialError }: LoginFormProps) {
  const router = useRouter();
  const [email, setEmail] = useState("");
  const [password, setPassword] = useState("");
  const [showPassword, setShowPassword] = useState(false);
  const [submitting, setSubmitting] = useState(false);
  const [error, setError] = useState(
    initialError ? (errorMessages[initialError] ?? initialError) : "",
  );

  async function handleSubmit(event: FormEvent<HTMLFormElement>) {
    event.preventDefault();
    setSubmitting(true);
    setError("");

    try {
      const supabase = createBrowserClient();
      const { data, error: signInError } = await supabase.auth.signInWithPassword({
        email: email.trim().toLowerCase(),
        password,
      });

      if (signInError || !data.user) {
        setError(signInError?.message ?? "Unable to sign in with those credentials.");
        return;
      }

      const { data: profile, error: profileError } = await supabase
        .from("profiles")
        .select("role, status, deleted_at")
        .eq("id", data.user.id)
        .maybeSingle();

      const allowed =
        !profileError &&
        profile?.role === "super_admin" &&
        profile.status === "active" &&
        profile.deleted_at === null;

      if (!allowed) {
        await supabase.auth.signOut();
        setError("This console is restricted to active super administrators.");
        return;
      }

      const { data: assurance } =
        await supabase.auth.mfa.getAuthenticatorAssuranceLevel();

      if (assurance?.currentLevel !== "aal2") {
        const next = encodeURIComponent(nextPath);
        router.replace(`/mfa?next=${next}`);
      } else {
        router.replace(nextPath);
      }
      router.refresh();
    } catch (caught) {
      setError(caught instanceof Error ? caught.message : "Unable to sign in.");
    } finally {
      setSubmitting(false);
    }
  }

  return (
    <main className="auth-page">
      <div className="auth-grid" aria-hidden="true" />
      <section className="auth-card" aria-labelledby="login-heading">
        <div className="auth-brand">
          <Image
            className="auth-logo"
            src="/logo.png"
            width={58}
            height={58}
            priority
            alt="BU Horizon emblem"
          />
          <div>
            <p className="auth-brand-name">BU Horizon</p>
            <p className="auth-brand-label">Administration console</p>
          </div>
        </div>

        <h1 className="auth-heading" id="login-heading">
          Welcome back
        </h1>
        <p className="auth-copy">
          Sign in with your authorized university account to manage campus
          operations.
        </p>

        {error ? (
          <div className="auth-error" role="alert">
            <AlertCircle aria-hidden="true" size={17} />
            <span>{error}</span>
          </div>
        ) : null}

        <form className="auth-form" onSubmit={handleSubmit}>
          <label className="field-group">
            <span className="field-label">University email</span>
            <span className="field-shell">
              <Mail className="field-icon" aria-hidden="true" />
              <input
                className="field-input"
                type="email"
                name="email"
                autoComplete="username"
                inputMode="email"
                placeholder="admin@bu.ac.bd"
                value={email}
                onChange={(event) => setEmail(event.target.value)}
                required
                autoFocus
              />
            </span>
          </label>

          <label className="field-group">
            <span className="field-label">Password</span>
            <span className="field-shell">
              <LockKeyhole className="field-icon" aria-hidden="true" />
              <input
                className="field-input"
                type={showPassword ? "text" : "password"}
                name="password"
                autoComplete="current-password"
                placeholder="Enter your password"
                value={password}
                onChange={(event) => setPassword(event.target.value)}
                required
              />
              <button
                className="field-action"
                type="button"
                onClick={() => setShowPassword((visible) => !visible)}
                aria-label={showPassword ? "Hide password" : "Show password"}
              >
                {showPassword ? (
                  <EyeOff aria-hidden="true" size={17} />
                ) : (
                  <Eye aria-hidden="true" size={17} />
                )}
              </button>
            </span>
          </label>

          <button className="primary-button" type="submit" disabled={submitting}>
            {submitting ? (
              <span className="spinner" aria-hidden="true" />
            ) : (
              <ShieldCheck aria-hidden="true" size={18} />
            )}
            {submitting ? "Verifying account…" : "Sign in securely"}
          </button>
        </form>

        <p className="auth-footer">
          Protected by Supabase authentication, row-level security and MFA.
        </p>
      </section>
    </main>
  );
}
