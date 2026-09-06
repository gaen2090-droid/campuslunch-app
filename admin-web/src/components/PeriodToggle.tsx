interface Props {
  value: "7d" | "30d";
  onChange: (value: "7d" | "30d") => void;
}

export function PeriodToggle({ value, onChange }: Props) {
  return (
    <div className="row-actions" style={{ justifyContent: "flex-end" }}>
      <button
        type="button"
        className={`btn sm${value === "7d" ? " primary" : " outline"}`}
        onClick={() => onChange("7d")}
      >
        최근 7일
      </button>
      <button
        type="button"
        className={`btn sm${value === "30d" ? " primary" : " outline"}`}
        onClick={() => onChange("30d")}
      >
        최근 30일
      </button>
    </div>
  );
}
