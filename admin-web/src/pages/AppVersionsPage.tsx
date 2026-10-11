import { useMemo } from "react";
import { MetricCard } from "../components/MetricCard";
import {
  PLATFORM_LABEL,
  compareVersionDesc,
  type AppPlatform,
  type AppVersionStat,
} from "../types/appVersion";

interface Props {
  stats: AppVersionStat[];
  loading: boolean;
  error: string | null;
  onReload: () => void;
}

const PLATFORMS: AppPlatform[] = ["android", "ios"];

function percent(part: number, total: number): string {
  if (total === 0) return "0%";
  return `${Math.round((part / total) * 1000) / 10}%`;
}

export function AppVersionsPage({ stats, loading, error, onReload }: Props) {
  const summary = useMemo(() => {
    const byPlatform: Record<AppPlatform, number> = { ios: 0, android: 0, unknown: 0 };
    for (const s of stats) byPlatform[s.platform] += s.userCount;
    const total = byPlatform.ios + byPlatform.android + byPlatform.unknown;
    return { byPlatform, total, known: byPlatform.ios + byPlatform.android };
  }, [stats]);

  // 버전 하나당 한 줄: 전체 인원 + 플랫폼별 인원. 최신 버전이 위, 미확인은 맨 아래.
  const rows = useMemo(() => {
    const byVersion = new Map<
      string | null,
      { version: string | null; total: number; android: number; ios: number }
    >();
    for (const s of stats) {
      const row = byVersion.get(s.appVersion) ?? {
        version: s.appVersion,
        total: 0,
        android: 0,
        ios: 0,
      };
      row.total += s.userCount;
      if (s.platform === "android") row.android += s.userCount;
      if (s.platform === "ios") row.ios += s.userCount;
      byVersion.set(s.appVersion, row);
    }
    return [...byVersion.values()].sort((a, b) =>
      compareVersionDesc(a.version, b.version),
    );
  }, [stats]);

  if (error) {
    return <div className="alert">{error}</div>;
  }

  return (
    <div className="dashboard">
      <section className="panel">
        <div className="panel-head">
          <h2>앱 버전 현황</h2>
          <button type="button" className="btn outline sm" onClick={onReload} disabled={loading}>
            새로고침
          </button>
        </div>
        <p className="muted">
          가입자 전체 기준입니다(통계 제외 계정은 제외). 앱이 마지막으로 보고한
          버전을 집계하며, 버전 보고 기능이 들어간 빌드를 아직 쓰지 않은
          사용자는 &quot;미확인&quot;으로 표시됩니다. 사용자가 앱을 열 때마다
          갱신되므로 시간이 지날수록 정확해집니다.
        </p>
      </section>

      <section className="panel">
        <div className="panel-head">
          <h2>플랫폼별</h2>
        </div>
        <div className="metric-grid">
          <MetricCard
            label="전체 가입자"
            value={summary.total.toLocaleString("ko-KR")}
            unit="명"
          />
          {PLATFORMS.map((p) => (
            <MetricCard
              key={p}
              label={PLATFORM_LABEL[p]}
              value={summary.byPlatform[p].toLocaleString("ko-KR")}
              unit={`명 · ${percent(summary.byPlatform[p], summary.total)}`}
            />
          ))}
          <MetricCard
            label={PLATFORM_LABEL.unknown}
            value={summary.byPlatform.unknown.toLocaleString("ko-KR")}
            unit={`명 · ${percent(summary.byPlatform.unknown, summary.total)}`}
          />
        </div>
      </section>

      <section className="panel">
        <div className="panel-head">
          <h2>버전별</h2>
        </div>
        {rows.length === 0 ? (
          <p className="muted center">{loading ? "불러오는 중…" : "집계할 사용자가 없어요."}</p>
        ) : (
          <div className="table-wrap">
            <table className="data-table">
              <thead>
                <tr>
                  <th>앱 버전</th>
                  <th>사용자 수</th>
                  <th>비율</th>
                  <th>Android</th>
                  <th>iOS</th>
                </tr>
              </thead>
              <tbody>
                {rows.map((r) => (
                  <tr key={r.version ?? "none"}>
                    <td>{r.version ?? <span className="muted">미확인</span>}</td>
                    <td>{r.total.toLocaleString("ko-KR")}명</td>
                    <td>{percent(r.total, summary.total)}</td>
                    <td>{r.version === null ? "-" : `${r.android.toLocaleString("ko-KR")}명`}</td>
                    <td>{r.version === null ? "-" : `${r.ios.toLocaleString("ko-KR")}명`}</td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
        )}
      </section>
    </div>
  );
}
