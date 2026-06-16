export interface AppFeedback {
  id: string;
  category: string;
  content: string;
  userId: string | null;
  createdAt: Date;
}
