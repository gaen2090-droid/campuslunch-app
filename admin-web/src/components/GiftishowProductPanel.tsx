import { useEffect, useState } from "react";
import {
  fetchGiftishowBalance,
  fetchGiftishowProduct,
  saveGiftishowProduct,
  type GiftishowProduct,
} from "../lib/adminApi";
import { errorMessage } from "../lib/errors";

const EMPTY: GiftishowProduct = {
  goodsCode: "",
  brand: "",
  productName: "",
  faceValue: null,
  imageUrl: "",
  isEnabled: false,
};

export function GiftishowProductPanel() {
  const [product, setProduct] = useState<GiftishowProduct>(EMPTY);
  const [faceText, setFaceText] = useState("");
  const [loading, setLoading] = useState(true);
  const [saving, setSaving] = useState(false);
  const [balanceBusy, setBalanceBusy] = useState(false);
  const [message, setMessage] = useState<string | null>(null);
  const [error, setError] = useState<string | null>(null);

  useEffect(() => {
    let cancelled = false;
    fetchGiftishowProduct()
      .then((row) => {
        if (cancelled) return;
        setProduct(row);
        setFaceText(row.faceValue != null ? String(row.faceValue) : "");
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
  }, []);

  async function save() {
    setSaving(true);
    setError(null);
    setMessage(null);
    try {
      const face = faceText.trim()
        ? Number.parseInt(faceText.replace(/,/g, ""), 10)
        : null;
      if (face != null && (!Number.isFinite(face) || face < 0)) {
        throw new Error("액면가는 0 이상 숫자로 입력해 주세요.");
      }
      const next = { ...product, faceValue: face };
      await saveGiftishowProduct(next);
      setProduct(next);
      setMessage("기프티쇼 상품을 저장했어요.");
    } catch (e) {
      setError(errorMessage(e));
    } finally {
      setSaving(false);
    }
  }

  async function checkBalance() {
    setBalanceBusy(true);
    setError(null);
    setMessage(null);
    try {
      const result = await fetchGiftishowBalance();
      if (!result.ok) {
        setError(result.message || "비즈머니를 조회하지 못했어요.");
      } else {
        setMessage(
          result.balance != null
            ? `비즈머니 잔액 ${Number(result.balance).toLocaleString("ko-KR")}원`
            : result.message,
        );
      }
    } catch (e) {
      setError(errorMessage(e));
    } finally {
      setBalanceBusy(false);
    }
  }

  return (
    <section className="card" style={{ marginBottom: 16 }}>
      <h2>기프티쇼 교환 상품 (1종)</h2>
      <p className="muted sm">
        켜 두면 스탬프 20개 교환 때 수동 재고 대신 이 상품코드로 발급합니다.
        API 키는 서버 시크릿에만 둡니다.
      </p>
      {loading ? (
        <p className="muted sm">불러오는 중…</p>
      ) : (
        <>
          <div className="form-row">
            <label className="field">
              <span className="field-label">goods_code</span>
              <input
                value={product.goodsCode}
                onChange={(e) =>
                  setProduct({ ...product, goodsCode: e.target.value })
                }
                placeholder="G00000..."
              />
            </label>
            <label className="field">
              <span className="field-label">브랜드</span>
              <input
                value={product.brand}
                onChange={(e) =>
                  setProduct({ ...product, brand: e.target.value })
                }
              />
            </label>
            <label className="field">
              <span className="field-label">상품명</span>
              <input
                value={product.productName}
                onChange={(e) =>
                  setProduct({ ...product, productName: e.target.value })
                }
              />
            </label>
            <label className="field">
              <span className="field-label">액면가(원)</span>
              <input
                value={faceText}
                onChange={(e) => setFaceText(e.target.value)}
                inputMode="numeric"
              />
            </label>
          </div>
          <label className="checkbox-row">
            <input
              type="checkbox"
              checked={product.isEnabled}
              onChange={(e) =>
                setProduct({ ...product, isEnabled: e.target.checked })
              }
            />
            <span>기프티쇼 발급 사용 (끄면 기존 수동 재고)</span>
          </label>
          <div className="topbar-actions">
            <button
              type="button"
              className="btn primary sm"
              disabled={saving}
              onClick={save}
            >
              {saving ? "저장 중…" : "상품 저장"}
            </button>
            <button
              type="button"
              className="btn ghost sm"
              disabled={balanceBusy}
              onClick={checkBalance}
            >
              {balanceBusy ? "조회 중…" : "비즈머니 잔액"}
            </button>
          </div>
        </>
      )}
      {error && <div className="alert">{error}</div>}
      {message && <div className="alert success">{message}</div>}
      <div className="muted sm">
        <p>계약·키 신청 체크리스트</p>
        <ol>
          <li>기프티쇼 비즈(Pro) 계약. 용도는 리워드 교환(현금 판매 아님).</li>
          <li>
            API 키 발급: custom_auth_code, custom_auth_token, user_id, 발신번호.
          </li>
          <li>
            교환 상품 goods_code 1개 확정 후 위 칸에 저장. 켜는 건 키를 넣은
            다음.
          </li>
          <li>
            Supabase 시크릿: GIFTISHOW_AUTH_CODE, GIFTISHOW_AUTH_TOKEN,
            GIFTISHOW_USER_ID, GIFTISHOW_CALLBACK_NO. 수신번호는
            GIFTISHOW_PHONE_NO(없으면 발신번호). Edge Function
            issue-giftishow 배포.
          </li>
          <li>
            발급은 핀+바코드 이미지(gubun=I). 회원 전화번호는 수집하지 않으니,
            이 방식이 문자를 보내지 않는지 기프티쇼에 확인.
          </li>
          <li>비즈머니 충전. 잔액 없으면 발급이 실패하고 스탬프는 되돌아갑니다.</li>
        </ol>
      </div>
    </section>
  );
}
