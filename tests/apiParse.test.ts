import { describe, it, expect } from "vitest";
import { POST } from "@/app/api/seeds/parse/route";

function post(body: unknown) {
  return new Request("http://localhost/api/seeds/parse", {
    method: "POST",
    headers: { "content-type": "application/json" },
    body: typeof body === "string" ? body : JSON.stringify(body),
  });
}

describe("POST /api/seeds/parse", () => {
  it("returns a small SeedDraft for a wish", async () => {
    const res = await POST(post({ text: "我想找个天气好的时候坐一会野外" }));
    expect(res.status).toBe(200);
    const data = await res.json();
    expect(data.draft.title.length).toBeGreaterThan(0);
    expect(data.draft.categories).toContain("recovery");
    expect(data.draft.minimumAction.length).toBeLessThan(30);
    expect(["mock", "ai"]).toContain(data.source); // no key in test env → mock
  });

  it("rejects empty text with 400", async () => {
    const res = await POST(post({ text: "   " }));
    expect(res.status).toBe(400);
  });

  it("rejects invalid JSON with 400", async () => {
    const res = await POST(post("{not json"));
    expect(res.status).toBe(400);
  });

  it("rejects over-long text with 413 (coarse-input guard)", async () => {
    const res = await POST(post({ text: "x".repeat(501) }));
    expect(res.status).toBe(413);
  });
});
