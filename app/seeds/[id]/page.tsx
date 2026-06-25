import SeedDetail from "@/components/seed/SeedDetail";

export default async function SeedDetailPage({
  params,
}: {
  params: Promise<{ id: string }>;
}) {
  const { id } = await params;
  return <SeedDetail id={id} />;
}
