import {
  Activity,
  BookOpenCheck,
  BusFront,
  Database,
  FileClock,
  GraduationCap,
  LayoutDashboard,
  Megaphone,
  ScrollText,
  ShieldCheck,
  Sparkles,
  Users,
  type LucideIcon,
} from "lucide-react";

export type NavigationItem = {
  label: string;
  href: string;
  description: string;
  icon: LucideIcon;
};

export type NavigationGroup = {
  label: string;
  items: NavigationItem[];
};

export const navigationGroups: NavigationGroup[] = [
  {
    label: "Overview",
    items: [
      {
        label: "Dashboard",
        href: "/",
        description: "Campus health and activity",
        icon: LayoutDashboard,
      },
    ],
  },
  {
    label: "People",
    items: [
      {
        label: "Students",
        href: "/students",
        description: "Accounts, profiles and status",
        icon: Users,
      },
      {
        label: "CR Management",
        href: "/cr-management",
        description: "Promote and manage class representatives",
        icon: ShieldCheck,
      },
    ],
  },
  {
    label: "Academic operations",
    items: [
      {
        label: "Academics",
        href: "/academics",
        description: "Faculties, departments, batches and courses",
        icon: GraduationCap,
      },
      {
        label: "Attendance",
        href: "/attendance",
        description: "Sessions, records and correction requests",
        icon: BookOpenCheck,
      },
      {
        label: "Content",
        href: "/content",
        description: "Schedules, exams, notices and resources",
        icon: Megaphone,
      },
    ],
  },
  {
    label: "Campus services",
    items: [
      {
        label: "Campus",
        href: "/campus",
        description: "Bus, blood help, lost and found",
        icon: BusFront,
      },
      {
        label: "Workflows",
        href: "/workflows",
        description: "Requests, approvals and notifications",
        icon: FileClock,
      },
    ],
  },
  {
    label: "Forum & clubs",
    items: [
      {
        label: "BU ISSF Club",
        href: "/club",
        description: "Club profile, leadership, activities and notices",
        icon: Sparkles,
      },
    ],
  },
  {
    label: "System",
    items: [
      {
        label: "Database",
        href: "/database",
        description: "Organized view of Supabase data",
        icon: Database,
      },
      {
        label: "Audit log",
        href: "/audit",
        description: "Immutable privileged activity",
        icon: ScrollText,
      },
    ],
  },
];

export const allNavigationItems = navigationGroups.flatMap((group) => group.items);

export function navigationItemForPath(pathname: string) {
  return allNavigationItems.find((item) =>
    item.href === "/" ? pathname === "/" : pathname.startsWith(item.href),
  );
}

export function titleForPath(pathname: string) {
  const match = navigationItemForPath(pathname);
  return match?.label ?? "Administration";
}

export const dashboardActivityIcon = Activity;
