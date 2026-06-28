import { describe, it, expect, beforeEach, vi } from "vitest";
import { render, screen, fireEvent, cleanup } from "@testing-library/react";
import { useStore } from "@/lib/store";
import { seedMockGarden } from "@/lib/mockSeeds";
import { copy } from "@/lib/copy";
import BubbleField from "@/components/home/shared/BubbleField";

vi.mock("next/navigation", () => ({
  useRouter: () => ({ push: vi.fn() }),
  usePathname: () => "/",
}));

beforeEach(() => {
  window.localStorage.clear();
  useStore.setState({ seeds: seedMockGarden(), traces: [], hydrated: true, lastPick: {} });
});

describe("BubbleField (dreamy physics home)", () => {
  it("renders the central orb (→/now) and floating wish bubbles", () => {
    render(<BubbleField />);
    const orb = screen.getByLabelText("现在别消失");
    expect(orb.getAttribute("href")).toBe("/now");
    // at least one wish bubble (button labelled by a mock-garden title)
    const titles = ["记 3 个法语单词", "亲手理解一个模块", "夺回一点方向盘", "坐一会野外", "吃一顿热饭"];
    expect(titles.some((t) => screen.queryByRole("button", { name: t }))).toBe(true);
    cleanup();
  });

  it("tapping a bubble opens the do-it sheet and completing writes a trace", () => {
    render(<BubbleField />);
    const titles = ["记 3 个法语单词", "亲手理解一个模块", "夺回一点方向盘", "坐一会野外", "吃一顿热饭", "给一个人发一句真话", "去市中心走走", "深夜止损"];
    const bubble = titles.map((t) => screen.queryByRole("button", { name: t })).find(Boolean);
    expect(bubble).toBeTruthy();
    fireEvent.click(bubble!);
    fireEvent.click(screen.getByText(copy.completion.done));
    expect(useStore.getState().traces.length).toBe(1);
    cleanup();
  });
});
