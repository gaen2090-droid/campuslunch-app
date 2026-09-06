import { useState } from "react";
import { Modal } from "../Modal";
import { RestaurantDetailModal } from "./RestaurantDetailModal";
import { levelToLabel } from "../../lib/metrics";
import type { Top5RestaurantRow } from "../../types/realtimeMetrics";

interface Props {
  rows: Top5RestaurantRow[];
  onClose: () => void;
}

export function Top10RestaurantsModal({ rows, onClose }: Props) {
  const [selected, setSelected] = useState<Top5RestaurantRow | null>(null);

  return (
    <>
      <Modal title="오늘 제보 많은 매장 TOP 10" onClose={onClose} wide>
        {rows.length === 0 ? (
          <p className="muted center">오늘 제보가 없어요.</p>
        ) : (
          <div className="table-wrap">
            <table className="data-table">
              <thead>
                <tr>
                  <th>순위</th>
                  <th>매장명</th>
                  <th>오늘 제보</th>
                  <th>최근 7일</th>
                  <th>현재 혼잡도</th>
                  <th>마지막 제보</th>
                  <th>오늘 조회수</th>
                </tr>
              </thead>
              <tbody>
                {rows.map((r, i) => (
                  <tr
                    key={r.restaurantId}
                    className="clickable-row"
                    onClick={() => setSelected(r)}
                  >
                    <td>{i + 1}</td>
                    <td>{r.name}</td>
                    <td>{r.todayReports}건</td>
                    <td>{r.weekReports}건</td>
                    <td>{levelToLabel(r.currentLevel)}</td>
                    <td>
                      {r.lastReportAt
                        ? r.lastReportAt.toLocaleString("ko-KR", {
                            month: "numeric",
                            day: "numeric",
                            hour: "2-digit",
                            minute: "2-digit",
                          })
                        : "-"}
                    </td>
                    <td>{r.todayDetailViews}건</td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
        )}
      </Modal>

      {selected && (
        <RestaurantDetailModal restaurant={selected} onClose={() => setSelected(null)} />
      )}
    </>
  );
}
