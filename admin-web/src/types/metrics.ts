export interface DashboardMetrics {
  dauToday: number;
  mau: number;
  dailyDau: number[];
  monthlyMau: number[];
  todayReports: number;
  weekReports: number;
  bannerClickRate: number;
  dailyClickRates: number[];
  pushOpenRate: number;
  dailyPushOpenRates: number[];
  topReporters: [string, number][];
  todayByRestaurant: Record<string, number>;
  weekByRestaurant: Record<string, number>;
  todayGifticonsAssigned: number;
  dailyGifticonsAssigned: number[];
  monthGifticonsAssigned: number;
}

export interface RestaurantRow {
  id: string;
  name: string;
}
