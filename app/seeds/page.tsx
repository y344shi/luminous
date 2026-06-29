import Link from "next/link";
import PageHeader from "@/components/design/PageHeader";
import SeedGarden from "@/components/seed/SeedGarden";
import GardenNote from "@/components/seed/GardenNote";
import SoftButton from "@/components/design/SoftButton";
import { copy } from "@core/copy";

export default function SeedsPage() {
  return (
    <div className="flex flex-col gap-5">
      <PageHeader title={copy.garden.title} subtitle={copy.garden.subtitle} />
      <GardenNote />
      <SeedGarden />
      <Link href="/add" className="block">
        <SoftButton full variant="soft">
          + 丢一个新愿望进来
        </SoftButton>
      </Link>
    </div>
  );
}
