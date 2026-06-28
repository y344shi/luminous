import { describe, it, expect, beforeEach, vi } from "vitest";
import { render, screen, fireEvent, cleanup } from "@testing-library/react";
import { useStore } from "@/lib/store";
import { seedMockGarden } from "@core/mockSeeds";
import { copy } from "@core/copy";

vi.mock("next/navigation", () => ({
  useRouter: () => ({ push: vi.fn() }),
  usePathname: () => "/settings",
}));

import SettingsPanel from "@/components/settings/SettingsPanel";

beforeEach(() => {
  window.localStorage.clear();
  useStore.setState({ seeds: seedMockGarden(), traces: [], hydrated: true });
});

describe("in-app soft confirm (reset)", () => {
  it("does not reset until confirmed; cancel keeps data", () => {
    render(<SettingsPanel />);
    const before = useStore.getState().seeds.length;
    expect(before).toBeGreaterThan(0);

    // open sheet
    fireEvent.click(screen.getByRole("button", { name: "清空本地数据" }));
    expect(screen.getByText(copy.settings.resetConfirmTitle)).toBeTruthy();

    // cancel → unchanged
    fireEvent.click(screen.getByText(copy.settings.resetConfirmNo));
    expect(useStore.getState().seeds.length).toBe(before);
    cleanup();
  });

  it("confirming clears traces and replants the garden", () => {
    useStore.setState({ traces: [{ id: "t1", date: "2026-06-25", text: "x", createdAt: "" }] });
    render(<SettingsPanel />);

    fireEvent.click(screen.getByRole("button", { name: "清空本地数据" }));
    fireEvent.click(screen.getByText(copy.settings.resetConfirmYes));

    // resetAll wipes traces; garden is replanted (non-empty)
    expect(useStore.getState().traces.length).toBe(0);
    expect(useStore.getState().seeds.length).toBeGreaterThan(0);
    cleanup();
  });

  it("does not use the native window.confirm", () => {
    const spy = vi.spyOn(window, "confirm");
    render(<SettingsPanel />);
    fireEvent.click(screen.getByRole("button", { name: "清空本地数据" }));
    expect(spy).not.toHaveBeenCalled();
    spy.mockRestore();
    cleanup();
  });
});
