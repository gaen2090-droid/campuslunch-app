import { useState, type ReactNode } from "react";
import { fetchTrustSignalsUserDetail } from "../lib/adminApi";
import { errorMessage } from "../lib/errors";
import {
  fmtMeters,
  fmtMin,
  fmtMs,
  type TrustSignalsUserDetail,
  type TrustSignalsUserRow,
} from "../types/trustAbuse";
import { Modal } from "./Modal";

function MetricBlock({
  title,
  children,
}: {
  title: string;
  children: ReactNode;
}) {
  return (
    <div className="info-panel mt-0">
      <strong>{title}</strong>
      <div className="muted sm mt-1-5">
        {children}
      </div>
    </div>
  );
}

export function UserTrustSummaryCards({ u }: { u: TrustSignalsUserRow }) {
  return (
    <div className="trust-summary-grid">
      <MetricBlock title="같은 매장 제보 간격(분)">
        <p>
          쌍 {u.sameStoreIntervalPairCount} · 평균{" "}
          {fmtMin(u.sameStoreIntervalAvgMin)} · 중앙값{" "}
          {fmtMin(u.sameStoreIntervalMedianMin)}
        </p>
        <p>
          최소 {fmtMin(u.sameStoreIntervalMinMin)} · 최대{" "}
          {fmtMin(u.sameStoreIntervalMaxMin)}
        </p>
        {u.sameStoreIntervalsMin.length > 0 && (
          <p className="mono xs">
            [{u.sameStoreIntervalsMin.slice(0, 12).join(", ")}
            {u.sameStoreIntervalsMin.length > 12 ? ", …" : ""}]
          </p>
        )}
      </MetricBlock>

      <MetricBlock title="연속 제보 이동 거리(m)">
        <p>
          쌍 {u.movePairCount} · 평균 {fmtMeters(u.moveAvgM)} · 중앙값{" "}
          {fmtMeters(u.moveMedianM)}
        </p>
        <p>
          최소 {fmtMeters(u.moveMinM)} · 최대 {fmtMeters(u.moveMaxM)}
        </p>
        {u.moveMeters.length > 0 && (
          <p className="mono xs">
            [{u.moveMeters.slice(0, 12).join(", ")}
            {u.moveMeters.length > 12 ? ", …" : ""}]
          </p>
        )}
      </MetricBlock>

      <MetricBlock title="구역 이동">
        <p>전환 {u.areaTransitionCount}회</p>
        {u.areaTransitions.slice(0, 5).map((t, i) => (
          <p key={`${t.fromArea}-${t.toArea}-${i}`}>
            {t.fromArea || "?"} → {t.toArea || "?"} ({fmtMin(t.gapMin)})
          </p>
        ))}
      </MetricBlock>

      <MetricBlock title="10분 내 타유저 겹침">
        <p>
          일치 {u.peerAgreeCount} / 겹침 기회 {u.peerOverlapCount}
        </p>
      </MetricBlock>

      <MetricBlock title="동일 기기 계정">
        <p>
          기기 {u.deviceIds.length}개 · 공유 시 최대 계정{" "}
          {u.deviceMaxAccountsOnShared}
        </p>
        <p>형제 계정 {u.deviceSiblingUserCount}명</p>
      </MetricBlock>

      <MetricBlock title="제보 시도">
        <p>
          성공 {u.attemptSuccess} · 실패 {u.attemptFail}
        </p>
        {Object.keys(u.failReasons).length > 0 && (
          <p>
            {Object.entries(u.failReasons)
              .map(([k, v]) => `${k}: ${v}`)
              .join(" · ")}
          </p>
        )}
      </MetricBlock>

      <MetricBlock title="화면 체류">
        <p>합계 {fmtMs(u.dwellMsTotal)}</p>
        {Object.entries(u.dwellMsByScreen).map(([k, v]) => (
          <p key={k}>
            {k}: {fmtMs(v)}
          </p>
        ))}
      </MetricBlock>

      <MetricBlock title="비제보 활동 / 스탬프 시간">
        <p>
          상세 {u.detailViewN} · 지도 {u.mapClickN} · 검색 {u.searchClickN} ·
          배너 {u.bannerClickN} · 세션 {u.appSessionN}
        </p>
        <p>
          스탬프시간 내 제보 {u.reportsInStampHours} · 외{" "}
          {u.reportsOutStampHours}
        </p>
      </MetricBlock>
    </div>
  );
}

export function TrustUserDetailBody({
  detail,
}: {
  detail: TrustSignalsUserDetail;
}) {
  return (
    <>
      {detail.summary && <UserTrustSummaryCards u={detail.summary} />}
      {!detail.summary && (
        <p className="muted sm">
          최근 {detail.days}일 수집 요약이 없습니다. (제보·시도·체류 기록 없음)
        </p>
      )}
      <div className="mt-4">
        <strong>최근 제보</strong>
        {detail.recentReports.length === 0 ? (
          <p className="muted sm">없음</p>
        ) : (
          <ul className="feedback-list mt-2">
            {detail.recentReports.slice(0, 30).map((r) => (
              <li key={r.id} className="feedback-row">
                <div className="feedback-row-head">
                  <strong>{r.restaurantName}</strong>
                  <span className="badge">{r.area}</span>
                  <span className="badge">{r.level}</span>
                </div>
                <p className="muted xs">
                  {r.createdAt}
                  {r.lat != null && r.lng != null
                    ? ` · ${r.lat.toFixed(5)}, ${r.lng.toFixed(5)}`
                    : ""}
                </p>
              </li>
            ))}
          </ul>
        )}
      </div>
      <div className="mt-4">
        <strong>최근 시도(성공/실패)</strong>
        {detail.recentAttempts.length === 0 ? (
          <p className="muted sm">없음</p>
        ) : (
          <ul className="feedback-list mt-2">
            {detail.recentAttempts.slice(0, 30).map((a, i) => (
              <li key={`${a.createdAt}-${i}`} className="feedback-row">
                <div className="feedback-row-head">
                  <span className="badge">{a.outcome}</span>
                  {a.failReason && (
                    <span className="muted xs">{a.failReason}</span>
                  )}
                </div>
                <p className="muted xs">{a.createdAt}</p>
              </li>
            ))}
          </ul>
        )}
      </div>
    </>
  );
}

interface ProfileButtonProps {
  userId: string;
  nickname: string;
  days?: number;
}

/** 회원 관리 행용 — 정지 버튼과 같은 스타일로 프로필형 수집 지표 모달 */
export function TrustProfileButton({
  userId,
  nickname,
  days = 30,
}: ProfileButtonProps) {
  const [detail, setDetail] = useState<TrustSignalsUserDetail | null>(null);
  const [busy, setBusy] = useState(false);
  const [err, setErr] = useState<string | null>(null);

  async function open() {
    setBusy(true);
    setErr(null);
    try {
      const data = await fetchTrustSignalsUserDetail(userId, days);
      setDetail(data);
    } catch (e) {
      setErr(errorMessage(e));
    } finally {
      setBusy(false);
    }
  }

  return (
    <>
      <button
        type="button"
        className="btn ghost sm"
        disabled={busy}
        onClick={() => void open()}
      >
        {busy ? "불러오는 중…" : "수집 지표"}
      </button>
      {err && !detail && (
        <p className="muted xs mt-0">
          {err}
        </p>
      )}
      {detail && (
        <Modal
          title={`${nickname || "유저"} · 수집 지표`}
          onClose={() => setDetail(null)}
        >
          {err && <div className="alert">{err}</div>}
          <p className="muted xs">최근 {detail.days}일 · 점수/판정 없음</p>
          <TrustUserDetailBody detail={detail} />
        </Modal>
      )}
    </>
  );
}
