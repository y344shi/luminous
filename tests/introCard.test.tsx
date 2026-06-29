import { describe, it, expect, beforeEach, vi } from "vitest";
import { render, screen, fireEvent, cleanup } from "@testing-library/react";
import { useStore } from "@/lib/store";
import { copy } from "@core/copy";
import IntroCard from "@/components/IntroCard";

beforeEach(() => {
  window.localStorage.clear();
  useStore.setState({ hydrated: true, introSeen: false });
});

describe("first-open intro card", () => {
  it("shows for a new user and disappears after 开始吧", () => {
    render(<IntroCard />);
    expect(screen.getByText(copy.intro.cta)).toBeTruthy();

    fireEvent.click(screen.getByText(copy.intro.cta));
    expect(screen.queryByText(copy.intro.cta)).toBeNull();
    expect(useStore.getState().introSeen).toBe(true);
    cleanup();
  });

  it("does not show once seen", () => {
    useStore.setState({ introSeen: true });
    render(<IntroCard />);
    expect(screen.queryByText(copy.intro.cta)).toBeNull();
    cleanup();
  });
});
