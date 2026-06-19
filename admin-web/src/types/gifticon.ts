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
    case "used":
      return "사용됨";
    case "expired":
      return "만료";
    default:
      return "미배정";
  }
}

export function parseGifticonCsv(text: string): Array<{
  brand: string;
  product_name: string;
  image_url: string;
  expires_at?: string;
  coupon_code?: string;
}> {
  const lines = text
    .split("\n")
    .map((l) => l.trim())
    .filter(Boolean);
  if (lines.length < 2) return [];

  const header = lines[0].split(",").map((h) => h.trim().toLowerCase());
  const idx = (name: string) => header.indexOf(name);
  const brandIdx = idx("brand");
  const productIdx = idx("product_name");
  const imageIdx = idx("image_url");
  if (brandIdx < 0 || productIdx < 0 || imageIdx < 0) {
    throw new Error("CSV 헤더: brand, product_name, image_url 필수");
  }
  const expiresIdx = idx("expires_at");
  const codeIdx = idx("coupon_code");

  const rows: Array<{
    brand: string;
    product_name: string;
    image_url: string;
    expires_at?: string;
    coupon_code?: string;
  }> = [];

  for (let i = 1; i < lines.length; i++) {
    const cols = lines[i].split(",").map((c) => c.trim());
    const cell = (index: number) =>
      index >= 0 && index < cols.length ? cols[index] : "";
    const brand = cell(brandIdx);
    const product_name = cell(productIdx);
    const image_url = cell(imageIdx);
    if (!brand || !product_name || !image_url) continue;
    rows.push({
      brand,
      product_name,
      image_url,
      ...(expiresIdx >= 0 && cell(expiresIdx)
        ? { expires_at: cell(expiresIdx) }
        : {}),
      ...(codeIdx >= 0 && cell(codeIdx)
        ? { coupon_code: cell(codeIdx) }
        : {}),
    });
  }
  return rows;
}
