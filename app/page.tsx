import Link from "next/link";
import { copy } from "@/lib/copy";
import SoftButton from "@/components/design/SoftButton";
import TodayTracePreview from "@/components/trace/TodayTracePreview";
import RecentSeeds from "@/components/seed/RecentSeeds";

export default function HomePage() {
  return (
    <div className="flex flex-col gap-8">
      <header className="flex flex-col gap-3 pt-6 tdd-rise">
        <h1 className="text-[28px] font-semibold tracking-tight text-[var(--text)]">
          {copy.appTitle}
        </h1>
        <p className="text-[17px] leading-relaxed text-[var(--text)]">
          {copy.home.question}
        </p>
        <p className="whitespace-pre-line text-[14px] leading-relaxed text-[var(--text-secondary)]">
          {copy.home.subtitle}
        </p>
      </header>

      <Link href="/now" className="block">
        <SoftButton full className="tdd-breathe py-4 text-[17px]">
          {copy.home.primary}
        </SoftButton>
      </Link>

      <TodayTracePreview />

      <RecentSeeds />

      <Link
        href="/add"
        className="self-center text-[14px] text-[var(--text-secondary)] underline-offset-4 hover:underline"
      >
        + 丢一个新愿望进来
      </Link>
    </div>
  );
}
