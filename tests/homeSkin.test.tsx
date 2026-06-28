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

  it("glass/ocean render the bubble field (orb link, no notebook list)", () => {
    setSkin("glass");
    render(<HomeSkin clean={false} />);
    expect(screen.getByRole("link", { name: copy.home.primary }).getAttribute("href")).toBe("/now");
    expect(screen.queryByLabelText("也许现在可以做的小事")).toBeNull();
    cleanup();
  });

  it("paper renders the notebook list", () => {
    setSkin("paper");
    render(<HomeSkin clean={false} />);
    expect(screen.getByLabelText("也许现在可以做的小事")).toBeTruthy();
    cleanup();
  });
});
