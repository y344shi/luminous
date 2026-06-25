"use client";

import Link from "next/link";
import { usePathname } from "next/navigation";
import { cx } from "@/lib/utils";

const tabs = [
  { href: "/", label: "今天", match: (p: string) => p === "/" },
  { href: "/seeds", label: "愿望", match: (p: string) => p.startsWith("/seeds") },
  { href: "/traces", label: "痕迹", match: (p: string) => p.startsWith("/traces") },
  { href: "/settings", label: "设置", match: (p: string) => p.startsWith("/settings") },
];

export default function BottomNav() {
  const pathname = usePathname();
  return (
    <nav
      aria-label="主导航"
      className="fixed inset-x-0 bottom-0 z-30 border-t border-[var(--border)] bg-[var(--surface)]/90 backdrop-blur-md"
      style={{ paddingBottom: "env(safe-area-inset-bottom)" }}
    >
      <div className="mx-auto flex max-w-md items-stretch justify-around">
        {tabs.map((t) => {
          const active = t.match(pathname);
          return (
            <Link
              key={t.href}
              href={t.href}
              aria-current={active ? "page" : undefined}
              className={cx(
                "flex flex-1 flex-col items-center gap-1 py-3 text-[12px] transition-colors",
                active ? "text-[var(--accent)]" : "text-[var(--text-muted)]"
              )}
            >
              <span
                aria-hidden
                className={cx(
                  "h-1.5 w-1.5 rounded-full transition-all",
                  active ? "bg-[var(--accent)]" : "bg-transparent"
                )}
              />
              {t.label}
            </Link>
          );
        })}
      </div>
    </nav>
  );
}
