"use client";

import { useEffect, useState } from "react";
import { useStore } from "@/lib/store";
import { copy } from "@/lib/copy";
import { cx } from "@/lib/utils";
import { isQuietNow } from "@/lib/reminders";
import BreathingCard from "@/components/design/BreathingCard";
import SoftButton from "@/components/design/SoftButton";
import ThemeSwitcher from "@/components/design/ThemeSwitcher";
import ConfirmSheet from "@/components/design/ConfirmSheet";
import { illustrationStyles, StylePreview, IllustrationArt } from "../home/shared/illustrationPacks";

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

  const [confirmReset, setConfirmReset] = useState(false);
  // Client-only so the live quiet state can't cause a hydration mismatch.
  const [quietNow, setQuietNow] = useState<boolean | null>(null);
  const [notifyState, setNotifyState] = useState<"unsupported" | "default" | "granted" | "denied">("default");
  useEffect(() => {
    setQuietNow(isQuietNow(settings, new Date()));
  }, [settings.quietHoursStart, settings.quietHoursEnd, settings]);
  useEffect(() => {
    if (typeof Notification === "undefined") setNotifyState("unsupported");
    else setNotifyState(Notification.permission as "default" | "granted" | "denied");
  }, []);

  async function toggleNudges() {
    if (settings.nudgesEnabled) {
      updateSettings({ nudgesEnabled: false });
      return;
    }
    if (typeof Notification === "undefined") {
      setNotifyState("unsupported");
      return;
    }
    let perm = Notification.permission;
    if (perm === "default") perm = await Notification.requestPermission();
    setNotifyState(perm as "default" | "granted" | "denied");
    if (perm === "granted") updateSettings({ nudgesEnabled: true });
  }

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

      <Section title={copy.settings.skinLabel}>
        <BreathingCard className="flex gap-2">
          {([
            ["glass", copy.settings.skinGlass],
            ["ocean", copy.settings.skinOcean],
            ["paper", copy.settings.skinPaper],
          ] as const).map(([key, label]) => (
            <button
              key={key}
              onClick={() => updateSettings({ aesthetic: key })}
              aria-pressed={settings.aesthetic === key}
              className={cx(
                "flex-1 rounded-2xl px-3 py-2.5 text-[14px] transition-colors",
                settings.aesthetic === key
                  ? "bg-[var(--accent)] text-[var(--on-accent)]"
                  : "bg-[var(--surface-soft)] text-[var(--text-secondary)]"
              )}
            >
              {label}
            </button>
          ))}
        </BreathingCard>
      </Section>

      <Section title={copy.settings.soundLabel}>
        <BreathingCard className="flex items-center justify-between">
          <span className="text-[15px] text-[var(--text)]">
            {settings.soundEnabled ? copy.settings.soundOn : copy.settings.soundOff}
          </span>
          <button
            onClick={() => updateSettings({ soundEnabled: !settings.soundEnabled })}
            className={cx(
              "relative h-7 w-12 rounded-full transition-colors",
              settings.soundEnabled ? "bg-[var(--accent)]" : "bg-[var(--surface-soft)]"
            )}
            aria-label="切换完成时的轻响"
            aria-pressed={settings.soundEnabled}
          >
            <span
              className={cx(
                "absolute top-1 h-5 w-5 rounded-full bg-[var(--surface)] transition-all",
                settings.soundEnabled ? "left-6" : "left-1"
              )}
            />
          </button>
        </BreathingCard>
      </Section>

      <Section title={copy.settings.illustrationLabel}>
        <p className="-mt-1 mb-2 text-[12px] text-[var(--text-muted)]">
          {copy.settings.illustrationHelp}
        </p>
        <div className="grid grid-cols-2 gap-2.5">
          {illustrationStyles.map((st) => {
            const on = settings.illustrationStyle === st.key;
            return (
              <button
                key={st.key}
                onClick={() => updateSettings({ illustrationStyle: st.key })}
                aria-pressed={on}
                className={cx(
                  "flex flex-col gap-1.5 rounded-2xl border p-2 text-left transition-colors",
                  on
                    ? "border-[var(--accent)] bg-[var(--accent-soft)]"
                    : "border-[var(--border)] bg-[var(--surface)]"
                )}
              >
                {/* fixed light card so the library-style art (some dark line-work)
                    reads in every theme, including the dark soft_ritual */}
                <span className="h-16 w-full overflow-hidden rounded-xl bg-[#f1ece2]">
                  <StylePreview art={st.art} />
                </span>
                <span className="text-[13px] font-medium text-[var(--text)]">{st.name}</span>
                <span className="text-[11px] text-[var(--text-muted)]">{st.note}</span>
              </button>
            );
          })}
        </div>
        <div className="mt-1 flex items-center gap-3 rounded-2xl border border-[var(--border)] bg-[var(--surface)] p-3">
          <span className="h-16 w-24 shrink-0 overflow-hidden rounded-xl bg-[#f1ece2]">
            <IllustrationArt style={settings.illustrationStyle} category="learning" />
          </span>
          <div className="flex flex-col gap-0.5">
            <span className="serif text-[15px] text-[var(--text)]">{copy.settings.illustrationSample}</span>
            <span className="text-[12px] text-[var(--text-secondary)]">{copy.settings.illustrationSampleAction}</span>
          </div>
        </div>
      </Section>

      <Section title={copy.settings.nudgeLabel}>
        <BreathingCard className="flex flex-col gap-2">
          <div className="flex items-center justify-between">
            <span className="text-[15px] text-[var(--text)]">
              {settings.nudgesEnabled ? copy.settings.nudgeOn : copy.settings.nudgeOff}
            </span>
            <button
              onClick={toggleNudges}
              disabled={notifyState === "unsupported"}
              className={cx(
                "relative h-7 w-12 rounded-full transition-colors disabled:opacity-50",
                settings.nudgesEnabled ? "bg-[var(--accent)]" : "bg-[var(--surface-soft)]"
              )}
              aria-label="切换轻轻提醒"
              aria-pressed={settings.nudgesEnabled}
            >
              <span
                className={cx(
                  "absolute top-1 h-5 w-5 rounded-full bg-[var(--surface)] transition-all",
                  settings.nudgesEnabled ? "left-6" : "left-1"
                )}
              />
            </button>
          </div>
          <p className="text-[12px] leading-relaxed text-[var(--text-muted)]">
            {notifyState === "unsupported"
              ? copy.settings.nudgeUnsupported
              : notifyState === "denied"
                ? copy.settings.nudgeDenied
                : copy.settings.nudgeHelp}
          </p>
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
          {quietNow !== null && (
            <p className="text-[12px] text-[var(--text-secondary)]">
              {quietNow ? copy.settings.quietNow : copy.settings.quietNotNow}
            </p>
          )}
        </BreathingCard>
      </Section>

      <Section title={copy.settings.maxRemindersLabel}>
        <BreathingCard className="flex items-center justify-between">
          <span className="text-[15px] text-[var(--text)]">每天最多</span>
          <div className="flex items-center gap-3">
            <button
              aria-label="减少每天契机次数"
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
              aria-label="增加每天契机次数"
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
        <SoftButton full variant="ghost" onClick={() => setConfirmReset(true)}>
          清空本地数据
        </SoftButton>
      </Section>

      <ConfirmSheet
        open={confirmReset}
        title={copy.settings.resetConfirmTitle}
        body={copy.settings.resetConfirm}
        confirmLabel={copy.settings.resetConfirmYes}
        cancelLabel={copy.settings.resetConfirmNo}
        onConfirm={() => {
          resetAll();
          setConfirmReset(false);
        }}
        onCancel={() => setConfirmReset(false)}
      />
    </div>
  );
}
