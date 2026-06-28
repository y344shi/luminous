"use client";

import { useStore } from "@/lib/store";
import { themes, themeMeta, themeOrder } from "@/lib/themes";
import { cx } from "@core/utils";

export default function ThemeSwitcher() {
  const current = useStore((s) => s.settings.theme);
  const setTheme = useStore((s) => s.setTheme);

  return (
    <div className="flex flex-col gap-3">
      {themeOrder.map((name) => {
        const t = themes[name];
        const meta = themeMeta[name];
        const active = current === name;
        return (
          <button
            key={name}
            onClick={() => setTheme(name)}
            className={cx(
              "flex items-center gap-3 rounded-[20px] border p-3 text-left transition-all active:scale-[0.99]",
              active
                ? "border-[var(--accent)] bg-[var(--accent-soft)]"
                : "border-[var(--border)] bg-[var(--surface)]"
            )}
          >
            <span
              className="flex h-10 w-10 shrink-0 overflow-hidden rounded-full border"
              style={{ borderColor: t.border }}
            >
              <span className="h-full w-1/2" style={{ background: t.background }} />
              <span className="h-full w-1/2" style={{ background: t.accent }} />
            </span>
            <span className="flex flex-col">
              <span className="text-[15px] font-medium text-[var(--text)]">{meta.label}</span>
              <span className="text-[12px] text-[var(--text-secondary)]">{meta.feeling}</span>
            </span>
            {active && <span className="ml-auto text-[var(--accent-text)]">●</span>}
          </button>
        );
      })}
    </div>
  );
}
