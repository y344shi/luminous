import { describe, it, expect, beforeEach, vi } from "vitest";
import { render, screen, fireEvent, cleanup } from "@testing-library/react";
import { useStore } from "@/lib/store";
import { buildTrace } from "@/lib/traceGenerator";
import { materializeSeed, mockSeeds } from "@/lib/mockSeeds";
import { copy } from "@/lib/copy";

vi.mock("next/navigation", () => ({
  useRouter: () => ({ push: vi.fn() }),
  usePathname: () => "/traces",
}));

import TraceJournal from "@/components/trace/TraceJournal";

beforeEach(() => {
  window.localStorage.clear();
  const t = buildTrace(materializeSeed(mockSeeds[0]), "completed");
  useStore.setState({ traces: [t], hydrated: true });
});

describe("trace delete (gentle)", () => {
  it("opens a soft confirm and removes the trace only on confirm", () => {
    render(<TraceJournal />);
    expect(useStore.getState().traces.length).toBe(1);

    fireEvent.click(screen.getByLabelText(copy.traces.deleteAria));
    expect(screen.getByText(copy.traces.deleteTitle)).toBeTruthy();

    fireEvent.click(screen.getByText(copy.traces.deleteYes));
    expect(useStore.getState().traces.length).toBe(0);
    cleanup();
  });

  it("cancel keeps the trace", () => {
    render(<TraceJournal />);
    fireEvent.click(screen.getByLabelText(copy.traces.deleteAria));
    fireEvent.click(screen.getByText(copy.traces.deleteNo));
    expect(useStore.getState().traces.length).toBe(1);
    cleanup();
  });
});
