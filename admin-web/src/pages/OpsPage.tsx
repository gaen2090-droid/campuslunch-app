import { useState } from "react";
import { MetricCard } from "../components/MetricCard";
import { Modal } from "../components/Modal";
import { PeriodToggle } from "../components/PeriodToggle";
import { TrendChart } from "../components/TrendChart";
import { formatCount, lastNDayLabels } from "../lib/metrics";
import type { OpsMetrics, BannerRestaurantRow } from "../types/opsMetrics";

interface Props {
  metrics: OpsMetrics | null;
  loading: boolean;
  error: string | null;
}

function diffPct(current: number, prev: number): string {
  const diff = Math.round((current - prev) * 10) / 10;
  return `${diff >= 0 ? "+" : ""}${diff}%p`;
}

export function OpsPage({ metrics, loading, error }: Props) {
  const [showBannerModal, setShowBannerModal] = useState(false);
  const [showPushModal, setShowPushModal] = useState(false);
  const [showRewardModal, setShowRewardModal] = useState(false);
  const [selectedBanner, setSelectedBanner] = useState<BannerRestaurantRow | null>(null);
  const [rewardPeriod, setRewardPeriod] = useState<"7d" | "30d">("7d");

  if (error) {
    return <div className="alert">{error}</div>;
  }
  if (!metrics) {
    return (
      <div className="center-msg">{loading ? "지표 불러오는 중…" : "데이터 없음"}</div>
    );
  }

  return (
    <div className="dashboard">
      <section className="metric-grid metric-grid--primary">
        <MetricCard
          size="primary"
          label="추천 배너 클릭률 (최근 7일)"
          value={`${metrics.bannerCtr7d}%`}
          unit={`노출 ${formatCount(metrics.bannerImpressions7d)} · 클릭 ${formatCount(metrics.bannerClicks7d)} · 전주대비 ${diffPct(metrics.bannerCtr7d, metrics.bannerCtrPrev7d)}`}
          onClick={() => setShowBannerModal(true)}
        />
        <MetricCard
          size="primary"
          label="푸시 오픈율 (점심시간 알림)"
          value={`${metrics.pushOpenRateToday}%`}
          unit={`오늘 발송 ${metrics.pushDeliveredToday} · 오픈 ${metrics.pushClicksToday}`}
          onClick={() => setShowPushModal(true)}
        />
      </section>

      <section className="metric-grid">
        <MetricCard
          label="오늘 쿠폰 지급"
          value={formatCount(metrics.couponsToday)}
          unit="건"
          onClick={() => setShowRewardModal(true)}
        />
        <MetricCard
          label="최근 7일 쿠폰 지급"
          value={formatCount(metrics.coupons7d)}
          unit="건"
          onClick={() => setShowRewardModal(true)}
        />
        <MetricCard
          label="총 누적 쿠폰 지급"
          value={formatCount(metrics.couponsTotal)}
          unit="건"
          onClick={() => setShowRewardModal(true)}
        />
        <MetricCard
          label="누적 고유 수령자"
          value={formatCount(metrics.uniqueRecipients)}
          unit="명"
          onClick={() => setShowRewardModal(true)}
        />
        <MetricCard
          label="현재 쿠폰 재고"
          value={formatCount(metrics.couponsInStock)}
          unit="개"
          onClick={() => setShowRewardModal(true)}
        />
      </section>
      <p className="muted xs">
        최근 7일 발송 {formatCount(metrics.pushDelivered7d)}건 · 오픈{" "}
        {formatCount(metrics.pushClicks7d)}건 · 평균 오픈율 {metrics.pushOpenRate7d}%
      </p>

      {showBannerModal && (
        <Modal title="추천 배너 성과" onClose={() => setShowBannerModal(false)} wide>
          <div className="two-col">
            <TrendChart
              title="최근 7일 CTR 추이 (%)"
              labels={lastNDayLabels(7)}
              values={metrics.bannerDailyCtr7d}
              suffix="%"
            />
            <TrendChart
              title="최근 30일 CTR 추이 (%)"
              labels={lastNDayLabels(30)}
              values={metrics.bannerDailyCtr30d}
              suffix="%"
            />
          </div>

          <div className="panel-head mt-8">
            <h3>매장별 성과 (최근 7일, CTR 높은 순)</h3>
          </div>
          {metrics.bannerByRestaurant.length === 0 ? (
            <p className="muted center">최근 7일간 노출된 매장이 없어요.</p>
          ) : (
            <div className="table-wrap">
              <table className="data-table">
                <thead>
                  <tr>
                    <th>매장명</th>
                    <th>노출 수</th>
                    <th>클릭 수</th>
                    <th>CTR</th>
                  </tr>
                </thead>
                <tbody>
                  {metrics.bannerByRestaurant.map((row) => (
                    <tr
                      key={row.restaurantId}
                      className="clickable-row"
                      onClick={() => setSelectedBanner(row)}
                    >
                      <td>{row.name}</td>
                      <td>{row.impressions}</td>
                      <td>{row.clicks}</td>
                      <td>{row.ctr}%</td>
                    </tr>
                  ))}
                </tbody>
              </table>
            </div>
          )}
        </Modal>
      )}

      {selectedBanner && (
        <Modal title={selectedBanner.name} onClose={() => setSelectedBanner(null)}>
          <div className="metric-grid">
            <div>
              <p className="metric-label">총 노출 수</p>
              <p className="metric-value">{selectedBanner.impressions}</p>
            </div>
            <div>
              <p className="metric-label">총 클릭 수</p>
              <p className="metric-value">{selectedBanner.clicks}</p>
            </div>
            <div>
              <p className="metric-label">평균 CTR</p>
              <p className="metric-value">{selectedBanner.ctr}%</p>
            </div>
          </div>
          <p className="muted xs mt-8">최근 7일 기준 집계</p>
        </Modal>
      )}

      {showPushModal && (
        <Modal title="푸시 오픈율 (점심시간 알림)" onClose={() => setShowPushModal(false)} wide>
          <div className="two-col">
            <TrendChart
              title="최근 7일 발송/오픈 수"
              labels={lastNDayLabels(7)}
              values={metrics.pushDaily7d.map((d) => d.delivered)}
              kind="bar"
            />
            <TrendChart
              title="최근 30일 발송/오픈 수"
              labels={lastNDayLabels(30)}
              values={metrics.pushDaily30d.map((d) => d.delivered)}
              kind="bar"
            />
          </div>
          <p className="muted sm mt-8">
            막대는 발송 수 기준입니다. 최근 7일 오픈율 {metrics.pushOpenRate7d}%
          </p>
        </Modal>
      )}

      {showRewardModal && (
        <Modal title="리워드 현황" onClose={() => setShowRewardModal(false)} wide>
          <PeriodToggle value={rewardPeriod} onChange={setRewardPeriod} />
          <TrendChart
            title="일별 쿠폰 지급 추이"
            labels={lastNDayLabels(rewardPeriod === "7d" ? 7 : 30)}
            values={rewardPeriod === "7d" ? metrics.dailyCoupons7d : metrics.dailyCoupons30d}
            kind="bar"
          />

          <div className="metric-grid mt-8">
            <div>
              <p className="metric-label">총 지급 건수</p>
              <p className="metric-value">{formatCount(metrics.couponsTotal)}</p>
            </div>
            <div>
              <p className="metric-label">고유 수령자 수</p>
              <p className="metric-value">{formatCount(metrics.uniqueRecipients)}</p>
            </div>
            <div>
              <p className="metric-label">현재 쿠폰 재고</p>
              <p className="metric-value">{formatCount(metrics.couponsInStock)}</p>
            </div>
          </div>

          <div className="panel-head mt-8">
            <h3>사용자별 쿠폰 지급 횟수 분포</h3>
          </div>
          {Object.keys(metrics.couponsPerUserDist).length === 0 ? (
            <p className="muted center">지급된 쿠폰이 없어요.</p>
          ) : (
            <div className="table-wrap">
              <table className="data-table">
                <thead>
                  <tr>
                    <th>받은 쿠폰 수</th>
                    <th>사용자 수</th>
                  </tr>
                </thead>
                <tbody>
                  {Object.entries(metrics.couponsPerUserDist)
                    .sort(([a], [b]) => Number(a) - Number(b))
                    .map(([count, userCount]) => (
                      <tr key={count}>
                        <td>{count}개</td>
                        <td>{userCount}명</td>
                      </tr>
                    ))}
                </tbody>
              </table>
            </div>
          )}

          <div className="panel-head mt-8">
            <h3>스탬프 보유 구간별 사용자 수</h3>
          </div>
          <div className="table-wrap">
            <table className="data-table">
              <thead>
                <tr>
                  <th>스탬프 보유 구간</th>
                  <th>사용자 수</th>
                </tr>
              </thead>
              <tbody>
                <tr>
                  <td>0~9개</td>
                  <td>{metrics.stampDist.under10}명</td>
                </tr>
                <tr>
                  <td>10~19개</td>
                  <td>{metrics.stampDist.from10to19}명</td>
                </tr>
                <tr>
                  <td>20개 이상</td>
                  <td>{metrics.stampDist.over20}명</td>
                </tr>
              </tbody>
            </table>
          </div>
        </Modal>
      )}
    </div>
  );
}
