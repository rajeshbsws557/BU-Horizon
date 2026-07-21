import type { CSSProperties } from "react";
import {
  ArrowUpRight,
  BookOpenCheck,
  BusFront,
  CalendarClock,
  Database,
  FileCheck2,
  FileClock,
  GraduationCap,
  HeartPulse,
  Megaphone,
  PackageSearch,
  ScrollText,
  ShieldCheck,
  TriangleAlert,
  UserRoundCog,
  Users,
} from "lucide-react";
import Link from "next/link";

import type { DashboardData } from "@/features/dashboard/dashboard-data";
import { formatDhakaDate, formatNumber } from "@/lib/utils";

type DashboardViewProps = {
  data: DashboardData;
  adminName: string;
};

type TokenStyle = CSSProperties & {
  "--metric-color"?: string;
  "--attention-color"?: string;
};

function greeting() {
  const hour = Number(
    new Intl.DateTimeFormat("en-US", {
      hour: "2-digit",
      hourCycle: "h23",
      timeZone: "Asia/Dhaka",
    }).format(new Date()),
  );
  if (hour < 12) return "Good morning";
  if (hour < 17) return "Good afternoon";
  return "Good evening";
}

function actionLabel(value: string) {
  return value
    .replace(/[._-]+/g, " ")
    .replace(/\b\w/g, (letter) => letter.toUpperCase());
}

const metricCards = [
  {
    key: "activeStudents" as const,
    label: "Active students",
    meta: "Approved student profiles",
    icon: Users,
    color: "var(--primary)",
  },
  {
    key: "classRepresentatives" as const,
    label: "Class representatives",
    meta: "Current CR assignments",
    icon: ShieldCheck,
    color: "var(--success)",
  },
  {
    key: "activeBatches" as const,
    label: "Active batches",
    meta: "Across all academic programs",
    icon: GraduationCap,
    color: "var(--purple)",
  },
  {
    key: "courses" as const,
    label: "Courses",
    meta: "Available, non-archived courses",
    icon: BookOpenCheck,
    color: "var(--warning)",
  },
];

export function DashboardView({ data, adminName }: DashboardViewProps) {
  const attention = [
    {
      label: "Attendance corrections",
      value: data.attention.attendanceCorrections,
      href: "/attendance",
      icon: FileCheck2,
      color: "var(--warning)",
    },
    {
      label: "Batch change requests",
      value: data.attention.batchChanges,
      href: "/workflows",
      icon: FileClock,
      color: "var(--purple)",
    },
    {
      label: "Open blood requests",
      value: data.attention.openBloodRequests,
      href: "/campus",
      icon: HeartPulse,
      color: "var(--danger)",
    },
    {
      label: "Open lost & found posts",
      value: data.attention.openLostFound,
      href: "/campus",
      icon: PackageSearch,
      color: "var(--primary)",
    },
  ];

  const snapshots = [
    {
      label: "Published notices",
      value: data.content.publishedNotices,
      icon: Megaphone,
    },
    {
      label: "Upcoming exams",
      value: data.content.upcomingExams,
      icon: CalendarClock,
    },
    {
      label: "Available resources",
      value: data.content.resources,
      icon: FileCheck2,
    },
  ];

  const quickActions = [
    { label: "Manage students", href: "/students", icon: UserRoundCog },
    { label: "Assign a CR", href: "/cr-management", icon: ShieldCheck },
    { label: "Publish content", href: "/content", icon: Megaphone },
    { label: "Browse database", href: "/database", icon: Database },
  ];

  return (
    <>
      <header className="dashboard-header">
        <div>
          <h2 className="dashboard-title">
            {greeting()}, {adminName.split(" ")[0] || "Admin"}
          </h2>
          <p className="dashboard-subtitle">
            Here is a live overview of accounts, academics and campus operations
            across BU Horizon.
          </p>
        </div>
        <div className="live-badge">
          <span className="live-dot" aria-hidden="true" />
          Live Supabase data
        </div>
      </header>

      {!data.healthy ? (
        <div className="data-warning" role="status">
          <TriangleAlert aria-hidden="true" />
          <span>
            {data.issueCount} dashboard {data.issueCount === 1 ? "query" : "queries"}
            {" "}could not be loaded. Available metrics are still shown; verify the
            Supabase connection and final RLS policies.
          </span>
        </div>
      ) : null}

      <section className="metric-grid" aria-label="Key campus metrics">
        {metricCards.map((card) => {
          const Icon = card.icon;
          return (
            <article
              className="metric-card"
              key={card.key}
              style={{ "--metric-color": card.color } as TokenStyle}
            >
              <div className="metric-top">
                <div className="metric-icon">
                  <Icon aria-hidden="true" />
                </div>
                <ArrowUpRight aria-hidden="true" size={15} color="var(--text-muted)" />
              </div>
              <p className="metric-label">{card.label}</p>
              <p className="metric-value">{formatNumber(data.metrics[card.key])}</p>
              <p className="metric-meta">{card.meta}</p>
            </article>
          );
        })}
      </section>

      <div className="dashboard-grid">
        <div className="dashboard-column">
          <section className="dashboard-card" aria-labelledby="activity-heading">
            <div className="card-header">
              <div>
                <h3 className="card-title" id="activity-heading">
                  Recent privileged activity
                </h3>
                <p className="card-subtitle">Immutable audit trail from Supabase</p>
              </div>
              <Link className="text-link" href="/audit">
                Full audit log <ArrowUpRight aria-hidden="true" />
              </Link>
            </div>
            {data.audit.length ? (
              <ul className="activity-list">
                {data.audit.map((item) => (
                  <li className="activity-item" key={item.id}>
                    <div className="activity-icon">
                      <ScrollText aria-hidden="true" />
                    </div>
                    <div className="activity-copy">
                      <p className="activity-action">{actionLabel(item.action)}</p>
                      <p className="activity-meta">
                        {item.actorName} · {actionLabel(item.entity_type)}
                        {item.entity_id ? ` · ${item.entity_id.slice(0, 8)}` : ""}
                      </p>
                    </div>
                    <time className="activity-time" dateTime={item.created_at}>
                      {formatDhakaDate(item.created_at)}
                    </time>
                  </li>
                ))}
              </ul>
            ) : (
              <div className="empty-panel">
                <div>
                  <ScrollText aria-hidden="true" />
                  <p>No privileged actions have been recorded yet.</p>
                </div>
              </div>
            )}
          </section>

          <section className="dashboard-card" aria-labelledby="snapshot-heading">
            <div className="card-header">
              <div>
                <h3 className="card-title" id="snapshot-heading">
                  Academic content snapshot
                </h3>
                <p className="card-subtitle">Currently visible content and events</p>
              </div>
              <Link className="text-link" href="/content">
                Manage content <ArrowUpRight aria-hidden="true" />
              </Link>
            </div>
            <div className="snapshot-grid">
              {snapshots.map((item) => {
                const Icon = item.icon;
                return (
                  <div className="snapshot-item" key={item.label}>
                    <Icon aria-hidden="true" />
                    <div>
                      <strong>{formatNumber(item.value)}</strong>
                      <span>{item.label}</span>
                    </div>
                  </div>
                );
              })}
            </div>
          </section>
        </div>

        <aside className="dashboard-column">
          <section className="dashboard-card" aria-labelledby="attention-heading">
            <div className="card-header">
              <div>
                <h3 className="card-title" id="attention-heading">
                  Needs attention
                </h3>
                <p className="card-subtitle">Open requests and service posts</p>
              </div>
            </div>
            <ul className="attention-list">
              {attention.map((item) => {
                const Icon = item.icon;
                return (
                  <li key={item.label}>
                    <Link
                      className="attention-item"
                      href={item.href}
                      style={{ "--attention-color": item.color } as TokenStyle}
                    >
                      <span className="attention-label">
                        <Icon aria-hidden="true" />
                        {item.label}
                      </span>
                      <span className="count-badge">{formatNumber(item.value)}</span>
                    </Link>
                  </li>
                );
              })}
            </ul>
          </section>

          <section className="dashboard-card" aria-labelledby="quick-heading">
            <div className="card-header">
              <div>
                <h3 className="card-title" id="quick-heading">
                  Quick actions
                </h3>
                <p className="card-subtitle">Jump into common admin tasks</p>
              </div>
            </div>
            <div className="quick-list">
              {quickActions.map((action) => {
                const Icon = action.icon;
                return (
                  <Link className="quick-link" href={action.href} key={action.href}>
                    <Icon aria-hidden="true" />
                    <span>{action.label}</span>
                  </Link>
                );
              })}
            </div>
          </section>

          <section className="dashboard-card campus-card" aria-label="Campus services">
            <div className="campus-card-icon">
              <BusFront aria-hidden="true" />
            </div>
            <div>
              <h3>Campus services</h3>
              <p>Maintain bus routes and moderate blood help or lost & found posts.</p>
              <Link className="text-link" href="/campus">
                Open services <ArrowUpRight aria-hidden="true" />
              </Link>
            </div>
          </section>
        </aside>
      </div>
    </>
  );
}
