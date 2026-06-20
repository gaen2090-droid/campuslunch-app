const { createClient } = require('@supabase/supabase-js');

const STORE_URL_ANDROID = process.env.STORE_URL_ANDROID || '';
const STORE_URL_IOS = process.env.STORE_URL_IOS || '';

const STATUS_LABEL = {
  1: '여유로움',
  2: '약간혼잡',
  3: '자리없음',
};
const STATUS_COLOR = {
  여유로움: '#4C9C2A',
  약간혼잡: '#D97706',
  자리없음: '#EF4444',
  영업안함: '#9CA3AF',
};
const STATUS_BG = {
  여유로움: '#F3F8F0',
  약간혼잡: '#FFFBEB',
  자리없음: '#FEF2F2',
  영업안함: '#F3F4F6',
};

function escapeHtml(str) {
  return String(str ?? '').replace(/[&<>"']/g, (c) => ({
    '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;',
  }[c]));
}

function formatAge(updatedAt) {
  if (!updatedAt) return null;
  const diffMs = Date.now() - new Date(updatedAt).getTime();
  const minutes = Math.max(0, Math.floor(diffMs / 60000));
  if (minutes <= 0) return '방금 전';
  if (minutes < 60) return `${minutes}분 전`;
  const hours = Math.floor(minutes / 60);
  if (hours < 24) return `${hours}시간 전`;
  return `${Math.floor(hours / 24)}일 전`;
}

function renderPage({ restaurant, statusLabel, statusAge, notFound = false, restaurantId = '' }) {
  const appBtn = `
    <a class="app-btn" href="#" id="open-app-btn">앱에서 보기</a>
    <p class="app-hint">설치되어 있지 않다면 스토어로 연결돼요.</p>
  `;

  if (notFound) {
    return `<!doctype html><html lang="ko"><head>
      <meta charset="utf-8" />
      <meta name="viewport" content="width=device-width, initial-scale=1" />
      <title>캠퍼스런치</title>
      ${baseStyle()}
      </head><body>
      <div class="card">
        <div class="logo">🍙</div>
        <h1>매장을 찾을 수 없어요</h1>
        <p class="sub">링크가 잘못됐거나 매장이 삭제됐을 수 있어요.</p>
        ${appBtn}
      </div>
      ${appBtnScript(restaurantId)}
      </body></html>`;
  }

  const name = escapeHtml(restaurant.name);
  const area = escapeHtml(restaurant.area || '');
  const category = escapeHtml(restaurant.category || '');
  const imageUrl = restaurant.image_url ? escapeHtml(restaurant.image_url) : '';
  const color = STATUS_COLOR[statusLabel] || '#9CA3AF';
  const bg = STATUS_BG[statusLabel] || '#F3F4F6';
  const statusText = statusAge ? `${statusLabel} · ${statusAge}` : statusLabel;
  const ogDescription = `${name} 지금 ${statusText}`;

  return `<!doctype html><html lang="ko"><head>
    <meta charset="utf-8" />
    <meta name="viewport" content="width=device-width, initial-scale=1" />
    <title>${name} - 캠퍼스런치</title>
    <meta property="og:title" content="${name} - 캠퍼스런치" />
    <meta property="og:description" content="${escapeHtml(ogDescription)}" />
    ${imageUrl ? `<meta property="og:image" content="${imageUrl}" />` : ''}
    ${baseStyle()}
    </head><body>
    <div class="card">
      ${imageUrl
        ? `<img class="photo" src="${imageUrl}" alt="${name}" />`
        : `<div class="logo">🍙</div>`}
      <h1>${name}</h1>
      <p class="sub">${area}${area && category ? ' · ' : ''}${category}</p>
      <div class="status" style="color:${color};background:${bg}">${escapeHtml(statusText)}</div>
      ${appBtn}
    </div>
    ${appBtnScript(restaurantId)}
    </body></html>`;
}

function baseStyle() {
  return `<style>
    * { box-sizing: border-box; }
    body {
      margin: 0; min-height: 100vh; display: flex; align-items: center; justify-content: center;
      background: #F3F8F0; font-family: -apple-system, "Pretendard", sans-serif;
    }
    .card {
      width: 100%; max-width: 360px; margin: 20px; background: #fff; border-radius: 28px;
      padding: 32px 24px; text-align: center; box-shadow: 0 8px 30px rgba(0,0,0,0.08);
    }
    .logo { font-size: 56px; margin-bottom: 8px; }
    .photo { width: 100%; height: 180px; object-fit: cover; border-radius: 20px; margin-bottom: 16px; }
    h1 { font-size: 20px; font-weight: 900; color: #111827; margin: 0 0 4px; }
    .sub { font-size: 13px; color: #9CA3AF; margin: 0 0 16px; }
    .status {
      display: inline-block; padding: 8px 16px; border-radius: 20px;
      font-size: 14px; font-weight: 900; margin-bottom: 24px;
    }
    .app-btn {
      display: block; background: #9ECA8B; color: #111827; text-decoration: none;
      font-weight: 900; font-size: 15px; padding: 14px; border-radius: 14px;
    }
    .app-hint { font-size: 12px; color: #9CA3AF; margin: 10px 0 0; }
  </style>`;
}

function appBtnScript(restaurantId) {
  return `<script>
    (function () {
      var btn = document.getElementById('open-app-btn');
      if (!btn) return;
      var androidStore = ${JSON.stringify(STORE_URL_ANDROID)};
      var iosStore = ${JSON.stringify(STORE_URL_IOS)};
      var ua = navigator.userAgent || '';
      var isIOS = /iPhone|iPad|iPod/i.test(ua);
      var storeUrl = isIOS ? iosStore : androidStore;
      btn.addEventListener('click', function (e) {
        e.preventDefault();
        var restaurantId = ${JSON.stringify(restaurantId)};
        window.location.href = 'campuslunch://restaurant/' + restaurantId;
        setTimeout(function () {
          if (storeUrl) window.location.href = storeUrl;
        }, 800);
      });
    })();
  </script>`;
}

module.exports = async (req, res) => {
  const id = (req.query.id || '').toString();
  if (!id) {
    res.statusCode = 400;
    res.setHeader('Content-Type', 'text/html; charset=utf-8');
    res.end(renderPage({ notFound: true }));
    return;
  }

  const supabaseUrl = process.env.SUPABASE_URL;
  const supabaseKey = process.env.SUPABASE_ANON_KEY;
  if (!supabaseUrl || !supabaseKey) {
    res.statusCode = 500;
    res.end('Supabase 설정이 없어요.');
    return;
  }
  const supabase = createClient(supabaseUrl, supabaseKey);

  const { data: restaurant } = await supabase
    .from('restaurants')
    .select('id, name, area, category, image_url, is_active')
    .eq('id', id)
    .eq('is_active', true)
    .maybeSingle();

  if (!restaurant) {
    res.statusCode = 404;
    res.setHeader('Content-Type', 'text/html; charset=utf-8');
    res.end(renderPage({ notFound: true, restaurantId: id }));
    return;
  }

  const { data: status } = await supabase
    .from('crowd_status')
    .select('display_level, updated_at')
    .eq('restaurant_id', id)
    .maybeSingle();

  const statusLabel = status ? STATUS_LABEL[status.display_level] || '여유로움' : '제보없음';
  const statusAge = status ? formatAge(status.updated_at) : null;

  const html = renderPage({ restaurant, statusLabel, statusAge, restaurantId: id });

  res.statusCode = 200;
  res.setHeader('Content-Type', 'text/html; charset=utf-8');
  res.setHeader('Cache-Control', 's-maxage=60, stale-while-revalidate');
  res.end(html);
};
