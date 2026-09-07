/** 앱 미설치 시 스토어 리다이렉트 URL (Vercel env로 덮어쓰기 가능) */
const STORE_URL_IOS_DEFAULT = 'https://apps.apple.com/app/id6795425369';
const STORE_URL_ANDROID_DEFAULT =
  'https://play.google.com/store/apps/details?id=com.campuslunch.app&hl=ko';

function isIOSUserAgent(userAgent) {
  return /iPhone|iPad|iPod/i.test(userAgent || '');
}

function isAndroidUserAgent(userAgent) {
  return /Android/i.test(userAgent || '');
}

function isMobileUserAgent(userAgent) {
  const ua = userAgent || '';
  return isIOSUserAgent(ua) || isAndroidUserAgent(ua);
}

/**
 * UA 기준 스토어 URL.
 * - iOS → App Store
 * - Android → Play Store
 * - 그 외(데스크톱) → null (양쪽 버튼 랜딩)
 */
function resolveStoreUrl(userAgent) {
  const ua = userAgent || '';
  if (isIOSUserAgent(ua)) {
    const fromEnv = process.env.STORE_URL_IOS;
    return (fromEnv && fromEnv.trim()) || STORE_URL_IOS_DEFAULT;
  }
  if (isAndroidUserAgent(ua)) {
    const fromEnv = process.env.STORE_URL_ANDROID;
    return (fromEnv && fromEnv.trim()) || STORE_URL_ANDROID_DEFAULT;
  }
  return null;
}

function storeButtonLabel(userAgent) {
  if (isIOSUserAgent(userAgent)) return 'App Store에서 설치';
  if (isAndroidUserAgent(userAgent)) return 'Play Store에서 설치';
  return '스토어에서 설치';
}

/** 카톡 인앱브라우저 등에서 302가 막힐 때 — HTML + 직접 스토어 링크 */
function sendStoreLandingPage(req, res, { title = '캠퍼스런치' } = {}) {
  const ua = req.headers['user-agent'] || '';
  const storeUrl = resolveStoreUrl(ua);
  const safeTitle = String(title).replace(/[<>&"']/g, '');
  const iosUrl = (process.env.STORE_URL_IOS || '').trim() || STORE_URL_IOS_DEFAULT;
  const androidUrl =
    (process.env.STORE_URL_ANDROID || '').trim() || STORE_URL_ANDROID_DEFAULT;

  const autoRedirectScript = storeUrl
    ? `<meta http-equiv="refresh" content="0;url=${storeUrl.replace(/"/g, '%22')}" />
  <script>setTimeout(function(){ location.replace(${JSON.stringify(storeUrl)}); }, 100);</script>`
    : '';

  const primaryButton = storeUrl
    ? `<a class="btn" href="${storeUrl.replace(/"/g, '%22')}">${storeButtonLabel(ua)}</a>`
    : `<a class="btn" href="${iosUrl.replace(/"/g, '%22')}">App Store</a>
    <a class="btn outline" href="${androidUrl.replace(/"/g, '%22')}">Play Store</a>`;

  const html = `<!doctype html>
<html lang="ko">
<head>
  <meta charset="utf-8" />
  <meta name="viewport" content="width=device-width, initial-scale=1" />
  <title>${safeTitle}</title>
  ${autoRedirectScript}
  <style>
    body { font-family: -apple-system, sans-serif; text-align: center; padding: 48px 20px; color: #374151; }
    a.btn { display: inline-block; margin: 12px 8px 0; padding: 14px 28px; background: #111; color: #fff;
      text-decoration: none; border-radius: 12px; font-weight: 700; font-size: 16px; }
    a.btn.outline { background: #fff; color: #111; border: 2px solid #111; }
    p { line-height: 1.6; }
  </style>
</head>
<body>
  <p><strong>${safeTitle}</strong></p>
  <p>${storeUrl ? '앱으로 이동 중이에요…' : '사용하는 기기의 스토어에서 설치해주세요.'}</p>
  ${primaryButton}
</body>
</html>`;
  res.statusCode = 200;
  res.setHeader('Content-Type', 'text/html; charset=utf-8');
  res.setHeader('Cache-Control', 'no-store');
  res.end(html);
}

function redirectToStore(req, res) {
  const ua = req.headers['user-agent'] || '';
  const storeUrl = resolveStoreUrl(ua);

  // 모바일·카톡 인앱 / 데스크톱 모두 HTML 랜딩(탭 가능한 스토어 링크).
  // 모바일은 자동 리다이렉트, 데스크톱은 App Store + Play Store 둘 다 표시.
  if (isMobileUserAgent(ua) || !storeUrl) {
    sendStoreLandingPage(req, res);
    return;
  }

  res.statusCode = 302;
  res.setHeader('Location', storeUrl);
  res.setHeader('Cache-Control', 'no-store');
  res.end();
}

module.exports = {
  STORE_URL_IOS_DEFAULT,
  STORE_URL_ANDROID_DEFAULT,
  resolveStoreUrl,
  isIOSUserAgent,
  isAndroidUserAgent,
  isMobileUserAgent,
  sendStoreLandingPage,
  redirectToStore,
};
