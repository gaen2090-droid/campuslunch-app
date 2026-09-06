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

export interface OpsMetrics {
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

export function parseOpsMetrics(map: Record<string, unknown>): OpsMetrics {
  return {
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
  };
}
