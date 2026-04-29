type ClickyLogoProps = {
  className?: string;
  markClassName?: string;
  showWordmark?: boolean;
  wordmarkClassName?: string;
};

export function ClickyLogo({
  className = '',
  markClassName = 'h-8 w-8',
  showWordmark = true,
  wordmarkClassName = 'text-xl font-semibold tracking-tight text-charcoal',
}: ClickyLogoProps) {
  return (
    <span className={`inline-flex items-center gap-2.5 ${className}`}>
      <img
        src="/clicky-logo.svg"
        alt=""
        aria-hidden="true"
        className={`${markClassName} shrink-0 rounded-[10px] bg-transparent`}
        draggable={false}
      />
      {showWordmark ? (
        <span className={wordmarkClassName}>Clicky</span>
      ) : null}
    </span>
  );
}

export default ClickyLogo;
