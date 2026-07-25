// 구형 경로 /restaurant/:id → 안내 문구
module.exports = async (req, res) => {
  const id = req.query.id || '';
  res.statusCode = 200;
  res.setHeader('Content-Type', 'text/plain; charset=utf-8');
  res.end(`캠퍼스런치 앱에서 열어주세요. (restaurant ${id})`);
};
