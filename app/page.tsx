import HomeSkin from "@/components/home/HomeSkin";

export default async function HomePage({
  searchParams,
}: {
  searchParams: Promise<{ shot?: string }>;
}) {
  // ?shot=1 → a clean capture (no first-run overlays) for the per-skin gallery.
  const { shot } = await searchParams;
  return <HomeSkin clean={shot === "1"} />;
}
