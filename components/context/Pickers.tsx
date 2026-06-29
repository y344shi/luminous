"use client";

import type { Mood, Energy, LocationType } from "@core/types";
import { cx } from "@core/utils";

export const moodOptions: { value: Mood; label: string }[] = [
  { value: "empty", label: "有点空" },
  { value: "tired", label: "累" },
  { value: "anxious", label: "焦虑" },
  { value: "okay", label: "还行" },
  { value: "alive", label: "有点想活过来" },
  { value: "avoidant", label: "想逃避" },
  { value: "want_love", label: "想被爱" },
  { value: "lonely", label: "有点孤单" },
  { value: "unknown", label: "我也不知道" },
];

export const energyOptions: { value: Energy; label: string }[] = [
  { value: "low", label: "低" },
  { value: "medium", label: "中" },
  { value: "high", label: "高" },
];

export const freeOptions: { value: number | undefined; label: string }[] = [
  { value: 5, label: "5 分钟" },
  { value: 15, label: "15 分钟" },
  { value: 30, label: "30 分钟" },
  { value: 90, label: "1 小时以上" },
  { value: undefined, label: "不知道" },
];

export const locationOptions: { value: LocationType; label: string }[] = [
  { value: "home", label: "在家" },
  { value: "computer", label: "电脑前" },
  { value: "outdoor", label: "在外面" },
  { value: "downtown", label: "市中心" },
  { value: "transit", label: "路上" },
];

/** A single on/off pill, e.g. the "天气不错" toggle. */
export function ToggleChip({
  active,
  children,
  onClick,
}: {
  active: boolean;
  children: React.ReactNode;
  onClick: () => void;
}) {
  return (
    <button
      onClick={onClick}
      aria-pressed={active}
      className={cx(
        "rounded-full border px-4 py-2 text-[14px] transition-all duration-200 active:scale-[0.97]",
        active
          ? "border-[var(--accent)] bg-[var(--accent-soft)] text-[var(--text)]"
          : "border-[var(--border)] bg-[var(--surface)] text-[var(--text-secondary)]"
      )}
    >
      {children}
    </button>
  );
}

function Chip({
  active,
  children,
  onClick,
}: {
  active: boolean;
  children: React.ReactNode;
  onClick: () => void;
}) {
  return (
    <button
      onClick={onClick}
      aria-pressed={active}
      className={cx(
        "rounded-full border px-4 py-2 text-[14px] transition-all duration-200 active:scale-[0.97]",
        active
          ? "border-[var(--accent)] bg-[var(--accent-soft)] text-[var(--text)]"
          : "border-[var(--border)] bg-[var(--surface)] text-[var(--text-secondary)]"
      )}
    >
      {children}
    </button>
  );
}

export function ChipGroup<T>({
  options,
  value,
  onChange,
  isEqual,
}: {
  options: { value: T; label: string }[];
  value: T | undefined;
  onChange: (v: T) => void;
  isEqual?: (a: T | undefined, b: T) => boolean;
}) {
  const eq = isEqual ?? ((a: T | undefined, b: T) => a === b);
  return (
    <div className="flex flex-wrap gap-2">
      {options.map((o, i) => (
        <Chip key={i} active={eq(value, o.value)} onClick={() => onChange(o.value)}>
          {o.label}
        </Chip>
      ))}
    </div>
  );
}
