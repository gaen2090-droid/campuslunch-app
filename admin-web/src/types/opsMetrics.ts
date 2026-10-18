export interface BannerRestaurantRow {
  restaurantId: string;
  name: string;
  impressions: number;
  clicks: number;
  ctr: number;
}

export interface PushDayRow {
  delivered: number;
  clicks: number;
}

export interface TopReferrerRow {
  userId: string;
  nickname: string;
  email: string;
  totalCount: number;
  last24hCount: number;
  last7dCount: number;
  lastReferredAt: Date | null;
}

export interface RecentReferralRow {
  id: string;
  createdAt: Date;
  referrerUserId: string;
  referrerNickname: string;
  referredUserId: string;
  referredNickname: string;
}

/** 점메추 요정/식당 룰렛 한 기능의 최근 7일 지표 (supabase/feature_analytics.sql) */
export interface FeatureStats {
  actions7d: Record<string, number>;
  actionsPrev7d: Record<string, number>;
  actionsToday: Record<string, number>;
  users7d: number;
  shareUsers7d: number;
  /** 결과 공유 클릭 ÷ 결과 노출 (%) */
  shareCtr7d: number;
  shareCtrPrev7d: number;
  daily7d: { resultShown: number; shareClicks: number }[];
}

export interface FeatureMetrics {
  fairy: FeatureStats;
  roulette: FeatureStats;
  /** 혼잡도 예측: 노출(impression) ÷ 클릭(click). shareCtr 자리에 클릭률이 들어온다. */
  prediction: FeatureStats;
}

export interface OpsMetrics {
  /** 기능 지표 SQL이 아직 적용되지 않았으면 null */
  featureMetrics: FeatureMetrics | null;
  bannerImpressions7d: number;
  bannerClicks7d: number;
  bannerCtr7d: number;
  bannerCtrPrev7d: number;
  bannerDailyCtr7d: number[];
  bannerDailyCtr30d: number[];
  bannerByRestaurant: BannerRestaurantRow[];

  pushDeliveredToday: number;
  pushClicksToday: number;
  pushOpenRateToday: number;
  pushDelivered7d: number;
  pushClicks7d: number;
  pushOpenRate7d: number;
  pushDaily7d: PushDayRow[];
  pushDaily30d: PushDayRow[];

  couponsToday: number;
  coupons7d: number;
  couponsTotal: number;
  uniqueRecipients: number;
  couponsInStock: number;
  dailyCoupons7d: number[];
  dailyCoupons30d: number[];
  couponsPerUserDist: Record<string, number>;
  stampDist: { under10: number; from10to19: number; over20: number };

  referralsToday: number;
  referrals7d: number;
  referralsTotal: number;
  uniqueReferrers: number;
  uniqueReferred: number;
  dailyReferrals7d: number[];
  dailyReferrals30d: number[];
  topReferrers: TopReferrerRow[];
  recentReferrals: RecentReferralRow[];
}

function parseNumberArray(value: unknown): number[] {
  if (!Array.isArray(value)) return [];
  return value.map((v) => (typeof v === "number" ? v : Number(v) || 0));
}

function parseBannerRows(value: unknown): BannerRestaurantRow[] {
  if (!Array.isArray(value)) return [];
  return value.map((raw) => {
    const row = raw as Record<string, unknown>;
    return {
      restaurantId: String(row.restaurant_id ?? ""),
      name: String(row.name ?? ""),
      impressions: Number(row.impressions ?? 0),
      clicks: Number(row.clicks ?? 0),
      ctr: Number(row.ctr ?? 0),
    };
  });
}

function parsePushDayRows(value: unknown): PushDayRow[] {
  if (!Array.isArray(value)) return [];
  return value.map((raw) => {
    const row = (raw ?? {}) as Record<string, unknown>;
    return {
      delivered: Number(row.delivered ?? 0),
      clicks: Number(row.clicks ?? 0),
    };
  });
}

function parseTopReferrers(value: unknown): TopReferrerRow[] {
  if (!Array.isArray(value)) return [];
  return value.map((raw) => {
    const row = raw as Record<string, unknown>;
    return {
      userId: String(row.user_id ?? ""),
      nickname: String(row.nickname ?? ""),
      email: String(row.email ?? ""),
      totalCount: Number(row.total_count ?? 0),
      last24hCount: Number(row.last_24h_count ?? 0),
      last7dCount: Number(row.last_7d_count ?? 0),
      lastReferredAt: row.last_referred_at
        ? new Date(String(row.last_referred_at))
        : null,
    };
  });
}

function parseRecentReferrals(value: unknown): RecentReferralRow[] {
  if (!Array.isArray(value)) return [];
  return value.map((raw) => {
    const row = raw as Record<string, unknown>;
    return {
      id: String(row.id ?? ""),
      createdAt: row.created_at ? new Date(String(row.created_at)) : new Date(),
      referrerUserId: String(row.referrer_user_id ?? ""),
      referrerNickname: String(row.referrer_nickname ?? ""),
      referredUserId: String(row.referred_user_id ?? ""),
      referredNickname: String(row.referred_nickname ?? ""),
    };
  });
}

function parseCountRecord(value: unknown): Record<string, number> {
  if (!value || typeof value !== "object" || Array.isArray(value)) return {};
  return Object.fromEntries(
    Object.entries(value as Record<string, unknown>).map(([k, v]) => [
      k,
      Number(v) || 0,
    ]),
  );
}

function parseFeatureStats(value: unknown): FeatureStats {
  const raw = (value ?? {}) as Record<string, unknown>;
  const daily = Array.isArray(raw.daily_7d) ? raw.daily_7d : [];
  return {
    actions7d: parseCountRecord(raw.actions_7d),
    actionsPrev7d: parseCountRecord(raw.actions_prev_7d),
    actionsToday: parseCountRecord(raw.actions_today),
    users7d: Number(raw.users_7d ?? 0),
    shareUsers7d: Number(raw.share_users_7d ?? 0),
    shareCtr7d: Number(raw.share_ctr_7d ?? 0),
    shareCtrPrev7d: Number(raw.share_ctr_prev_7d ?? 0),
    daily7d: daily.map((d) => {
      const row = (d ?? {}) as Record<string, unknown>;
      return {
        resultShown: Number(row.result_shown ?? 0),
        shareClicks: Number(row.share_clicks ?? 0),
      };
    }),
  };
}

export function parseFeatureMetrics(map: Record<string, unknown>): FeatureMetrics {
  return {
    fairy: parseFeatureStats(map.fairy),
    roulette: parseFeatureStats(map.roulette),
    prediction: parseFeatureStats(map.prediction),
  };
}

export function parseOpsMetrics(map: Record<string, unknown>): OpsMetrics {
  return {
    featureMetrics: null,
    bannerImpressions7d: Number(map.banner_impressions_7d ?? 0),
    bannerClicks7d: Number(map.banner_clicks_7d ?? 0),
    bannerCtr7d: Number(map.banner_ctr_7d ?? 0),
    bannerCtrPrev7d: Number(map.banner_ctr_prev_7d ?? 0),
    bannerDailyCtr7d: parseNumberArray(map.banner_daily_ctr_7d),
    bannerDailyCtr30d: parseNumberArray(map.banner_daily_ctr_30d),
    bannerByRestaurant: parseBannerRows(map.banner_by_restaurant),

    pushDeliveredToday: Number(map.push_delivered_today ?? 0),
    pushClicksToday: Number(map.push_clicks_today ?? 0),
    pushOpenRateToday: Number(map.push_open_rate_today ?? 0),
    pushDelivered7d: Number(map.push_delivered_7d ?? 0),
    pushClicks7d: Number(map.push_clicks_7d ?? 0),
    pushOpenRate7d: Number(map.push_open_rate_7d ?? 0),
    pushDaily7d: parsePushDayRows(map.push_daily_7d),
    pushDaily30d: parsePushDayRows(map.push_daily_30d),

    couponsToday: Number(map.coupons_today ?? 0),
    coupons7d: Number(map.coupons_7d ?? 0),
    couponsTotal: Number(map.coupons_total ?? 0),
    uniqueRecipients: Number(map.unique_recipients ?? 0),
    couponsInStock: Number(map.coupons_in_stock ?? 0),
    dailyCoupons7d: parseNumberArray(map.daily_coupons_7d),
    dailyCoupons30d: parseNumberArray(map.daily_coupons_30d),
    couponsPerUserDist:
      map.coupons_per_user_dist && typeof map.coupons_per_user_dist === "object"
        ? Object.fromEntries(
            Object.entries(map.coupons_per_user_dist as Record<string, unknown>).map(
              ([k, v]) => [k, Number(v) || 0],
            ),
          )
        : {},
    stampDist: (() => {
      const raw = (map.stamp_dist ?? {}) as Record<string, unknown>;
      return {
        under10: Number(raw["0_9"] ?? 0),
        from10to19: Number(raw["10_19"] ?? 0),
        over20: Number(raw["20_plus"] ?? 0),
      };
    })(),

    referralsToday: Number(map.referrals_today ?? 0),
    referrals7d: Number(map.referrals_7d ?? 0),
    referralsTotal: Number(map.referrals_total ?? 0),
    uniqueReferrers: Number(map.unique_referrers ?? 0),
    uniqueReferred: Number(map.unique_referred ?? 0),
    dailyReferrals7d: parseNumberArray(map.daily_referrals_7d),
    dailyReferrals30d: parseNumberArray(map.daily_referrals_30d),
    topReferrers: parseTopReferrers(map.top_referrers),
    recentReferrals: parseRecentReferrals(map.recent_referrals),
  };
}
