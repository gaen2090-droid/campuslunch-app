export interface OwnerApplication {
  id: string;
  userId: string;
  userNickname: string;
  restaurantId: string;
  restaurantName: string;
  phone: string;
  email: string;
  licensePaths: string[];
  status: "pending" | "approved" | "rejected" | string;
  rejectReason: string | null;
  /** 승인 시 앱 푸시로 알림받기를 신청 시점에 선택했는지 (승인 즉시 자동 발송) */
  notifyPush: boolean;
  /** 승인 시 문자로 알림받기를 신청 시점에 선택했는지 (자동 발송 없음 — phone 번호로 수동 발송) */
  notifySms: boolean;
  createdAt: Date;
  reviewedAt: Date | null;
}

export function ownerApplicationStatusLabel(status: string): string {
  switch (status) {
    case "approved":
      return "승인됨";
    case "rejected":
      return "반려됨";
    default:
      return "심사중";
  }
}
