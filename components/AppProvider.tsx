"use client";

import { useEffect } from "react";
import { useStore } from "@/lib/store";

/** Hydrates the store from localStorage and keeps <html data-theme> in sync. */
export default function AppProvider({ children }: { children: React.ReactNode }) {
  const hydrate = useStore((s) => s.hydrate);
  const hydrated = useStore((s) => s.hydrated);
  const theme = useStore((s) => s.settings.theme);

  useEffect(() => {
    hydrate();
  }, [hydrate]);

  useEffect(() => {
    if (!hydrated) return;
    document.documentElement.setAttribute("data-theme", theme);
  }, [theme, hydrated]);

  return <>{children}</>;
}
