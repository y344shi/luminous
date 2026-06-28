import { describe, it, expect, beforeEach, vi } from "vitest";
import { render, screen, cleanup } from "@testing-library/react";
import { useStore } from "@/lib/store";
import { defaultSettings } from "@/lib/storage";
import { seedMockGarden } from "@/lib/mockSeeds";
import { copy } from "@/lib/copy";
import HomeSkin from "@/components/home/HomeSkin";

vi.mock("next/navigation", () => ({
  useRouter: () => ({ push: vi.fn() }),
  usePathname: () => "/",
}));

function setSkin(aesthetic: "glass" | "ocean" | "paper") {
  useStore.setState({
    seeds: seedMockGarden(),
    traces: [],
    hydrated: true,
    lastPick: {},
    settings: { ...defaultSettings, aesthetic },
  });
}

beforeEach(() => {
  window.localStorage.clear();
});

describe("HomeSkin — runtime skin switch", () => {
  it("default aesthetic is a valid skin", () => {
    expect(["glass", "ocean", "paper"]).toContain(defaultSettings.aesthetic);
  });

  it("glass/ocean render the bubble field (no notebook list)", () => {
    setSkin("glass");
    render(<HomeSkin clean={false} />);
    expect(screen.getAllByText(copy.home.navFind).length).toBeGreaterThan(0);
    expect(screen.queryByLabelText("也许现在可以做的小事")).toBeNull();
    cleanup();
  });

  it("paper renders the notebook list — and the geo search is in every skin", () => {
    setSkin("paper");
    render(<HomeSkin clean={false} />);
    expect(screen.getByLabelText("也许现在可以做的小事")).toBeTruthy();
    expect(screen.getAllByText(copy.home.navFind).length).toBeGreaterThan(0);
    cleanup();
  });
});
