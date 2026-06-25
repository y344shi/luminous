import PageHeader from "@/components/design/PageHeader";
import AddSeedFlow from "@/components/seed/AddSeedFlow";
import { copy } from "@/lib/copy";

export default function AddPage() {
  return (
    <div className="flex flex-col gap-5">
      <PageHeader title={copy.add.prompt} />
      <AddSeedFlow />
    </div>
  );
}
