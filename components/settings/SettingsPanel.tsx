"use client";

import { useStore } from "@/lib/store";
import { copy } from "@/lib/copy";
import { cx } from "@/lib/utils";
import BreathingCard from "@/components/design/BreathingCard";
import SoftButton from "@/components/design/SoftButton";
import ThemeSwitcher from "@/components/design/ThemeSwitcher";

function Section({ title, children }: { title: string; children: React.ReactNode }) {
  return (
    <section className="flex flex-col gap-3">
      <h2 className="px-1 text-[13px] font-medium text-[var(--text-muted)]">{title}</h2>
      {children}
    </section>
  );
}

const hourLabel = (h: number) => `${String(h).padStart(2, "0")}:00`;
const HOURS = Array.from({ length: 24 }, (_, h) => h);

function HourSelect({
  value,
  onChange,
  label,
}: {
  value: number;
  onChange: (h: number) => void;
  label: string;
}) {
  return (
    <label className="flex items-center gap-2 text-[14px] text-[var(--text-secondary)]">
      {label}
      <select
        value={value}
        onChange={(e) => onChange(Number(e.target.value))}
        className="rounded-full border border-[var(--border)] bg-[var(--surface-soft)] px-3 py-1.5 text-[15px] text-[var(--text)] focus:outline-none focus:ring-2 focus:ring-[var(--accent-soft)]"
      >
        {HOURS.map((h) => (
          <option key={h} value={h}>
            {hourLabel(h)}
          </option>
        ))}
      </select>
    </label>
  );
}

export default function SettingsPanel() {
  const hydrated = useStore((s) => s.hydrated);
  const settings = useStore((s) => s.settings);
  const updateSettings = useStore((s) => s.updateSettings);
  const resetAll = useStore((s) => s.resetAll);

  if (!hydrated) return null;

  return (
    <div className="flex flex-col gap-7">
      <Section title={copy.settings.themeLabel}>
        <ThemeSwitcher />
      </Section>

      <Section title={copy.settings.aiLabel}>
        <BreathingCard className="flex items-center justify-between">
          <div className="flex flex-col">
            <span className="text-[15px] text-[var(--text)]">
              {settings.aiMode === "mock" ? "本地规则模式" : "AI 模式"}
            </span>
            <span className="text-[12px] text-[var(--text-secondary)]">
              {settings.aiMode === "mock"
                ? "完全在本地运行，不联网。"
                : "接入真实 AI（稍后启用）。"}
            </span>
          </div>
          <button
            onClick={() =>
              updateSettings({ aiMode: settings.aiMode === "mock" ? "real" : "mock" })
            }
            className={cx(
              "relative h-7 w-12 rounded-full transition-colors",
              settings.aiMode === "real" ? "bg-[var(--accent)]" : "bg-[var(--surface-soft)]"
            )}
            aria-label="切换 AI 模式"
          >
            <span
              className={cx(
                "absolute top-1 h-5 w-5 rounded-full bg-[var(--surface)] transition-all",
                settings.aiMode === "real" ? "left-6" : "left-1"
              )}
            />
          </button>
        </BreathingCard>
      </Section>

      <Section title={copy.settings.quietLabel}>
        <BreathingCard className="flex flex-col gap-3">
          <div className="flex flex-wrap items-center gap-x-4 gap-y-3">
            <HourSelect
              label={copy.settings.quietFrom}
              value={settings.quietHoursStart}
              onChange={(h) => updateSettings({ quietHoursStart: h })}
            />
            <HourSelect
              label={copy.settings.quietTo}
              value={settings.quietHoursEnd}
              onChange={(h) => updateSettings({ quietHoursEnd: h })}
            />
          </div>
          <p className="text-[12px] text-[var(--text-muted)]">{copy.settings.quietHelp}</p>
        </BreathingCard>
      </Section>

      <Section title={copy.settings.maxRemindersLabel}>
        <BreathingCard className="flex items-center justify-between">
          <span className="text-[15px] text-[var(--text)]">每天最多</span>
          <div className="flex items-center gap-3">
            <button
              onClick={() =>
                updateSettings({
                  maxRemindersPerDay: Math.max(0, settings.maxRemindersPerDay - 1),
                })
              }
              className="h-8 w-8 rounded-full bg-[var(--surface-soft)] text-[var(--text)]"
            >
              −
            </button>
            <span className="w-6 text-center text-[16px] text-[var(--text)]">
              {settings.maxRemindersPerDay}
            </span>
            <button
              onClick={() =>
                updateSettings({
                  maxRemindersPerDay: Math.min(8, settings.maxRemindersPerDay + 1),
                })
              }
              className="h-8 w-8 rounded-full bg-[var(--surface-soft)] text-[var(--text)]"
            >
              +
            </button>
          </div>
        </BreathingCard>
      </Section>

      <Section title="隐私">
        <BreathingCard soft>
          <p className="whitespace-pre-line text-[14px] leading-relaxed text-[var(--text-secondary)]">
            {copy.settings.privacy}
          </p>
        </BreathingCard>
      </Section>

      <Section title={copy.settings.resetLabel}>
        <SoftButton
          full
          variant="ghost"
          onClick={() => {
            if (confirm(copy.settings.resetConfirm)) resetAll();
          }}
        >
          清空本地数据
        </SoftButton>
      </Section>
    </div>
  );
}
