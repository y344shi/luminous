import PageHeader from "@/components/design/PageHeader";
import TraceJournal from "@/components/trace/TraceJournal";
import TraceExport from "@/components/trace/TraceExport";
import KeepsakeButton from "@/components/trace/KeepsakeButton";
import { copy } from "@core/copy";

export default function TracesPage() {
  return (
    <div className="flex flex-col gap-5">
      <PageHeader title={copy.traces.title} subtitle={copy.traces.subtitle} />
      <TraceJournal />
      <div className="flex flex-col items-center gap-2">
        <KeepsakeButton />
        <TraceExport />
      </div>
    </div>
  );
}
