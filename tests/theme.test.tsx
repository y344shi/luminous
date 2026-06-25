import { describe, it, expect, beforeEach } from "vitest";
import { render, act, cleanup, waitFor } from "@testing-library/react";
import AppProvider from "@/components/AppProvider";
import { useStore } from "@/lib/store";
import { storage, defaultSettings } from "@/lib/storage";

beforeEach(() => {
  window.localStorage.clear();
  document.documentElement.removeAttribute("data-theme");
  useStore.setState({ hydrated: false, settings: { ...defaultSettings }, seeds: [], traces: [] });
});

describe("theme — applied to <html> and persisted", () => {
  it("AppProvider sets data-theme on the document element after hydration", async () => {
    render(
      <AppProvider>
        <div>child</div>
      </AppProvider>
    );
    await waitFor(() =>
      expect(document.documentElement.getAttribute("data-theme")).toBe("warm_paper")
    );
    cleanup();
  });

  it("changing the theme updates <html data-theme> and writes to storage", async () => {
    render(
      <AppProvider>
        <div>child</div>
      </AppProvider>
    );
    await waitFor(() => expect(useStore.getState().hydrated).toBe(true));

    act(() => {
      useStore.getState().setTheme("soft_ritual");
    });

    await waitFor(() =>
      expect(document.documentElement.getAttribute("data-theme")).toBe("soft_ritual")
    );
    expect(storage.loadTheme()).toBe("soft_ritual");
    expect(storage.loadSettings().theme).toBe("soft_ritual");
    cleanup();
  });

  it("a persisted theme is restored on hydrate", async () => {
    storage.saveTheme("field_notebook");
    render(
      <AppProvider>
        <div>child</div>
      </AppProvider>
    );
    await waitFor(() =>
      expect(document.documentElement.getAttribute("data-theme")).toBe("field_notebook")
    );
    expect(useStore.getState().settings.theme).toBe("field_notebook");
    cleanup();
  });
});
