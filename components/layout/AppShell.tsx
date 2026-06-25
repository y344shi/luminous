import BottomNav from "./BottomNav";

/** Mobile-first centered column with bottom nav and safe-area padding. */
export default function AppShell({ children }: { children: React.ReactNode }) {
  return (
    <div className="min-h-dvh bg-[var(--bg)]">
      <main
        className="mx-auto flex w-full max-w-md flex-col gap-5 px-5 pb-28 pt-8"
        style={{ paddingTop: "calc(env(safe-area-inset-top) + 2rem)" }}
      >
        {children}
      </main>
      <BottomNav />
    </div>
  );
}
