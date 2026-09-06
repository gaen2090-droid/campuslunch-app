import { useState } from "react";
import { Modal } from "./Modal";

interface Props {
  title: string;
  onCancel: () => void;
  onConfirm: (reason: string) => void | Promise<void>;
}

export function DeleteReasonModal({ title, onCancel, onConfirm }: Props) {
  const [reason, setReason] = useState("");
  const [submitting, setSubmitting] = useState(false);

  async function submit() {
    if (submitting) return;
    setSubmitting(true);
    try {
      await onConfirm(reason.trim());
    } finally {
      setSubmitting(false);
    }
  }

  return (
    <Modal title={title} onClose={onCancel}>
      <p className="muted sm">삭제 사유는 대상 작성자에게 알림으로 전달돼요.</p>
      <textarea
        className="search-input textarea-resizable"
        placeholder="예: 욕설/비방 등 운영정책 위반"
        value={reason}
        onChange={(e) => setReason(e.target.value)}
        autoFocus
      />
      <div className="row-actions mt-3">
        <button type="button" className="btn ghost sm" disabled={submitting} onClick={onCancel}>
          취소
        </button>
        <button type="button" className="btn danger sm" disabled={submitting} onClick={submit}>
          삭제
        </button>
      </div>
    </Modal>
  );
}
