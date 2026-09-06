export interface RewardSpendUserRow {
  userId: string;
  nickname: string;
  email: string;
  rewardCount: number;
  amountKrw: number;
}

export interface RewardSpendReport {
  totalRewardCount: number;
  totalAmountKrw: number;
  attributedCount: number;
  unattributedCount: number;
  missingFaceValueCount: number;
  users: RewardSpendUserRow[];
}

