import { useMemo, useState } from "react";
import { fetchTrustSignalsUserDetail } from "../lib/adminApi";
import { errorMessage } from "../lib/errors";
import {
  fmtMeters,
  fmtMin,
  fmtMs,
  type TrustSignalsReport,
  type TrustSignalsUserDetail,
} from "../types/trustAbuse";
import { Modal } from "../components/Modal";
import { TrustUserDetailBody } from "../components/TrustUserProfile";

interface Props {
  report: TrustSignalsReport | null;
  days: number;
  loading: boolean;
  error: string | null;
  onReload: (days?: number) => void;
  onExport: () => void;
}

export function TrustSignalsPage({
  report,
  days,
  loading,
  error,
  onReload,
  onExport,
}: Props) {
  const [query, setQuery] = useState("");
  const [detail, setDetail] = useState<TrustSignalsUserDetail | null>(null);
  const [detailBusy, setDetailBusy] = useState(false);
  const [detailError, setDetailError] = useState<string | null>(null);

  const filtered = useMemo(() => {
    const users = report?.users ?? [];
    const q = query.trim().toLowerCase();
    if (!q) return users;
    return users.filter(
      (u) =>
        u.email.toLowerCase().includes(q) ||
        u.nickname.toLowerCase().includes(q) ||
        u.userId.toLowerCase().includes(q),
    );
  }, [report, query]);

  async function openDetail(userId: string) {
    setDetailBusy(true);
    setDetailError(null);
    try {
      const data = await fetchTrustSignalsUserDetail(userId, days);
      setDetail(data);
    } catch (e) {
      setDetailError(errorMessage(e));
    } finally {
      setDetailBusy(false);
    }
  }

  return (
    <div className="page">
      <div className="panel-head">
        <div>
          <h2>신뢰·어뷰징</h2>
          <p className="muted sm">
            최근 {report?.days ?? days}일 · 점수/판정 없이 원본 수치만 표시
          </p>
        </div>
        <div style={{ display: "flex", gap: 8, flexWrap: "wrap" }}>
          <select
            value={days}
            disabled={loading}
            onChange={(e) => onReload(Number(e.target.value))}
          >
            <option value={7}>7일</option>
            <option value={14}>14일</option>
            <option value={30}>30일</option>
            <option value={60}>60일</option>
          </select>
          <button
            type="button"
            className="btn outline sm"
            disabled={loading}
            onClick={() => onReload()}
          >
            {loading ? "불러오는 중…" : "새로고침"}
          </button>
          <button type="button" className="btn primary sm" onClick={onExport}>
            수집 지표 내보내기
          </button>
        </div>
      </div>

      <div className="info-panel">
        <strong>수집 지표</strong>
        <ul>
          <li>같은 매장 연속 제보 간격(분) · 연속 제보 GPS 이동(m)</li>
          <li>구역 전환 · 동일 기기 계정 · 제보 성공/실패 · 화면 체류</li>
          <li>
            개별 회원은 <strong>회원 관리</strong>에서 「수집 지표」 버튼으로도
            확인
          </li>
          <li>
            SQL: <code>supabase/trust_abuse_scoring.sql</code>
          </li>
        </ul>
      </div>

      {error && <div className="alert">{error}</div>}
      {detailError && <div className="alert">{detailError}</div>}

      <input
        className="search-input"
        placeholder="닉네임 · 이메일 · UUID 검색"
        value={query}
        onChange={(e) => setQuery(e.target.value)}
      />

      {loading && !report ? (
        <p className="muted center">불러오는 중…</p>
      ) : filtered.length === 0 ? (
        <p className="muted center">표시할 유저가 없습니다.</p>
      ) : (
        <ul className="user-list">
          {filtered.map((u) => (
            <li key={u.userId} className="user-row">
              <div className="user-row-main">
                <div className="user-row-head">
                  <strong>{u.nickname || "(닉네임 없음)"}</strong>
                  <span className="badge">제보 {u.reportCount}</span>
                </div>
                <p className="user-email">{u.email || u.userId}</p>
                <div className="user-meta">
                  <span>
                    같매장간격 중앙 {fmtMin(u.sameStoreIntervalMedianMin)}
                  </span>
                  <span>이동중앙 {fmtMeters(u.moveMedianM)}</span>
                  <span>
                    실패 {u.attemptFail}/{u.attemptSuccess + u.attemptFail}
                  </span>
                  <span>체류 {fmtMs(u.dwellMsTotal)}</span>
                  <span>형제계정 {u.deviceSiblingUserCount}</span>
                </div>
              </div>
              <div className="user-row-actions">
                <button
                  type="button"
                  className="btn outline sm"
                  disabled={detailBusy}
                  onClick={() => void openDetail(u.userId)}
                >
                  상세 수치
                </button>
              </div>
            </li>
          ))}
        </ul>
      )}

      {detail && (
        <Modal
          title={`${detail.summary?.nickname || "유저"} · 수집 지표`}
          onClose={() => setDetail(null)}
        >
          <p className="muted xs">최근 {detail.days}일 · 점수/판정 없음</p>
          <TrustUserDetailBody detail={detail} />
        </Modal>
      )}
    </div>
  );
}
