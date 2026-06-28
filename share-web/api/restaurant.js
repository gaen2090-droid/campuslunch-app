// 앱이 없는 사용자를 위한 최소 리다이렉트.
// App Links/Universal Links 설정 후에는 앱이 설치된 사용자는 이 페이지를 거치지 않고
// 바로 앱으로 연결되며, 이 핸들러는 앱이 없는 사용자에게만 도달한다.
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

  res.statusCode = 200;
  res.setHeader('Content-Type', 'text/plain; charset=utf-8');
  res.end('캠퍼스런치 앱이 곧 출시됩니다.');
};
