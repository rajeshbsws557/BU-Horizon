import type { Metadata } from "next";
import { Suspense } from "react";

import { SectionWorkspace } from "@/components/data/section-workspace";

export const metadata: Metadata = { title: "Club Info & Management" };

export default function ClubPage() {
  return (
    <Suspense>
      <SectionWorkspace
        defaultEntity="club_info"
        description="Update BU ISSF (Barishal University Intelligent Systems & Security Forum) profile metadata, manage executive & core committee members, organize workshop/hackathon activity cards, and publish forum notices shown directly in the mobile app."
        eyebrow="Forum & clubs"
        groups={["club"]}
        title="BU ISSF Club management"
      />
    </Suspense>
  );
}
