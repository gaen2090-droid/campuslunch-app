const { redirectToStore } = require('../lib/store');

// 구형 경로 /restaurant/:id → 스토어 리다이렉트
module.exports = async (req, res) => {
  redirectToStore(req, res);
};
