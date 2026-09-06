import {
  Bar,
  BarChart,
  CartesianGrid,
  Line,
  LineChart,
  ResponsiveContainer,
  Tooltip,
  XAxis,
  YAxis,
} from "recharts";

interface Props {
  title: string;
  labels: string[];
  values: number[];
  kind?: "line" | "bar";
  suffix?: string;
  hideTitle?: boolean;
}

export function TrendChart({
  title,
  labels,
  values,
  kind = "line",
  suffix = "",
  hideTitle = false,
}: Props) {
  const data = labels.map((label, i) => ({
    label,
    value: values[i] ?? 0,
  }));

  return (
    <section className={`panel chart-panel${hideTitle ? " no-title" : ""}`}>
      {!hideTitle && <h2>{title}</h2>}
      <div className="chart-wrap">
        <ResponsiveContainer width="100%" height={220}>
          {kind === "bar" ? (
            <BarChart data={data}>
              <CartesianGrid strokeDasharray="3 3" stroke="#e5e7eb" />
              <XAxis dataKey="label" tick={{ fontSize: 12 }} />
              <YAxis tick={{ fontSize: 12 }} />
              <Tooltip formatter={(v) => [`${v}${suffix}`, ""]} />
              <Bar dataKey="value" fill="#26BC7D" radius={[6, 6, 0, 0]} />
            </BarChart>
          ) : (
            <LineChart data={data}>
              <CartesianGrid strokeDasharray="3 3" stroke="#e5e7eb" />
              <XAxis dataKey="label" tick={{ fontSize: 12 }} />
              <YAxis tick={{ fontSize: 12 }} />
              <Tooltip formatter={(v) => [`${v}${suffix}`, ""]} />
              <Line
                type="monotone"
                dataKey="value"
                stroke="#26BC7D"
                strokeWidth={3}
                dot={{ r: 4, fill: "#26BC7D" }}
              />
            </LineChart>
          )}
        </ResponsiveContainer>
      </div>
    </section>
  );
}
