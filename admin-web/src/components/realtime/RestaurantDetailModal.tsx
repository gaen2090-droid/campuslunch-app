import { useEffect, useState } from "react";
import { Modal } from "../Modal";
import { fetchRecentCrowdReports } from "../../lib/adminApi";
import { errorMessage } from "../../lib/errors";
import type { RecentCrowdReport } from "../../types/restaurant";
import type { Top5RestaurantRow } from "../../types/realtimeMetrics";

interface Props {
  restaurant: Top5RestaurantRow;
  onClose: () => void;
}

export function RestaurantDetailModal({ restaurant, onClose }: Props) {
  const [reports, setReports] = useState<RecentCrowdReport[]>([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);

  useEffect(() => {
    let cancelled = false;
    setLoading(true);
    fetchRecentCrowdReports(restaurant.restaurantId, 20)
      .then((rows) => {
        if (!cancelled) setReports(rows);
      })
      .catch((e) => {
        if (!cancelled) setError(errorMessage(e));
      })
      .finally(() => {
        if (!cancelled) setLoading(false);
      });
    return () => {
      cancelled = true;
    };
  }, [restaurant.restaurantId]);

  const userReports = reports.filter((r) => r.source === "user").length;
  const ownerReports = reports.filter((r) => r.source === "owner").length;

  return (
    <Modal title={restaurant.name} onClose={onClose}>
      <div className="metric-grid">
        <div>
          <p className="metric-label">오늘 제보 수</p>
          <p className="metric-value">{restaurant.todayReports}건</p>
        </div>
        <div>
          <p className="metric-label">최근 7일 제보 수</p>
          <p className="metric-value">{restaurant.weekReports}건</p>
        </div>
        <div>
          <p className="metric-label">오늘 매장 상세 조회 수</p>
          <p className="metric-value">{restaurant.todayDetailViews}건</p>
        </div>
      </div>

      {error && <div className="alert mt-8">{error}</div>}

      <div className="panel-head mt-8">
        <h3>최근 제보 내역 (최대 20건)</h3>
      </div>
      {loading ? (
        <p className="muted center">불러오는 중…</p>
      ) : reports.length === 0 ? (
        <p className="muted center">제보 내역이 없어요.</p>
      ) : (
        <>
          <p className="muted sm">
            사용자 제보 {userReports}건 · 사장님 제보 {ownerReports}건 (최근 {reports.length}건 기준)
          </p>
          <ul className="feedback-list">
            {reports.map((r) => (
              <li key={r.id} className="feedback-row">
                <div className="feedback-row-head">
                  <strong>{r.status}</strong>
                  <span className="muted sm">
                    {r.source === "owner" ? "사장님" : "사용자"} ·{" "}
                    {r.createdAt.toLocaleString("ko-KR", {
                      month: "numeric",
                      day: "numeric",
                      hour: "2-digit",
                      minute: "2-digit",
                    })}
                  </span>
                </div>
              </li>
            ))}
          </ul>
        </>
      )}
    </Modal>
  );
}
