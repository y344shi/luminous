import { describe, it, expect, beforeEach, vi } from "vitest";
import { render, screen, fireEvent, cleanup } from "@testing-library/react";
import { useStore } from "@/lib/store";
import { seedMockGarden } from "@/lib/mockSeeds";
import AmbientOrbit from "@/components/home/AmbientOrbit";

vi.mock("next/navigation", () => ({
  useRouter: () => ({ push: vi.fn() }),
  usePathname: () => "/",
}));

beforeEach(() => {
  window.localStorage.clear();
  useStore.setState({ seeds: seedMockGarden(), traces: [], hydrated: true, lastPick: {} });
});

describe("AmbientOrbit (minimal circular Home)", () => {
  it("shows a centre action and the ambient line, with orbiting bubbles", () => {
    render(<AmbientOrbit />);
    // centre link → /now
    const centre = screen.getByLabelText("现在别消失");
    expect(centre.getAttribute("href")).toBe("/now");
    // ambient line (周X · …)
    expect(screen.getByText(/周[一二三四五六日]\s·/)).toBeTruthy();
    // an add affordance
    expect(screen.getByLabelText("接住一个新愿望")).toBeTruthy();
    cleanup();
  });

  it("tapping a bubble opens the do-it sheet and completing writes a trace", () => {
    render(<AmbientOrbit />);
    // bubbles are buttons labelled by their seed title; grab the first mock-garden one present
    const candidate = ["记 3 个法语单词", "亲手理解一个模块", "夺回一点方向盘", "给一个人发一句真话", "坐一会野外", "深夜止损", "吃一顿热饭", "去市中心走走"]
      .map((t) => screen.queryByRole("button", { name: t }))
      .find(Boolean);
    expect(candidate).toBeTruthy();
    fireEvent.click(candidate!);
    fireEvent.click(screen.getByText("完成了"));
    expect(useStore.getState().traces.length).toBe(1);
    cleanup();
  });
});
