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
  /** 액면가(원). 미입력 시 null */
  faceValue: number | null;
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

const HEADER_ALIASES: Record<string, string> = {
  productname: "product_name",
  product: "product_name",
  imageurl: "image_url",
  image: "image_url",
  expires: "expires_at",
  expire: "expires_at",
  expiry: "expires_at",
  expiration_date: "expires_at",
  expiration: "expires_at",
  couponcode: "coupon_code",
  coupon: "coupon_code",
  code: "coupon_code",
  facevalue: "face_value",
  amount: "face_value",
  price: "face_value",
  액수: "face_value",
  금액: "face_value",
};

function stripBom(text: string): string {
  return text.startsWith("\uFEFF") ? text.slice(1) : text;
}

function normalizeHeader(raw: string): string {
  let h = raw.trim();
  if (h.startsWith("\uFEFF")) h = h.slice(1).trim();
  if (h.length >= 2 && h.startsWith('"') && h.endsWith('"')) {
    h = h.slice(1, -1).trim();
  }
  h = h.toLowerCase().replace(/[\s-]+/g, "_").replace(/_+/g, "_");
  h = h.replace(/^_|_$/g, "");
  return HEADER_ALIASES[h] ?? h;
}

function detectDelimiter(line: string): string {
  const commas = (line.match(/,/g) ?? []).length;
  const semis = (line.match(/;/g) ?? []).length;
  const tabs = (line.match(/\t/g) ?? []).length;
  if (tabs > 0 && tabs >= commas && tabs >= semis) return "\t";
  if (semis > commas) return ";";
  return ",";
}

function unquoteCell(cell: string): string {
  const trimmed = cell.trim();
  if (trimmed.length >= 2 && trimmed.startsWith('"') && trimmed.endsWith('"')) {
    return trimmed.slice(1, -1).replace(/""/g, '"');
  }
  return trimmed;
}

function parseQuotedCsvLine(line: string): string[] {
  const out: string[] = [];
  let buf = "";
  let inQuotes = false;
  for (let i = 0; i < line.length; i++) {
    const ch = line[i];
    if (ch === '"') {
      if (inQuotes && line[i + 1] === '"') {
        buf += '"';
        i++;
        continue;
      }
      inQuotes = !inQuotes;
      continue;
    }
    if (ch === "," && !inQuotes) {
      out.push(unquoteCell(buf));
      buf = "";
      continue;
    }
    buf += ch;
  }
  out.push(unquoteCell(buf));
  return out;
}

function parseLine(line: string, delimiter: string): string[] {
  if (delimiter === ",") return parseQuotedCsvLine(line);
  return line.split(delimiter).map((c) => unquoteCell(c));
}

export function parseGifticonCsv(text: string): Array<{
  brand: string;
  product_name: string;
  image_url: string;
  expires_at?: string;
  coupon_code?: string;
  face_value?: number;
}> {
  const lines = stripBom(text)
    .split(/\r?\n/)
    .map((l) => l.trim())
    .filter(Boolean);
  if (lines.length < 2) return [];

  const delimiter = detectDelimiter(lines[0]);
  const header = parseLine(lines[0], delimiter).map(normalizeHeader);
  const idx = (name: string) => header.indexOf(name);
  const brandIdx = idx("brand");
  const productIdx = idx("product_name");
  const imageIdx = idx("image_url");
  if (brandIdx < 0 || productIdx < 0 || imageIdx < 0) {
    throw new Error(
      `CSV 헤더: brand, product_name, image_url 필수 (인식된 헤더: ${header.join(", ")})`,
    );
  }
  const expiresIdx = idx("expires_at");
  const codeIdx = idx("coupon_code");
  const faceIdx = idx("face_value");

  const rows: Array<{
    brand: string;
    product_name: string;
    image_url: string;
    expires_at?: string;
    coupon_code?: string;
    face_value?: number;
  }> = [];

  for (let i = 1; i < lines.length; i++) {
    const cols = parseLine(lines[i], delimiter);
    const cell = (index: number) =>
      index >= 0 && index < cols.length ? cols[index].trim() : "";
    const brand = cell(brandIdx);
    const product_name = cell(productIdx);
    const image_url = cell(imageIdx);
    if (!brand || !product_name || !image_url) continue;
    const faceRaw = faceIdx >= 0 ? cell(faceIdx).replace(/,/g, "") : "";
    const face_value =
      faceRaw !== "" ? Number.parseInt(faceRaw, 10) : undefined;
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
      ...(face_value != null && Number.isFinite(face_value)
        ? { face_value }
        : {}),
    });
  }
  return rows;
}

/** face_value 우선, 없으면 상품명의 "4,000원" / "5000원" 패턴 */
export function resolveGifticonFaceValueKrw(
  faceValue: number | null | undefined,
  productName: string,
): number {
  if (typeof faceValue === "number" && Number.isFinite(faceValue) && faceValue > 0) {
    return Math.trunc(faceValue);
  }
  const m = productName.match(/(\d{1,3}(?:,\d{3})+|\d+)\s*원/);
  if (!m?.[1]) return 0;
  return Number.parseInt(m[1].replace(/,/g, ""), 10) || 0;
}
