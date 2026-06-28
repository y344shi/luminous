import { describe, it, expect, beforeEach, vi } from "vitest";
import { render, screen, fireEvent, cleanup } from "@testing-library/react";
import { useStore } from "@/lib/store";
import { seedMockGarden } from "@/lib/mockSeeds";
import { copy } from "@/lib/copy";
import PaperHome from "@/components/home/PaperHome";

vi.mock("next/navigation", () => ({
  useRouter: () => ({ push: vi.fn() }),
  usePathname: () => "/",
}));

beforeEach(() => {
  window.localStorage.clear();
  useStore.setState({ seeds: seedMockGarden(), traces: [], hydrated: true, lastPick: {} });
});

describe("PaperHome (Calm Ritual aesthetic)", () => {
  it("lays out the wordmark, ambient line, and wish notes (→/now)", () => {
    render(<PaperHome />);
    expect(screen.getByText("今天别消失")).toBeTruthy();
    expect(screen.getByText(/周[一二三四五六日]\s·/)).toBeTruthy();
    expect(screen.getByRole("link", { name: copy.home.primary }).getAttribute("href")).toBe("/now");
    cleanup();
  });

  it("tapping a note opens the sheet and completing writes a trace", () => {
    render(<PaperHome />);
    const titles = ["记 3 个法语单词", "亲手理解一个模块", "夺回一点方向盘", "坐一会野外", "吃一顿热饭", "给一个人发一句真话", "去市中心走走", "深夜止损"];
    const note = titles.map((t) => screen.queryByText(t)).find(Boolean);
    expect(note).toBeTruthy();
    fireEvent.click(note!.closest("button")!);
    fireEvent.click(screen.getByText(copy.completion.done));
    expect(useStore.getState().traces.length).toBe(1);
    cleanup();
  });
});
