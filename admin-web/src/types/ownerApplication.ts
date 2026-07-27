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
