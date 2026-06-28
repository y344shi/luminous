import PageHeader from "@/components/design/PageHeader";
import SettingsPanel from "@/components/settings/SettingsPanel";
import { copy } from "@core/copy";

export default function SettingsPage() {
  return (
    <div className="flex flex-col gap-5">
      <PageHeader title={copy.settings.title} />
      <SettingsPanel />
    </div>
  );
}
