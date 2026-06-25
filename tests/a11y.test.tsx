import { describe, it, expect, beforeEach, vi } from "vitest";
import { render, screen, fireEvent, cleanup } from "@testing-library/react";
import { useStore } from "@/lib/store";
import { seedMockGarden } from "@/lib/mockSeeds";

vi.mock("next/navigation", () => ({
  useRouter: () => ({ push: vi.fn() }),
  usePathname: () => "/now",
}));

import NowFlow from "@/components/opportunity/NowFlow";
import SettingsPanel from "@/components/settings/SettingsPanel";

beforeEach(() => {
  window.localStorage.clear();
  useStore.setState({ seeds: seedMockGarden(), traces: [], hydrated: true });
});

describe("accessibility", () => {
  it("mood chips expose selection state via aria-pressed", () => {
    render(<NowFlow />);
    const chip = screen.getByRole("button", { name: "还行" });
    expect(chip.getAttribute("aria-pressed")).toBe("false");
    fireEvent.click(chip);
    expect(chip.getAttribute("aria-pressed")).toBe("true");
    cleanup();
  });

  it("icon-only reminder steppers have accessible names", () => {
    render(<SettingsPanel />);
    expect(screen.getByLabelText("增加每天契机次数")).toBeTruthy();
    expect(screen.getByLabelText("减少每天契机次数")).toBeTruthy();
    cleanup();
  });

  it("the AI-mode toggle has an accessible label", () => {
    render(<SettingsPanel />);
    expect(screen.getByLabelText("切换 AI 模式")).toBeTruthy();
    cleanup();
  });
});
