import { useState } from "react";
import {
  bulkDeleteGifticons,
  bulkRegisterGifticons,
  deleteGifticon,
  registerGifticon,
  uploadGifticonImage,
} from "../lib/adminApi";
import { Modal } from "../components/Modal";
import { errorMessage } from "../lib/errors";
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
  const [faceValue, setFaceValue] = useState("");
  const [imageFile, setImageFile] = useState<File | null>(null);
  const [preview, setPreview] = useState<string | null>(null);
  const [saving, setSaving] = useState(false);
  const [formError, setFormError] = useState<string | null>(null);
  const [csvBusy, setCsvBusy] = useState(false);
  const [deleteTarget, setDeleteTarget] = useState<Gifticon | null>(null);
  const [deleteBusy, setDeleteBusy] = useState(false);
  const [selectedIds, setSelectedIds] = useState<Set<string>>(new Set());
  const [bulkDeleteOpen, setBulkDeleteOpen] = useState(false);
  const [bulkDeleteBusy, setBulkDeleteBusy] = useState(false);

  const [bulkOpen, setBulkOpen] = useState(false);
  const [bulkBrand, setBulkBrand] = useState("");
  const [bulkProductName, setBulkProductName] = useState("");
  const [bulkExpiresAt, setBulkExpiresAt] = useState("");
  const [bulkRows, setBulkRows] = useState<
    Array<{ file: File; preview: string }>
  >([]);
  const [bulkBusy, setBulkBusy] = useState(false);
  const [bulkProgress, setBulkProgress] = useState<string | null>(null);

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
      const parsedFace = faceValue.trim()
        ? Number.parseInt(faceValue.replace(/,/g, ""), 10)
        : undefined;
      if (parsedFace != null && (!Number.isFinite(parsedFace) || parsedFace < 0)) {
        throw new Error("액수(원)는 0 이상 숫자로 입력해 주세요.");
      }
      await registerGifticon({
        brand: brand.trim(),
        productName: productName.trim(),
        imageUrl: path,
        ...(parsedFace != null ? { faceValue: parsedFace } : {}),
      });
      setBrand("");
      setProductName("");
      setFaceValue("");
      onPickImage(null);
      setShowForm(false);
      onReload();
    } catch (err) {
      setFormError(errorMessage(err));
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
      setFormError(errorMessage(err));
    } finally {
      setCsvBusy(false);
    }
  }

  function openBulk() {
    setBulkBrand("");
    setBulkProductName("");
    setBulkExpiresAt("");
    setBulkRows([]);
    setFormError(null);
    setBulkOpen(true);
  }

  function closeBulk() {
    for (const r of bulkRows) URL.revokeObjectURL(r.preview);
    setBulkRows([]);
    setBulkOpen(false);
  }

  function onPickBulkImages(files: FileList | null) {
    const picked = Array.from(files ?? []);
    if (picked.length === 0) return;
    setBulkRows((prev) => [
      ...prev,
      ...picked.map((file) => ({
        file,
        preview: URL.createObjectURL(file),
      })),
    ]);
  }

  function removeBulkRow(index: number) {
    setBulkRows((prev) => {
      const target = prev[index];
      if (target) URL.revokeObjectURL(target.preview);
      return prev.filter((_, i) => i !== index);
    });
  }

  async function submitBulk() {
    if (!bulkBrand.trim()) {
      setFormError("브랜드명을 입력해주세요.");
      return;
    }
    if (!bulkProductName.trim()) {
      setFormError("상품명을 입력해주세요.");
      return;
    }
    if (bulkRows.length === 0) {
      setFormError("이미지를 하나 이상 선택해주세요.");
      return;
    }
    setBulkBusy(true);
    setFormError(null);
    try {
      const rows: Array<Record<string, string>> = [];
      for (let i = 0; i < bulkRows.length; i++) {
        setBulkProgress(`이미지 업로드 중… (${i + 1}/${bulkRows.length})`);
        const path = await uploadGifticonImage(bulkRows[i].file);
        rows.push({
          brand: bulkBrand.trim(),
          product_name: bulkProductName.trim(),
          image_url: path,
          ...(bulkExpiresAt ? { expires_at: bulkExpiresAt } : {}),
        });
      }
      setBulkProgress("등록 중…");
      const inserted = await bulkRegisterGifticons(rows);
      closeBulk();
      onReload();
      alert(`기프티콘 ${inserted}건 등록했어요.`);
    } catch (err) {
      setFormError(errorMessage(err));
    } finally {
      setBulkBusy(false);
      setBulkProgress(null);
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
      setFormError(errorMessage(err));
    } finally {
      setDeleteBusy(false);
    }
  }

  function toggleSelected(id: string) {
    setSelectedIds((prev) => {
      const next = new Set(prev);
      if (next.has(id)) next.delete(id);
      else next.add(id);
      return next;
    });
  }

  const deletableGifticons = gifticons.filter(canDeleteGifticon);
  const allDeletableSelected =
    deletableGifticons.length > 0 &&
    deletableGifticons.every((g) => selectedIds.has(g.id));

  function toggleSelectAll() {
    setSelectedIds(
      allDeletableSelected
        ? new Set()
        : new Set(deletableGifticons.map((g) => g.id)),
    );
  }

  async function confirmBulkDelete() {
    setBulkDeleteBusy(true);
    setFormError(null);
    try {
      const deleted = await bulkDeleteGifticons(Array.from(selectedIds));
      setSelectedIds(new Set());
      setBulkDeleteOpen(false);
      onReload();
      alert(`기프티콘 ${deleted}건 삭제했어요.`);
    } catch (err) {
      setFormError(errorMessage(err));
    } finally {
      setBulkDeleteBusy(false);
    }
  }

  return (
    <div className="page">
      <div className="panel-head">
        <h2>기프티콘 관리</h2>
        <div className="topbar-actions">
          <button type="button" className="btn primary sm" onClick={openBulk}>
            쿠폰 대량 등록
          </button>
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
            className="btn ghost sm"
            onClick={() => setShowForm((v) => !v)}
          >
            {showForm ? "취소" : "+ 단건 등록"}
          </button>
        </div>
      </div>

      {(error || formError) && (
        <div className="alert">{error ?? formError}</div>
      )}

      <p className="muted xs">
        CSV 헤더: brand, product_name, image_url, expires_at, coupon_code,
        face_value(액수·원)
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
            <span className="field-label">액수(원)</span>
            <input
              type="number"
              min={0}
              step={100}
              placeholder="예: 5000"
              value={faceValue}
              onChange={(e) => setFaceValue(e.target.value)}
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
        <>
          <div className="panel-head" style={{ marginTop: 8 }}>
            <label className="muted sm" style={{ display: "flex", alignItems: "center", gap: 6 }}>
              <input
                type="checkbox"
                checked={allDeletableSelected}
                disabled={deletableGifticons.length === 0}
                onChange={toggleSelectAll}
              />
              전체 선택 (삭제 가능한 항목만)
            </label>
            {selectedIds.size > 0 && (
              <button
                type="button"
                className="btn danger sm"
                onClick={() => setBulkDeleteOpen(true)}
              >
                선택 삭제 ({selectedIds.size})
              </button>
            )}
          </div>
          <ul className="gifticon-list">
            {gifticons.map((g) => {
              const deletable = canDeleteGifticon(g);
              return (
                <li key={g.id} className="gifticon-row">
                  <input
                    type="checkbox"
                    checked={selectedIds.has(g.id)}
                    disabled={!deletable}
                    onChange={() => toggleSelected(g.id)}
                  />
                  {g.imageUrl ? (
                    <img src={g.imageUrl} alt="" className="gifticon-thumb" />
                  ) : (
                    <div className="gifticon-thumb placeholder" />
                  )}
                  <div className="gifticon-row-body">
                    <strong>{g.brand}</strong>
                    <p className="muted sm">{g.productName}</p>
                    {g.faceValue != null && g.faceValue > 0 && (
                      <p className="muted xs">
                        {g.faceValue.toLocaleString("ko-KR")}원
                      </p>
                    )}
                    <span className={`badge ${g.status}`}>
                      {gifticonStatusLabel(g.status)}
                    </span>
                  </div>
                  {deletable ? (
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
              );
            })}
          </ul>
        </>
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

      {bulkDeleteOpen && (
        <Modal
          title="기프티콘 선택 삭제"
          onClose={bulkDeleteBusy ? () => {} : () => setBulkDeleteOpen(false)}
        >
          <p className="muted sm">
            선택한 {selectedIds.size}건을 삭제할까요? 배정된 기프티콘은 애초에
            선택할 수 없으니, 선택된 건은 모두 미배정/만료 상태예요.
          </p>
          <div className="modal-actions">
            <button
              type="button"
              className="btn ghost"
              disabled={bulkDeleteBusy}
              onClick={() => setBulkDeleteOpen(false)}
            >
              취소
            </button>
            <button
              type="button"
              className="btn danger"
              disabled={bulkDeleteBusy}
              onClick={confirmBulkDelete}
            >
              {bulkDeleteBusy ? "삭제 중…" : "삭제"}
            </button>
          </div>
        </Modal>
      )}

      {bulkOpen && (
        <Modal title="쿠폰 대량 등록" onClose={bulkBusy ? () => {} : closeBulk} wide>
          <div className="form-grid">
            <label className="field">
              <span className="field-label">브랜드명 (전체 적용)</span>
              <input
                placeholder="예: 바나프레소"
                value={bulkBrand}
                onChange={(e) => setBulkBrand(e.target.value)}
              />
            </label>
            <label className="field">
              <span className="field-label">상품명 (전체 적용)</span>
              <input
                placeholder="예: 아메리카노 Tall"
                value={bulkProductName}
                onChange={(e) => setBulkProductName(e.target.value)}
              />
            </label>
            <label className="field">
              <span className="field-label">유효기간 (전체 적용, 선택)</span>
              <input
                type="date"
                value={bulkExpiresAt}
                onChange={(e) => setBulkExpiresAt(e.target.value)}
              />
            </label>
          </div>

          <div style={{ margin: "12px 0" }}>
            <button
              type="button"
              className="btn ghost sm"
              onClick={() => {
                const input = document.createElement("input");
                input.type = "file";
                input.accept = "image/*";
                input.multiple = true;
                input.onchange = () => onPickBulkImages(input.files);
                input.click();
              }}
            >
              + 이미지 추가
            </button>
          </div>

          {bulkRows.length === 0 ? (
            <p className="muted sm">
              같은 브랜드·상품의 쿠폰 이미지를 여러 장 선택하면, 선택한
              장수만큼 등록 항목이 자동으로 만들어져요.
            </p>
          ) : (
            <ul className="gifticon-list">
              {bulkRows.map((row, i) => (
                <li key={i} className="gifticon-row">
                  <img src={row.preview} alt="" className="gifticon-thumb" />
                  <div className="gifticon-row-body">
                    <span className="muted sm">이미지 {i + 1}</span>
                  </div>
                  <button
                    type="button"
                    className="btn ghost sm danger-text"
                    onClick={() => removeBulkRow(i)}
                  >
                    제거
                  </button>
                </li>
              ))}
            </ul>
          )}

          <div className="modal-actions">
            <button type="button" className="btn ghost" disabled={bulkBusy} onClick={closeBulk}>
              취소
            </button>
            <button
              type="button"
              className="btn primary"
              disabled={bulkBusy || bulkRows.length === 0}
              onClick={submitBulk}
            >
              {bulkBusy
                ? bulkProgress ?? "등록 중…"
                : `${bulkRows.length}건 등록하기`}
            </button>
          </div>
        </Modal>
      )}
    </div>
  );
}
