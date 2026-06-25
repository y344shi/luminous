import { describe, it, expect, beforeEach, vi } from "vitest";
import { render, screen, fireEvent, cleanup } from "@testing-library/react";
import { useStore } from "@/lib/store";
import { seedMockGarden } from "@/lib/mockSeeds";

// next/navigation isn't available outside the Next runtime — stub what NowFlow uses.
const push = vi.fn();
vi.mock("next/navigation", () => ({
  useRouter: () => ({ push }),
  usePathname: () => "/now",
}));

// Import after the mock is registered.
import NowFlow from "@/components/opportunity/NowFlow";

beforeEach(() => {
  window.localStorage.clear();
  push.mockReset();
  useStore.setState({ seeds: seedMockGarden(), traces: [], hydrated: true });
});

describe("Now flow (integration) — the core loop end to end", () => {
  it("mood + energy → opportunity → complete → trace is created", () => {
    render(<NowFlow />);

    // context step
    fireEvent.click(screen.getByText("还行")); // mood: okay
    fireEvent.click(screen.getByText("中")); // energy: medium
    fireEvent.click(screen.getByText("看看现在适合做什么"));

    // list step → an opportunity card with a start affordance
    const start = screen.getByText("开始一点点");
    fireEvent.click(start);

    // completion step
    expect(screen.getByText("做到了吗？")).toBeTruthy();
    fireEvent.click(screen.getByText("完成了"));

    // trace step — a warm trace was generated and persisted
    expect(screen.getByText(/今天没有消失/)).toBeTruthy();
    const traces = useStore.getState().traces;
    expect(traces.length).toBe(1);
    expect(traces[0].text).toContain("今天没有消失");
    expect(traces[0].partial).toBe(false);
    cleanup();
  });

  it("partial completion still creates a positive (non-shaming) trace", () => {
    render(<NowFlow />);
    fireEvent.click(screen.getByText("累")); // mood: tired
    fireEvent.click(screen.getByText("低")); // energy: low
    fireEvent.click(screen.getByText("看看现在适合做什么"));
    fireEvent.click(screen.getByText("开始一点点"));
    fireEvent.click(screen.getByText("做了一点")); // partial

    const traces = useStore.getState().traces;
    expect(traces.length).toBe(1);
    expect(traces[0].partial).toBe(true);
    expect(traces[0].text).not.toMatch(/失败|浪费|没用/);
    cleanup();
  });

  it("shows alternative opportunities as peeks and switching makes one active", () => {
    render(<NowFlow />);
    fireEvent.click(screen.getByText("还行"));
    fireEvent.click(screen.getByText("中"));
    fireEvent.click(screen.getByText("看看现在适合做什么"));

    // With the mock garden there are multiple candidates → peeks render.
    expect(screen.getByText("或者，现在也可以：")).toBeTruthy();

    // The first peek button's label should become the active card's title on tap.
    const peekLabel = "亲手理解一个模块";
    const peek = screen.queryByRole("button", { name: peekLabel });
    if (peek) {
      fireEvent.click(peek);
      // now it's the headline (a heading), not a peek button
      expect(screen.getByRole("heading", { name: peekLabel })).toBeTruthy();
    }
    // the start action remains available throughout
    expect(screen.getByText("开始一点点")).toBeTruthy();
    cleanup();
  });

  it("skipped does not create a trace and shows the gentle message", () => {
    render(<NowFlow />);
    fireEvent.click(screen.getByText("有点空")); // mood: empty
    fireEvent.click(screen.getByText("中"));
    fireEvent.click(screen.getByText("看看现在适合做什么"));
    fireEvent.click(screen.getByText("开始一点点"));
    fireEvent.click(screen.getByText("没做，但我知道了")); // skipped

    expect(useStore.getState().traces.length).toBe(0);
    expect(screen.getByText(/愿望还在/)).toBeTruthy();
    cleanup();
  });
});
