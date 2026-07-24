"use client";

import {
  AlertCircle,
  CheckCircle2,
  Copy,
  KeyRound,
  LogOut,
  ShieldCheck,
  Smartphone,
} from "lucide-react";
import Image from "next/image";
import { useRouter } from "next/navigation";
import { useEffect, useState, type FormEvent } from "react";
import { toast } from "sonner";

import { createBrowserClient } from "@/lib/supabase/client";

type MfaFormProps = {
  adminName: string;
  nextPath: string;
};

type Enrollment = {
  factorId: string;
  qrCode: string;
  secret: string;
};

export function MfaForm({ adminName, nextPath }: MfaFormProps) {
  const router = useRouter();
  const [factorId, setFactorId] = useState("");
  const [enrollment, setEnrollment] = useState<Enrollment | null>(null);
  const [code, setCode] = useState("");
  const [loading, setLoading] = useState(true);
  const [submitting, setSubmitting] = useState(false);
  const [error, setError] = useState("");

  useEffect(() => {
    let cancelled = false;

    async function prepareFactor() {
      try {
        const supabase = createBrowserClient();
        const { data: factors, error: factorsError } =
          await supabase.auth.mfa.listFactors();
        if (factorsError) throw factorsError;

        const verifiedTotp = factors.totp.at(0);
        if (verifiedTotp) {
          if (!cancelled) setFactorId(verifiedTotp.id);
          return;
        }

        const pendingFactors = factors.all.filter(
          (factor) => factor.factor_type === "totp" && factor.status !== "verified",
        );
        await Promise.all(
          pendingFactors.map((factor) =>
            supabase.auth.mfa.unenroll({ factorId: factor.id }),
          ),
        );

        const { data: enrolled, error: enrollError } = await supabase.auth.mfa.enroll({
          factorType: "totp",
          friendlyName: "BU Horizon Admin",
        });
        if (enrollError) throw enrollError;

        if (!cancelled) {
          setFactorId(enrolled.id);
          setEnrollment({
            factorId: enrolled.id,
            qrCode: enrolled.totp.qr_code,
            secret: enrolled.totp.secret,
          });
        }
      } catch (caught) {
        if (!cancelled) {
          setError(
            caught instanceof Error
              ? caught.message
              : "Unable to prepare multi-factor authentication.",
          );
        }
      } finally {
        if (!cancelled) setLoading(false);
      }
    }

    void prepareFactor();
    return () => {
      cancelled = true;
    };
  }, []);

  async function handleVerify(event: FormEvent<HTMLFormElement>) {
    event.preventDefault();
    if (!factorId || code.length !== 6) return;

    setSubmitting(true);
    setError("");
    try {
      const supabase = createBrowserClient();
      const { error: verifyError } = await supabase.auth.mfa.challengeAndVerify({
        factorId,
        code,
      });
      if (verifyError) throw verifyError;

      toast.success("Identity verified");
      window.location.assign(nextPath);
    } catch (caught) {
      setCode("");
      setError(
        caught instanceof Error
          ? caught.message
          : "That verification code could not be confirmed.",
      );
    } finally {
      setSubmitting(false);
    }
  }

  async function handleSignOut() {
    const supabase = createBrowserClient();
    await supabase.auth.signOut();
    window.location.assign("/login");
  }

  async function copySecret() {
    if (!enrollment?.secret) return;
    await navigator.clipboard.writeText(enrollment.secret);
    toast.success("Setup key copied");
  }

  const qrSource = enrollment?.qrCode ?? "";

  return (
    <main className="auth-page">
      <div className="auth-grid" aria-hidden="true" />
      <section className="auth-card" aria-labelledby="mfa-heading">
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
            <p className="auth-brand-name">Identity check</p>
            <p className="auth-brand-label">Signed in as {adminName}</p>
          </div>
        </div>

        <h1 className="auth-heading" id="mfa-heading">
          {enrollment ? "Secure your account" : "Two-step verification"}
        </h1>
        <p className="auth-copy">
          {enrollment
            ? "Scan this code with an authenticator app, then enter the six-digit code to finish enrollment."
            : "Enter the current six-digit code from your authenticator app."}
        </p>

        {error ? (
          <div className="auth-error" role="alert">
            <AlertCircle aria-hidden="true" size={17} />
            <span>{error}</span>
          </div>
        ) : null}

        {loading ? (
          <div className="auth-notice" aria-live="polite">
            <Smartphone aria-hidden="true" size={17} />
            <span>Preparing your secure verification method…</span>
          </div>
        ) : null}

        {enrollment ? (
          <div className="mfa-enrollment">
            <div className="mfa-qr-shell">
              {/* Supabase returns the enrollment QR as an inline SVG data URL.
                  next/image rejects inline SVG sources even when unoptimized,
                  so render this trusted Auth API response as a plain image. */}
              {/* eslint-disable-next-line @next/next/no-img-element */}
              <img
                src={qrSource}
                width={188}
                height={188}
                alt="Authenticator enrollment QR code"
              />
            </div>
            <div>
              <p className="field-label">Manual setup key</p>
              <button className="mfa-secret" type="button" onClick={copySecret}>
                <code>{enrollment.secret}</code>
                <Copy aria-hidden="true" size={15} />
              </button>
            </div>
          </div>
        ) : null}

        {!loading && factorId ? (
          <form className="auth-form" onSubmit={handleVerify}>
            <label className="field-group">
              <span className="field-label">Verification code</span>
              <span className="field-shell">
                <KeyRound className="field-icon" aria-hidden="true" />
                <input
                  className="field-input mfa-code"
                  name="code"
                  inputMode="numeric"
                  pattern="[0-9]{6}"
                  autoComplete="one-time-code"
                  placeholder="000000"
                  maxLength={6}
                  value={code}
                  onChange={(event) =>
                    setCode(event.target.value.replace(/\D/g, "").slice(0, 6))
                  }
                  required
                  autoFocus
                />
              </span>
            </label>

            <button
              className="primary-button"
              type="submit"
              disabled={submitting || code.length !== 6}
            >
              {submitting ? (
                <span className="spinner" aria-hidden="true" />
              ) : enrollment ? (
                <CheckCircle2 aria-hidden="true" size={18} />
              ) : (
                <ShieldCheck aria-hidden="true" size={18} />
              )}
              {submitting ? "Verifying…" : "Verify and continue"}
            </button>
          </form>
        ) : null}

        <button className="auth-signout" type="button" onClick={handleSignOut}>
          <LogOut aria-hidden="true" size={15} />
          Use a different account
        </button>
      </section>
    </main>
  );
}
