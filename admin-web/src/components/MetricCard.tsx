interface Props {
  label: string;
  value: string;
  unit?: string;
  onClick?: () => void;
  size?: "primary" | "secondary";
}

export function MetricCard({
  label,
  value,
  unit,
  onClick,
  size = "secondary",
}: Props) {
  const Tag = onClick ? "button" : "div";
  return (
    <Tag
      type={onClick ? "button" : undefined}
      className={`metric-card metric-card--${size}${onClick ? " clickable" : ""}`}
      onClick={onClick}
    >
      <p className="metric-label">{label}</p>
      <p className="metric-value">
        {value}
        {unit && <span className="metric-unit">{unit}</span>}
      </p>
    </Tag>
  );
}
