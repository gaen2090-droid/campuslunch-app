/** 목록·상세·엑셀에서 쓰는 지표 라벨과 설명 */
export const TRUST_FIELD_GLOSSARY: Array<{
  label: string;
  description: string;
}> = [
  {
    label: "제보 수",
    description: "기간 내 유저 소스 혼잡도 제보 성공 건수",
  },
  {
    label: "같은 매장 제보 간격",
    description:
      "같은 식당에 연속으로 제보했을 때, 이전 제보와의 시간 차이(분). 평균·중앙값·최소·최대와 간격 목록(배열)으로 제공",
  },
  {
    label: "전체 제보 간격",
    description:
      "매장과 관계없이 연속 제보 사이 시간 차이(분). 평균·중앙값·목록",
  },
  {
    label: "연속 제보 이동 거리",
    description:
      "연속 두 제보의 GPS 좌표 사이 직선 거리(m). 평균·중앙값·최소·최대·목록",
  },
  {
    label: "구역 전환",
    description:
      "제보 매장의 구역(정문/중문/후문)이 바뀔 때 from→to와 그때의 간격(분)",
  },
  {
    label: "피어 일치 / 겹침",
    description:
      "같은 매장에서 10분 안에 다른 유저 제보가 있을 때 겹침 기회 수, 그중 혼잡 레벨이 같은 일치 수",
  },
  {
    label: "동일 기기·형제 계정",
    description:
      "device_install_id 기준. 이 기기에서 잡힌 계정 수, 같은 기기를 쓰는 다른 유저(형제) 수·목록",
  },
  {
    label: "제보 시도 성공/실패",
    description:
      "report_attempts 기준 성공·실패 건수와 실패 사유별 건수(쿨다운, 거리 등)",
  },
  {
    label: "화면 체류",
    description:
      "탭/화면별 머문 시간 합(ms). home·map·community·my 등 화면 키로 구분",
  },
  {
    label: "비제보 활동",
    description:
      "상세 조회·지도 클릭·검색 클릭·배너 클릭·앱 세션 등 제보 외 이벤트 건수",
  },
  {
    label: "스탬프 시간 안/밖 제보",
    description:
      "KST 10:00–19:00(스탬프 지급 가능 시간) 안쪽 제보 수와 그 밖 제보 수",
  },
];

export function TrustFieldGlossary() {
  return (
    <details className="info-panel" open>
      <summary>
        <strong>지표 설명 (목록·상세·엑셀 공통)</strong>
      </summary>
      <ul style={{ marginTop: 8 }}>
        {TRUST_FIELD_GLOSSARY.map((f) => (
          <li key={f.label}>
            <strong>{f.label}</strong> — {f.description}
          </li>
        ))}
      </ul>
      <p className="muted xs" style={{ marginTop: 8 }}>
        목록의 「같은매장 간격(중앙)」= 같은 매장 연속 제보 간격의{" "}
        <strong>중앙값(분)</strong>, 「이동(중앙)」= 연속 제보 GPS 거리의{" "}
        <strong>중앙값(m)</strong>입니다. 점수·판정 필드는 없습니다.
      </p>
    </details>
  );
}
