/** CSV/텍스트 파일 인코딩 자동 감지 (UTF-8 · CP949/Windows-949) */

function countHangul(text: string): number {
  return (text.match(/[\uAC00-\uD7A3]/g) ?? []).length;
}

function countReplacement(text: string): number {
  return (text.match(/\uFFFD/g) ?? []).length;
}

function stripUtf8Bom(bytes: Uint8Array): Uint8Array {
  if (
    bytes.length >= 3 &&
    bytes[0] === 0xef &&
    bytes[1] === 0xbb &&
    bytes[2] === 0xbf
  ) {
    return bytes.subarray(3);
  }
  return bytes;
}

function decodeWith(label: string, bytes: Uint8Array): string | null {
  try {
    return new TextDecoder(label).decode(bytes);
  } catch {
    return null;
  }
}

function scoreDecodedText(text: string): number {
  const hangul = countHangul(text);
  const bad = countReplacement(text);
  return hangul * 10 - bad * 100;
}

/**
 * Excel(한국) 기본 CSV는 CP949인 경우가 많음.
 * UTF-8로만 읽으면 `�Ƹ޸�ī��` 같은 mojibake가 생김.
 */
export function decodeTextBytes(bytes: Uint8Array): string {
  const noBom = stripUtf8Bom(bytes);

  const candidates: string[] = [];
  const utf8 = decodeWith("utf-8", noBom);
  if (utf8 != null) candidates.push(utf8);

  for (const label of ["windows-949", "euc-kr"]) {
    const decoded = decodeWith(label, bytes);
    if (decoded != null) candidates.push(decoded);
  }

  if (candidates.length === 0) {
    return new TextDecoder().decode(bytes);
  }

  let best = candidates[0];
  let bestScore = scoreDecodedText(best);
  for (let i = 1; i < candidates.length; i++) {
    const score = scoreDecodedText(candidates[i]);
    if (score > bestScore) {
      bestScore = score;
      best = candidates[i];
    }
  }
  return best;
}

export async function readTextFileAutoEncoding(file: File): Promise<string> {
  const buffer = await file.arrayBuffer();
  return decodeTextBytes(new Uint8Array(buffer));
}
