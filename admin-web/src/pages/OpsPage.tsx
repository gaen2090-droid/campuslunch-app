import { useState } from "react";
import { MetricCard } from "../components/MetricCard";
import { Modal } from "../components/Modal";
import { PeriodToggle } from "../components/PeriodToggle";
import { TrendChart } from "../components/TrendChart";
import { formatCount, lastNDayLabels } from "../lib/metrics";
import type {
  BannerRestaurantRow,
  FeatureStats,
  OpsMetrics,
} from "../types/opsMetrics";

interface Props {
  metrics: OpsMetrics | null;
  loading: boolean;
  error: string | null;
}

function diffPct(current: number, prev: number): string {
  const diff = Math.round((current - prev) * 10) / 10;
  return `${diff >= 0 ? "+" : ""}${diff}%p`;
}

type FeatureKey = "fairy" | "roulette";

const FEATURE_LABEL: Record<FeatureKey, string> = {
  fairy: "점메추 요정",
  roulette: "식당 룰렛",
};

/** 결과 공유 버튼의 액션 이름 (요정: share_click, 룰렛: result_share_click) */
const RESULT_SHARE_ACTION: Record<FeatureKey, string> = {
  fairy: "share_click",
  roulette: "result_share_click",
};

const FEATURE_ROWS: Record<FeatureKey, [string, string][]> = {
  fairy: [
    ["화면 진입", "open"],
    ["결과 노출", "result_shown"],
    ["카톡 공유 클릭", "share_click"],
    ["다른 곳 볼래요", "reroll"],
    ["매장 자세히 보기", "detail_click"],
  ],
  roulette: [
    ["화면 진입", "open"],
    ["친구 링크로 진입", "preset_open"],
    ["룰렛 돌리기", "spin"],
    ["결과 노출", "result_shown"],
    ["결과 공유 클릭", "result_share_click"],
    ["후보 공유 클릭", "candidates_share_click"],
    ["매장 자세히 보기", "detail_click"],
  ],
};

function FeatureDetail({
  feature,
  stats,
}: {
  feature: FeatureKey;
  stats: FeatureStats;
}) {
  return (
    <>
      <div className="two-col">
        <TrendChart
          title="일별 결과 공유 클릭 수 (최근 7일)"
          labels={lastNDayLabels(7)}
          values={stats.daily7d.map((d) => d.shareClicks)}
          kind="bar"
        />
        <TrendChart
          title="일별 결과 노출 수 (최근 7일)"
          labels={lastNDayLabels(7)}
          values={stats.daily7d.map((d) => d.resultShown)}
          kind="bar"
        />
      </div>
      <div className="table-wrap mt-8">
        <table className="data-table">
          <thead>
            <tr>
              <th>동작</th>
              <th>최근 7일</th>
              <th>오늘</th>
            </tr>
          </thead>
          <tbody>
            {FEATURE_ROWS[feature].map(([label, action]) => (
              <tr key={action}>
                <td>{label}</td>
                <td>{formatCount(stats.actions7d[action] ?? 0)}</td>
                <td>{formatCount(stats.actionsToday[action] ?? 0)}</td>
              </tr>
            ))}
          </tbody>
        </table>
      </div>
      <p className="muted sm mt-8">
        결과 공유 CTR {stats.shareCtr7d}% = {RESULT_SHARE_ACTION[feature]} ÷ result_shown.
        이용자 {formatCount(stats.users7d)}명 중 공유 버튼을 누른 사람은{" "}
        {formatCount(stats.shareUsers7d)}명이에요. 결과 노출은 추천이 보이거나 룰렛이
        멈출 때마다 집계돼서, 다시 돌리면 다시 집계됩니다.
      </p>
    </>
  );
}

export function OpsPage({ metrics, loading, error }: Props) {
  const [featureModal, setFeatureModal] = useState<FeatureKey | null>(null);
  const [showBannerModal, setShowBannerModal] = useState(false);
  const [showPushModal, setShowPushModal] = useState(false);
  const [showRewardModal, setShowRewardModal] = useState(false);
  const [showReferralModal, setShowReferralModal] = useState(false);
  const [selectedBanner, setSelectedBanner] = useState<BannerRestaurantRow | null>(null);
  const [rewardPeriod, setRewardPeriod] = useState<"7d" | "30d">("7d");
  const [referralPeriod, setReferralPeriod] = useState<"7d" | "30d">("7d");

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

      {metrics.featureMetrics && (
        <section className="metric-grid metric-grid--primary">
          {(["fairy", "roulette"] as FeatureKey[]).map((key) => {
            const stats = metrics.featureMetrics![key];
            const shown = stats.actions7d.result_shown ?? 0;
            const shared = stats.actions7d[RESULT_SHARE_ACTION[key]] ?? 0;
            return (
              <MetricCard
                key={key}
                size="primary"
                label={`${FEATURE_LABEL[key]} 공유 CTR (최근 7일)`}
                value={`${stats.shareCtr7d}%`}
                unit={`결과 ${formatCount(shown)} · 공유 ${formatCount(shared)} · 이용자 ${formatCount(stats.users7d)}명 · 전주대비 ${diffPct(stats.shareCtr7d, stats.shareCtrPrev7d)}`}
                onClick={() => setFeatureModal(key)}
              />
            );
          })}
        </section>
      )}

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

      <section className="metric-grid">
        <MetricCard
          label="오늘 친구초대 성사"
          value={formatCount(metrics.referralsToday)}
          unit="건"
          onClick={() => setShowReferralModal(true)}
        />
        <MetricCard
          label="최근 7일 친구초대 성사"
          value={formatCount(metrics.referrals7d)}
          unit="건"
          onClick={() => setShowReferralModal(true)}
        />
        <MetricCard
          label="총 누적 친구초대 성사"
          value={formatCount(metrics.referralsTotal)}
          unit="건"
          onClick={() => setShowReferralModal(true)}
        />
        <MetricCard
          label="초대를 성공시킨 사람"
          value={formatCount(metrics.uniqueReferrers)}
          unit="명"
          onClick={() => setShowReferralModal(true)}
        />
        <MetricCard
          label="초대받아 가입한 사람"
          value={formatCount(metrics.uniqueReferred)}
          unit="명"
          onClick={() => setShowReferralModal(true)}
        />
      </section>

      {featureModal && metrics.featureMetrics && (
        <Modal
          title={`${FEATURE_LABEL[featureModal]} 운영 지표`}
          onClose={() => setFeatureModal(null)}
          wide
        >
          <FeatureDetail
            feature={featureModal}
            stats={metrics.featureMetrics[featureModal]}
          />
        </Modal>
      )}

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

      {showReferralModal && (
        <Modal title="친구초대 현황" onClose={() => setShowReferralModal(false)} wide>
          <PeriodToggle value={referralPeriod} onChange={setReferralPeriod} />
          <TrendChart
            title="일별 친구초대 성사 추이"
            labels={lastNDayLabels(referralPeriod === "7d" ? 7 : 30)}
            values={referralPeriod === "7d" ? metrics.dailyReferrals7d : metrics.dailyReferrals30d}
            kind="bar"
          />

          <div className="metric-grid mt-8">
            <div>
              <p className="metric-label">총 성사 건수</p>
              <p className="metric-value">{formatCount(metrics.referralsTotal)}</p>
            </div>
            <div>
              <p className="metric-label">초대를 성공시킨 사람</p>
              <p className="metric-value">{formatCount(metrics.uniqueReferrers)}</p>
            </div>
            <div>
              <p className="metric-label">초대받아 가입한 사람</p>
              <p className="metric-value">{formatCount(metrics.uniqueReferred)}</p>
            </div>
          </div>

          <div className="panel-head mt-8">
            <h3>추천인별 성사 랭킹 (어뷰징 감시용, 상위 20명)</h3>
          </div>
          <p className="muted xs">
            누적 건수가 유난히 많거나 최근 24시간/7일에 몰려있으면 어뷰징 의심 대상이에요. (현재 추천인당 하루 최대 1건 성사 제한 적용 중)
          </p>
          {metrics.topReferrers.length === 0 ? (
            <p className="muted center">친구초대 성사 이력이 없어요.</p>
          ) : (
            <div className="table-wrap">
              <table className="data-table">
                <thead>
                  <tr>
                    <th>닉네임</th>
                    <th>이메일</th>
                    <th>누적 성사</th>
                    <th>최근 24시간</th>
                    <th>최근 7일</th>
                    <th>마지막 성사</th>
                  </tr>
                </thead>
                <tbody>
                  {metrics.topReferrers.map((row) => (
                    <tr
                      key={row.userId}
                      className={row.last24hCount >= 3 || row.last7dCount >= 7 ? "row-warning" : undefined}
                    >
                      <td>{row.nickname || "(닉네임 없음)"}</td>
                      <td>{row.email}</td>
                      <td>{row.totalCount}건</td>
                      <td>{row.last24hCount}건</td>
                      <td>{row.last7dCount}건</td>
                      <td>
                        {row.lastReferredAt
                          ? row.lastReferredAt.toLocaleString("ko-KR")
                          : "-"}
                      </td>
                    </tr>
                  ))}
                </tbody>
              </table>
            </div>
          )}

          <div className="panel-head mt-8">
            <h3>최근 성사 이력 (최신순, 최근 50건)</h3>
          </div>
          {metrics.recentReferrals.length === 0 ? (
            <p className="muted center">친구초대 성사 이력이 없어요.</p>
          ) : (
            <div className="table-wrap">
              <table className="data-table">
                <thead>
                  <tr>
                    <th>시각</th>
                    <th>추천인</th>
                    <th>가입한 사람</th>
                  </tr>
                </thead>
                <tbody>
                  {metrics.recentReferrals.map((row) => (
                    <tr key={row.id}>
                      <td>{row.createdAt.toLocaleString("ko-KR")}</td>
                      <td>{row.referrerNickname || "(닉네임 없음)"}</td>
                      <td>{row.referredNickname || "(닉네임 없음)"}</td>
                    </tr>
                  ))}
                </tbody>
              </table>
            </div>
          )}
        </Modal>
      )}
    </div>
  );
}
