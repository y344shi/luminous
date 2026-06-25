import { cx } from "@/lib/utils";

type Props = React.HTMLAttributes<HTMLDivElement> & {
  soft?: boolean;
  rise?: boolean;
};

/** The base surface of the app: a soft, rounded, low-shadow card. */
export default function BreathingCard({
  soft,
  rise,
  className,
  children,
  ...rest
}: Props) {
  return (
    <div
      className={cx(
        "rounded-[24px] border border-[var(--border)] p-5",
        soft ? "bg-[var(--surface-soft)]" : "bg-[var(--surface)]",
        "shadow-[var(--shadow-card)]",
        rise && "tdd-rise",
        className
      )}
      {...rest}
    >
      {children}
    </div>
  );
}
