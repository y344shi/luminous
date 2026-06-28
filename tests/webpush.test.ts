import { describe, it, expect, afterEach, vi } from "vitest";
import { urlBase64ToUint8Array, getVapidPublicKey } from "@/lib/webpush";

afterEach(() => {
  vi.unstubAllEnvs();
});

describe("webpush", () => {
  it("decodes a base64url VAPID key to the right byte length", () => {
    // A 65-byte uncompressed P-256 public key is the usual VAPID shape.
    const b64url = Buffer.from(new Uint8Array(65).fill(7)).toString("base64")
      .replace(/\+/g, "-").replace(/\//g, "_").replace(/=+$/, "");
    const bytes = urlBase64ToUint8Array(b64url);
    expect(bytes).toBeInstanceOf(Uint8Array);
    expect(bytes.length).toBe(65);
    expect(bytes[0]).toBe(7);
  });

  it("round-trips simple bytes through base64url", () => {
    const b64url = Buffer.from([1, 2, 3, 250, 0]).toString("base64")
      .replace(/\+/g, "-").replace(/\//g, "_").replace(/=+$/, "");
    expect(Array.from(urlBase64ToUint8Array(b64url))).toEqual([1, 2, 3, 250, 0]);
  });

  it("getVapidPublicKey is undefined unless configured", () => {
    vi.stubEnv("NEXT_PUBLIC_VAPID_PUBLIC_KEY", "");
    expect(getVapidPublicKey()).toBeUndefined();
    vi.stubEnv("NEXT_PUBLIC_VAPID_PUBLIC_KEY", "BPexampleKey");
    expect(getVapidPublicKey()).toBe("BPexampleKey");
  });
});
