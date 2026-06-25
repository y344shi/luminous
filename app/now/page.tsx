import PageHeader from "@/components/design/PageHeader";
import NowFlow from "@/components/opportunity/NowFlow";
import LateNightThemeOffer from "@/components/design/LateNightThemeOffer";

export default function NowPage() {
  return (
    <div className="flex flex-col gap-5">
      <PageHeader title="现在别消失" subtitle="先告诉我你现在的状态，我帮你看看现在适合做点什么。" />
      <LateNightThemeOffer />
      <NowFlow />
    </div>
  );
}
