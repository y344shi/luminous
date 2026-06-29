import { describe, it, expect } from "vitest";
import { friendlyDate } from "@core/utils";

const today = new Date(2026, 5, 25); // 2026-06-25 (local)

describe("friendlyDate", () => {
  it("labels today / yesterday / day-before", () => {
    expect(friendlyDate("2026-06-25", today)).toBe("今天");
    expect(friendlyDate("2026-06-24", today)).toBe("昨天");
    expect(friendlyDate("2026-06-23", today)).toBe("前天");
  });

  it("uses M月D日 for older dates in the same year", () => {
    expect(friendlyDate("2026-06-20", today)).toBe("6月20日");
    expect(friendlyDate("2026-01-03", today)).toBe("1月3日");
  });

  it("includes the year when it differs from today", () => {
    expect(friendlyDate("2025-12-31", today)).toBe("2025年12月31日");
  });

  it("does not call a future date 今天", () => {
    expect(friendlyDate("2026-06-26", today)).toBe("6月26日");
  });

  it("returns the raw string for malformed input", () => {
    expect(friendlyDate("not-a-date", today)).toBe("not-a-date");
  });
});
