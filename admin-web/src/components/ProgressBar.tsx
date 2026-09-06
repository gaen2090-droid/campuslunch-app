interface Props {
  current: number;
  target: number;
}

export function ProgressBar({ current, target }: Props) {
  if (target <= 0) {
    return <p className="muted xs">목표 미설정</p>;
  }

  const pct = Math.min(100, Math.round((current / target) * 100));
  const tone = pct >= 100 ? "done" : pct >= 80 ? "near" : "behind";

  return (
    <div className="progress-bar-wrap">
      <div className="progress-bar-track">
        <div
          className={`progress-bar-fill progress-bar-fill--${tone}`}
          style={{ width: `${pct}%` }}
        />
      </div>
      <p className="muted xs">
        목표 {target.toLocaleString("ko-KR")} 중 {current.toLocaleString("ko-KR")} 달성 (
        {pct}%)
      </p>
    </div>
  );
}
