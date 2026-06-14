export interface Gifticon {
  id: string;
  brand: string;
  productName: string;
  imageUrl: string;
  expiresAt: Date | null;
  status: "unassigned" | "assigned" | "expired" | string;
  assignedUserId: string | null;
  assignedAt: Date | null;
  createdAt: Date;
}

export function gifticonStatusLabel(status: string): string {
  switch (status) {
    case "assigned":
      return "배정됨";
    case "expired":
      return "만료";
    default:
      return "미배정";
  }
}
