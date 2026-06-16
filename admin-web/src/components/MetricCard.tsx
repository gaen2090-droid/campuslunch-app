interface Props {
  label: string;
  value: string;
  unit?: string;
  onClick?: () => void;
}

export function MetricCard({ label, value, unit, onClick }: Props) {
  const Tag = onClick ? "button" : "div";
  return (
    <Tag
      type={onClick ? "button" : undefined}
      className={`metric-card${onClick ? " clickable" : ""}`}
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
