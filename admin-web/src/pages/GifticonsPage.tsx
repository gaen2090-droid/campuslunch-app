import { useState } from "react";
import {
  bulkRegisterGifticons,
  deleteGifticon,
  registerGifticon,
  uploadGifticonImage,
} from "../lib/adminApi";
import { Modal } from "../components/Modal";
import {
  gifticonStatusLabel,
  parseGifticonCsv,
  type Gifticon,
} from "../types/gifticon";
import { readTextFileAutoEncoding } from "../lib/readTextFile";

interface Props {
  gifticons: Gifticon[];
  loading: boolean;
  error: string | null;
  onReload: () => void;
}

export function GifticonsPage({
  gifticons,
  loading,
  error,
  onReload,
}: Props) {
  const [showForm, setShowForm] = useState(false);
  const [brand, setBrand] = useState("");
  const [productName, setProductName] = useState("");
  const [imageFile, setImageFile] = useState<File | null>(null);
  const [preview, setPreview] = useState<string | null>(null);
  const [saving, setSaving] = useState(false);
  const [formError, setFormError] = useState<string | null>(null);
  const [csvBusy, setCsvBusy] = useState(false);
  const [deleteTarget, setDeleteTarget] = useState<Gifticon | null>(null);
  const [deleteBusy, setDeleteBusy] = useState(false);

  function canDeleteGifticon(g: Gifticon): boolean {
    return g.status === "unassigned" || g.status === "expired";
  }

  function onPickImage(file: File | null) {
    setImageFile(file);
    if (preview) URL.revokeObjectURL(preview);
    setPreview(file ? URL.createObjectURL(file) : null);
  }

  async function submit(e: React.FormEvent) {
    e.preventDefault();
    if (!brand.trim() || !productName.trim() || !imageFile) {
      setFormError("모든 항목을 입력해주세요.");
      return;
    }
    setSaving(true);
    setFormError(null);
    try {
      const path = await uploadGifticonImage(imageFile);
      await registerGifticon({
        brand: brand.trim(),
        productName: productName.trim(),
        imageUrl: path,
      });
      setBrand("");
      setProductName("");
      onPickImage(null);
      setShowForm(false);
      onReload();
    } catch (err) {
      setFormError(err instanceof Error ? err.message : String(err));
    } finally {
      setSaving(false);
    }
  }

  async function onCsvUpload(file: File | null) {
    if (!file) return;
    setCsvBusy(true);
    setFormError(null);
    try {
      const text = await readTextFileAutoEncoding(file);
      const rows = parseGifticonCsv(text);
      if (rows.length === 0) {
        throw new Error("유효한 CSV 행이 없어요.");
      }
      const inserted = await bulkRegisterGifticons(rows);
      onReload();
      setFormError(null);
      alert(`CSV로 기프티콘 ${inserted}건 등록했어요.`);
    } catch (err) {
      setFormError(err instanceof Error ? err.message : String(err));
    } finally {
      setCsvBusy(false);
    }
  }

  async function confirmDelete() {
    if (!deleteTarget) return;
    setDeleteBusy(true);
    setFormError(null);
    try {
      await deleteGifticon(deleteTarget.id);
      setDeleteTarget(null);
      onReload();
    } catch (err) {
      setFormError(err instanceof Error ? err.message : String(err));
    } finally {
      setDeleteBusy(false);
    }
  }

  return (
    <div className="page">
      <div className="panel-head">
        <h2>기프티콘 관리</h2>
        <div className="topbar-actions">
          <button
            type="button"
            className="btn ghost sm"
            disabled={csvBusy}
            onClick={() => {
              const input = document.createElement("input");
              input.type = "file";
              input.accept = ".csv,text/csv";
              input.onchange = () => onCsvUpload(input.files?.[0] ?? null);
              input.click();
            }}
          >
            {csvBusy ? "업로드 중…" : "CSV 업로드"}
          </button>
          <button
            type="button"
            className="btn primary sm"
            onClick={() => setShowForm((v) => !v)}
          >
            {showForm ? "취소" : "+ 등록"}
          </button>
        </div>
      </div>

      {(error || formError) && (
        <div className="alert">{error ?? formError}</div>
      )}

      <p className="muted xs">
        CSV 헤더: brand, product_name, image_url, expires_at, coupon_code
      </p>

      {showForm && (
        <form className="panel form-grid" onSubmit={submit}>
          <h3>기프티콘 등록</h3>
          <label className="field">
            <span className="field-label">브랜드명</span>
            <input
              placeholder="예: 바나프레소"
              value={brand}
              onChange={(e) => setBrand(e.target.value)}
            />
          </label>
          <label className="field">
            <span className="field-label">상품명</span>
            <input
              placeholder="예: 아메리카노"
              value={productName}
              onChange={(e) => setProductName(e.target.value)}
            />
          </label>
          <label className="field">
            <span className="field-label">이미지</span>
            <div className="image-picker">
              {preview ? (
                <img src={preview} alt="" className="preview-img" />
              ) : (
                <span className="muted">기프티콘 이미지 선택</span>
              )}
              <input
                type="file"
                accept="image/*"
                onChange={(e) => onPickImage(e.target.files?.[0] ?? null)}
              />
            </div>
          </label>
          <button type="submit" className="btn primary block" disabled={saving}>
            {saving ? "등록 중…" : "등록하기"}
          </button>
        </form>
      )}

      {loading ? (
        <p className="muted center">불러오는 중…</p>
      ) : gifticons.length === 0 ? (
        <p className="muted center">등록된 기프티콘이 없어요.</p>
      ) : (
        <ul className="gifticon-list">
          {gifticons.map((g) => (
            <li key={g.id} className="gifticon-row">
              {g.imageUrl ? (
                <img src={g.imageUrl} alt="" className="gifticon-thumb" />
              ) : (
                <div className="gifticon-thumb placeholder" />
              )}
              <div className="gifticon-row-body">
                <strong>{g.brand}</strong>
                <p className="muted sm">{g.productName}</p>
                <span className={`badge ${g.status}`}>
                  {gifticonStatusLabel(g.status)}
                </span>
              </div>
              {canDeleteGifticon(g) ? (
                <button
                  type="button"
                  className="btn ghost sm danger-text"
                  disabled={deleteBusy}
                  onClick={() => setDeleteTarget(g)}
                >
                  삭제
                </button>
              ) : (
                <span className="muted xs gifticon-no-delete">삭제 불가</span>
              )}
            </li>
          ))}
        </ul>
      )}

      {deleteTarget && (
        <Modal title="기프티콘 삭제" onClose={() => setDeleteTarget(null)}>
          <p>
            <strong>{deleteTarget.brand}</strong> · {deleteTarget.productName}
          </p>
          <p className="muted sm">이 기프티콘을 삭제할까요?</p>
          <div className="modal-actions">
            <button
              type="button"
              className="btn ghost"
              disabled={deleteBusy}
              onClick={() => setDeleteTarget(null)}
            >
              취소
            </button>
            <button
              type="button"
              className="btn danger"
              disabled={deleteBusy}
              onClick={confirmDelete}
            >
              {deleteBusy ? "삭제 중…" : "삭제"}
            </button>
          </div>
        </Modal>
      )}
    </div>
  );
}
