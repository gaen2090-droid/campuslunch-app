export interface MenuItem {
  name: string;
  price: number;
}

export interface AdminRestaurant {
  id: string;
  linkNo: number;
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
  ownerId: string | null;
  manualRank: number;
  popularityScore: number;
  crowdBaseSource: string;
  crowdConfidence: string;
  hasCrowdUpdate: boolean;
  updated: number;
  isActive: boolean;
  /** 제보 대상 매장 여부. false면 맛집컬렉션 전용(혼잡도 제보 기능 없음). */
  crowdEnabled: boolean;
  /** 사장님이 직접 등록한 메뉴 사진 (최대 3장) */
  menuPhotoUrls?: string[];
  /** 대표사진(imageUrl) 출처. 'owner' | 'google' */
  imageSource?: string;
  /** 사장님이 직접 입력한 매장 공지 (최대 500자) */
  ownerNotice?: string;
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
  kakao_place_id?: string;
  google_place_id?: string;
  hours_display?: string;
  hours_periods?: Record<string, unknown>[];
  menu_photo_urls?: string[];
  image_source?: string;
  owner_notice?: string;
  /** 제보 대상 매장 여부. 기본 true. false로 등록하면 맛집컬렉션 전용 매장이 된다. */
  crowd_enabled?: boolean;
}
