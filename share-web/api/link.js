// 앱 미설치 시 App Link 폴백 (스토어 URL이 있으면 리다이렉트)
const STORE_URL_ANDROID = process.env.STORE_URL_ANDROID || '';
const STORE_URL_IOS = process.env.STORE_URL_IOS || '';

module.exports = async (req, res) => {
  const ua = req.headers['user-agent'] || '';
  const isIOS = /iPhone|iPad|iPod/i.test(ua);
  const storeUrl = isIOS ? STORE_URL_IOS : STORE_URL_ANDROID;

  if (storeUrl) {
    res.statusCode = 302;
    res.setHeader('Location', storeUrl);
    res.end();
    return;
  }

  const kind = req.query.kind || 'home';
  const no = req.query.no || '';
  res.statusCode = 200;
  res.setHeader('Content-Type', 'text/plain; charset=utf-8');
  res.end(`캠퍼스런치 앱에서 열어주세요. (${kind}${no ? ` #${no}` : ''})`);
};
