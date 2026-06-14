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
}

export function TrendChart({
  title,
  labels,
  values,
  kind = "line",
  suffix = "",
}: Props) {
  const data = labels.map((label, i) => ({
    label,
    value: values[i] ?? 0,
  }));

  return (
    <section className="panel chart-panel">
      <h2>{title}</h2>
      <div className="chart-wrap">
        <ResponsiveContainer width="100%" height={220}>
          {kind === "bar" ? (
            <BarChart data={data}>
              <CartesianGrid strokeDasharray="3 3" stroke="#e5e7eb" />
              <XAxis dataKey="label" tick={{ fontSize: 12 }} />
              <YAxis tick={{ fontSize: 12 }} />
              <Tooltip formatter={(v) => [`${v}${suffix}`, ""]} />
              <Bar dataKey="value" fill="#16a34a" radius={[6, 6, 0, 0]} />
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
                stroke="#16a34a"
                strokeWidth={3}
                dot={{ r: 4, fill: "#16a34a" }}
              />
            </LineChart>
          )}
        </ResponsiveContainer>
      </div>
    </section>
  );
}
