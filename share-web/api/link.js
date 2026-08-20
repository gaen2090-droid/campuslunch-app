const { redirectToStore } = require('../lib/store');

// 앱 미설치·Universal Link 미동작 시 스토어로 리다이렉트
// /r/:no, /home, /coupons, /invite → vercel.json rewrite
module.exports = async (req, res) => {
  redirectToStore(req, res);
};
