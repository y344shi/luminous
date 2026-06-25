"use client";

import { useEffect, useRef } from "react";
import SoftButton from "./SoftButton";

/**
 * A soft, themed in-app confirm — replaces the OS `window.confirm`, which
 * breaks the app's gentle aesthetic. Bottom sheet on mobile; dim backdrop;
 * Escape cancels; focus moves to the cancel (safe) action.
 */
export default function ConfirmSheet({
  open,
  title,
  body,
  confirmLabel,
  cancelLabel,
  onConfirm,
  onCancel,
}: {
  open: boolean;
  title: string;
  body?: string;
  confirmLabel: string;
  cancelLabel: string;
  onConfirm: () => void;
  onCancel: () => void;
}) {
  const cancelRef = useRef<HTMLButtonElement>(null);

  useEffect(() => {
    if (!open) return;
    cancelRef.current?.focus();
    const onKey = (e: KeyboardEvent) => {
      if (e.key === "Escape") onCancel();
    };
    window.addEventListener("keydown", onKey);
    return () => window.removeEventListener("keydown", onKey);
  }, [open, onCancel]);

  if (!open) return null;

  return (
    <div
      className="fixed inset-0 z-50 flex items-end justify-center sm:items-center"
      role="dialog"
      aria-modal="true"
      aria-label={title}
    >
      <button
        aria-label="取消"
        onClick={onCancel}
        className="absolute inset-0 bg-black/30 backdrop-blur-[2px]"
      />
      <div
        className="tdd-rise relative m-3 w-full max-w-md rounded-[28px] border border-[var(--border)] bg-[var(--surface)] p-6 shadow-[var(--shadow-card)]"
        style={{ paddingBottom: "calc(env(safe-area-inset-bottom) + 1.5rem)" }}
      >
        <h2 className="text-[18px] font-medium text-[var(--text)]">{title}</h2>
        {body && (
          <p className="mt-2 text-[14px] leading-relaxed text-[var(--text-secondary)]">{body}</p>
        )}
        <div className="mt-5 flex flex-col gap-2">
          <SoftButton full variant="primary" onClick={onConfirm}>
            {confirmLabel}
          </SoftButton>
          <button
            ref={cancelRef}
            onClick={onCancel}
            className="rounded-full px-6 py-3 text-[15px] text-[var(--text-secondary)] transition-colors hover:bg-[var(--surface-soft)]"
          >
            {cancelLabel}
          </button>
        </div>
      </div>
    </div>
  );
}
