import PageHeader from "@/components/design/PageHeader";
import TraceJournal from "@/components/trace/TraceJournal";
import { copy } from "@/lib/copy";

export default function TracesPage() {
  return (
    <div className="flex flex-col gap-5">
      <PageHeader title={copy.traces.title} subtitle={copy.traces.subtitle} />
      <TraceJournal />
    </div>
  );
}
