import { readdirSync, readFileSync, writeFileSync, mkdirSync, existsSync, rmSync } from 'node:fs';
import { join, dirname } from 'node:path';
import { fileURLToPath } from 'node:url';
import { marked } from 'marked';

const __dirname = dirname(fileURLToPath(import.meta.url));
const srcDir = join(__dirname, '..', 'content');
const outDir = join(__dirname, '..', 'dist');

// slug(파일명) -> { title, label } — 목록 페이지 표시용
const DOCS = [
  { file: 'PRIVACY_POLICY.md', slug: 'privacy-policy', label: '개인정보 처리방침' },
  { file: 'TERMS_OF_SERVICE.md', slug: 'terms-of-service', label: '이용약관' },
  { file: 'REPORT_OPERATION_POLICY.md', slug: 'report-operation-policy', label: '제보 운영정책' },
  { file: 'REWARD_POLICY.md', slug: 'reward-policy', label: '리워드 지급 정책' },
  { file: 'LOCATION_TERMS.md', slug: 'location-terms', label: '위치기반서비스 이용약관' },
  { file: 'COMMUNITY_POLICY.md', slug: 'community-policy', label: '커뮤니티 이용정책' },
  { file: 'BUSINESS_INFO.md', slug: 'business-info', label: '사업자 정보' },
];

if (existsSync(outDir)) rmSync(outDir, { recursive: true });
mkdirSync(outDir, { recursive: true });

const page = (title, bodyHtml) => `<!doctype html>
<html lang="ko">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>${title} · 캠퍼스런치</title>
<style>
  :root { color-scheme: light dark; }
  body {
    font-family: -apple-system, BlinkMacSystemFont, "Pretendard", "Malgun Gothic", sans-serif;
    max-width: 720px;
    margin: 0 auto;
    padding: 32px 20px 80px;
    line-height: 1.7;
    color: #111827;
    background: #fff;
  }
  @media (prefers-color-scheme: dark) {
    body { color: #E5E7EB; background: #0B0F0C; }
    a { color: #9ECA8B; }
    table, th, td { border-color: #374151 !important; }
    hr { border-color: #374151 !important; }
  }
  h1 { font-size: 22px; font-weight: 900; }
  h2 { font-size: 17px; font-weight: 800; margin-top: 32px; }
  table { border-collapse: collapse; width: 100%; margin: 16px 0; }
  th, td { border: 1px solid #E5E7EB; padding: 8px 10px; text-align: left; font-size: 14px; }
  hr { border: none; border-top: 1px solid #E5E7EB; margin: 24px 0; }
  a { color: #5E8C4A; }
  .back { display: inline-block; margin-bottom: 20px; font-size: 14px; }
</style>
</head>
<body>
<a class="back" href="/">← 전체 목록</a>
${bodyHtml}
</body>
</html>
`;

const indexItems = [];

for (const doc of DOCS) {
  const srcPath = join(srcDir, doc.file);
  const md = readFileSync(srcPath, 'utf8');
  const html = marked.parse(md);
  writeFileSync(join(outDir, `${doc.slug}.html`), page(doc.label, html));
  indexItems.push(doc);
}

const indexHtml = `<!doctype html>
<html lang="ko">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>약관 및 정책 · 캠퍼스런치</title>
<style>
  :root { color-scheme: light dark; }
  body {
    font-family: -apple-system, BlinkMacSystemFont, "Pretendard", "Malgun Gothic", sans-serif;
    max-width: 480px;
    margin: 0 auto;
    padding: 40px 20px 80px;
    color: #111827;
    background: #fff;
  }
  @media (prefers-color-scheme: dark) {
    body { color: #E5E7EB; background: #0B0F0C; }
    li a { background: #151A17 !important; border-color: #374151 !important; }
  }
  h1 { font-size: 22px; font-weight: 900; margin-bottom: 24px; }
  ul { list-style: none; padding: 0; margin: 0; }
  li { margin-bottom: 10px; }
  li a {
    display: block;
    padding: 14px 16px;
    border: 1px solid #E5E7EB;
    border-radius: 12px;
    text-decoration: none;
    color: inherit;
    font-weight: 600;
    font-size: 15px;
  }
</style>
</head>
<body>
<h1>캠퍼스런치 약관 및 정책</h1>
<ul>
${indexItems.map((d) => `  <li><a href="/${d.slug}.html">${d.label}</a></li>`).join('\n')}
</ul>
</body>
</html>
`;

writeFileSync(join(outDir, 'index.html'), indexHtml);

console.log(`Built ${indexItems.length} legal pages into ${outDir}`);
