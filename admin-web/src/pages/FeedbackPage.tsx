import type { AppFeedback } from "../types/feedback";

interface Props {
  feedback: AppFeedback[];
  loading: boolean;
  error: string | null;
}

function formatDate(d: Date): string {
  return d.toLocaleString("ko-KR", {
    year: "numeric",
    month: "2-digit",
    day: "2-digit",
    hour: "2-digit",
    minute: "2-digit",
  });
}

export function FeedbackPage({ feedback, loading, error }: Props) {
  return (
    <div className="page">
      {error && <div className="alert">{error}</div>}

      {loading ? (
        <p className="muted center">불러오는 중…</p>
      ) : feedback.length === 0 ? (
        <p className="muted center">접수된 피드백이 없어요.</p>
      ) : (
        <ul className="feedback-list">
          {feedback.map((f) => (
            <li key={f.id} className="feedback-row">
              <div className="feedback-row-head">
                <span className="badge">{f.category}</span>
                {f.isFromOwner && (
                  <span className="badge owner">사장님</span>
                )}
                {f.nickname && (
                  <span className="muted sm">{f.nickname}</span>
                )}
                <span className="muted sm">{formatDate(f.createdAt)}</span>
              </div>
              <p className="feedback-content">{f.content}</p>
            </li>
          ))}
        </ul>
      )}
    </div>
  );
}
