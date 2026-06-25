import { describe, it, expect, beforeEach, afterEach, vi } from "vitest";
import { render, screen, cleanup } from "@testing-library/react";
import { useStore } from "@/lib/store";
import { copy } from "@/lib/copy";

vi.mock("next/navigation", () => ({
  useRouter: () => ({ push: vi.fn() }),
  usePathname: () => "/now",
}));

import NowPage from "@/app/now/page";

beforeEach(() => {
  window.localStorage.clear();
  useStore.setState({
    seeds: [],
    traces: [],
    hydrated: true,
    settings: { ...useStore.getState().settings, theme: "warm_paper" },
  });
  vi.useFakeTimers();
});

afterEach(() => {
  vi.useRealTimers();
  cleanup();
});

describe("late-night theme offer on /now", () => {
  it("appears at 2am when theme isn't already soft_ritual", () => {
    vi.setSystemTime(new Date(2026, 5, 25, 2, 0, 0));
    render(<NowPage />);
    expect(screen.queryByText(copy.lateNight.themeOffer)).not.toBeNull();
  });

  it("does not appear in the afternoon", () => {
    vi.setSystemTime(new Date(2026, 5, 25, 15, 0, 0));
    render(<NowPage />);
    expect(screen.queryByText(copy.lateNight.themeOffer)).toBeNull();
  });
});
