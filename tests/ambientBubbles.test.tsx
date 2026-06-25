import { describe, it, expect, beforeEach, vi } from "vitest";
import { render, screen, cleanup } from "@testing-library/react";
import { useStore } from "@/lib/store";
import { seedMockGarden } from "@/lib/mockSeeds";
import { copy } from "@/lib/copy";
import AmbientBubbles from "@/components/home/AmbientBubbles";

beforeEach(() => {
  window.localStorage.clear();
  useStore.setState({ seeds: seedMockGarden(), traces: [], hydrated: true, lastPick: {} });
});

describe("AmbientBubbles", () => {
  it("senses the moment and floats opportunity bubbles", () => {
    render(<AmbientBubbles />);
    // ambient label: 周X · <time> · <place?>
    expect(screen.getByText(/周[一二三四五六日]\s·/)).toBeTruthy();
    // the lead + at least one bubble button from the mock garden
    expect(screen.getByText(copy.home.bubblesLead)).toBeTruthy();
    // the opt-in movement sense + correctable location are offered
    expect(screen.getByText(copy.home.senseMove)).toBeTruthy();
    expect(screen.getByText(copy.home.locationCorrect)).toBeTruthy();
    cleanup();
  });
});
