/** 앱 미설치 시 스토어 리다이렉트 URL (Vercel env로 덮어쓰기 가능) */
const STORE_URL_IOS_DEFAULT =
  'https://apps.apple.com/app/id6795425369';
const STORE_URL_ANDROID_DEFAULT =
  'https://play.google.com/store/apps/details?id=com.campuslunch.app';

function resolveStoreUrl(userAgent) {
  const ua = userAgent || '';
  const isIOS = /iPhone|iPad|iPod/i.test(ua);
  const fromEnv = isIOS
    ? process.env.STORE_URL_IOS
    : process.env.STORE_URL_ANDROID;
  const fallback = isIOS ? STORE_URL_IOS_DEFAULT : STORE_URL_ANDROID_DEFAULT;
  return (fromEnv && fromEnv.trim()) || fallback;
}

function isMobileUserAgent(userAgent) {
  const ua = userAgent || '';
  return /iPhone|iPad|iPod|Android/i.test(ua);
}

/** 카톡 인앱브라우저 등에서 302가 막힐 때 — HTML + 직접 스토어 링크 */
function sendStoreLandingPage(req, res, { title = '캠퍼스런치' } = {}) {
  const storeUrl = resolveStoreUrl(req.headers['user-agent']);
  const safeTitle = String(title).replace(/[<>&"']/g, '');
  const safeStore = storeUrl.replace(/"/g, '%22');
  const html = `<!doctype html>
<html lang="ko">
<head>
  <meta charset="utf-8" />
  <meta name="viewport" content="width=device-width, initial-scale=1" />
  <title>${safeTitle}</title>
  <meta http-equiv="refresh" content="0;url=${safeStore}" />
  <style>
    body { font-family: -apple-system, sans-serif; text-align: center; padding: 48px 20px; color: #374151; }
    a.btn { display: inline-block; margin-top: 24px; padding: 14px 28px; background: #111; color: #fff;
      text-decoration: none; border-radius: 12px; font-weight: 700; font-size: 16px; }
    p { line-height: 1.6; }
  </style>
  <script>setTimeout(function(){ location.replace(${JSON.stringify(storeUrl)}); }, 100);</script>
</head>
<body>
  <p><strong>${safeTitle}</strong></p>
  <p>앱으로 이동 중이에요…</p>
  <a class="btn" href="${safeStore}">App Store / Play Store에서 설치</a>
</body>
</html>`;
  res.statusCode = 200;
  res.setHeader('Content-Type', 'text/html; charset=utf-8');
  res.setHeader('Cache-Control', 'no-store');
  res.end(html);
}

function redirectToStore(req, res) {
  const ua = req.headers['user-agent'] || '';
  // 모바일·카톡 인앱: HTML 랜딩(탭 가능한 스토어 링크). 데스크톱 curl 등: 302.
  if (isMobileUserAgent(ua)) {
    sendStoreLandingPage(req, res);
    return;
  }
  const storeUrl = resolveStoreUrl(ua);
  res.statusCode = 302;
  res.setHeader('Location', storeUrl);
  res.setHeader('Cache-Control', 'no-store');
  res.end();
}

module.exports = {
  STORE_URL_IOS_DEFAULT,
  STORE_URL_ANDROID_DEFAULT,
  resolveStoreUrl,
  isMobileUserAgent,
  sendStoreLandingPage,
  redirectToStore,
};
