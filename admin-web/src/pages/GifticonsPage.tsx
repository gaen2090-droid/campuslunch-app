import { useState } from "react";
import {
  registerGifticon,
  uploadGifticonImage,
} from "../lib/adminApi";
import { gifticonStatusLabel, type Gifticon } from "../types/gifticon";

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

  return (
    <div className="page">
      <div className="panel-head">
        <h2>기프티콘 관리</h2>
        <button
          type="button"
          className="btn primary sm"
          onClick={() => setShowForm((v) => !v)}
        >
          {showForm ? "취소" : "+ 등록"}
        </button>
      </div>

      {(error || formError) && (
        <div className="alert">{error ?? formError}</div>
      )}

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
              <div>
                <strong>{g.brand}</strong>
                <p className="muted sm">{g.productName}</p>
                <span className={`badge ${g.status}`}>
                  {gifticonStatusLabel(g.status)}
                </span>
              </div>
            </li>
          ))}
        </ul>
      )}
    </div>
  );
}
