export interface MenuItem {
  name: string;
  price: number;
}

export interface AdminRestaurant {
  id: string;
  name: string;
  category: string;
  area: string;
  address: string;
  status: string;
  hours: string;
  imageUrl: string;
  latitude: number;
  longitude: number;
  reports: Record<string, number>;
  menu: MenuItem[];
  ownerCode: string;
  ownerRegistered: boolean;
  manualRank: number;
  popularityScore: number;
  crowdBaseSource: string;
  crowdConfidence: string;
  hasCrowdUpdate: boolean;
  updated: number;
}

export interface RecentCrowdReport {
  id: string;
  status: string;
  source: string;
  createdAt: Date;
  userId: string | null;
}

export interface RestaurantFormData {
  name: string;
  area: string;
  category: string;
  address: string;
  hours: string;
  menu?: MenuItem[];
  image_url?: string;
  latitude?: number;
  longitude?: number;
  google_place_id?: string;
  hours_display?: string;
  hours_periods?: Record<string, unknown>[];
}
