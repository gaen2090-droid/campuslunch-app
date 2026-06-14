interface Props {
  label: string;
  value: string;
  unit?: string;
}

export function MetricCard({ label, value, unit }: Props) {
  return (
    <div className="metric-card">
      <p className="metric-label">{label}</p>
      <p className="metric-value">
        {value}
        {unit && <span className="metric-unit">{unit}</span>}
      </p>
    </div>
  );
}
