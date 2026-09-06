import type { AdminRestaurant } from "../types/restaurant";

interface Props {
  restaurants: AdminRestaurant[];
  countById: Record<string, number>;
  total: number;
  unit?: string;
}

export function RestaurantBarList({
  restaurants,
  countById,
  total,
  unit = "건",
}: Props) {
  const data = restaurants
    .map((r) => ({ name: r.name, count: countById[r.id] ?? 0 }))
    .sort((a, b) => b.count - a.count);
  const maxV = Math.max(1, ...data.map((d) => d.count));
  const avg =
    restaurants.length > 0
      ? Math.round((total / restaurants.length) * 10) / 10
      : 0;

  return (
    <div className="restaurant-bar-list">
      <div className="avg-pill">
        <span>평균</span>
        <strong>
          {avg}
          {unit}
        </strong>
      </div>
      <ul>
        {data.map((row) => (
          <li key={row.name}>
            <span className="bar-name">{row.name}</span>
            <div className="bar-track-wrap">
              <div className="bar-track">
                <div
                  className="bar-fill"
                  style={{ width: `${(row.count / maxV) * 100}%` }}
                />
              </div>
              <span className="bar-count">{row.count}</span>
            </div>
          </li>
        ))}
      </ul>
    </div>
  );
}
