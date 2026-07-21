"use client";

import { RefreshCw, TriangleAlert } from "lucide-react";
import { useEffect } from "react";

export default function DashboardError({
  error,
  reset,
}: {
  error: Error & { digest?: string };
  reset: () => void;
}) {
  useEffect(() => {
    console.error("Admin route failed", error);
  }, [error]);

  return (
    <section className="route-error" role="alert">
      <div className="route-error-icon">
        <TriangleAlert aria-hidden="true" />
      </div>
      <h2>We could not load this admin view</h2>
      <p>
        Check the Supabase environment and your connection, then try the request
        again. No data was changed.
      </p>
      <button className="primary-button" type="button" onClick={reset}>
        <RefreshCw aria-hidden="true" size={17} />
        Try again
      </button>
    </section>
  );
}
