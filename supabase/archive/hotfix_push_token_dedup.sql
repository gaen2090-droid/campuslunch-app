-- 커뮤니티 댓글 알림 중복 발송 수정 (Dashboard → SQL Editor → Run)
--
-- 증상: 댓글 알림이 두 번(또는 그 이상) 옴.
-- 원인: upsert_push_token이 (user_id, token) 단위로만 upsert해서, 같은 유저의
--       FCM 토큰이 재발급(재설치·OS 업데이트 등)될 때마다 옛 토큰이 지워지지
--       않고 새 row로 계속 쌓였음. list_community_comment_push_recipients는
--       유저당 살아있는 모든 토큰에 join하므로, 죽은/구버전 토큰 개수만큼
--       FCM이 중복 발송됨. (실측: 한 유저에게 토큰 4개 누적된 사례 확인)
--
-- 정책: 기기당(플랫폼당) 토큰 1개만 유지. 같은 유저가 ios/android를 동시에
--       쓰면 각각 알림을 받되(정상 동작), 같은 플랫폼에서 토큰이 갱신되면
--       예전 토큰은 새 토큰으로 교체(삭제 후 insert)한다.

-- 1) upsert_push_token: (user_id, platform) 기준으로 예전 토큰을 지우고 새로 삽입
create or replace function public.upsert_push_token(
  p_token text,
  p_platform text
)
returns void
language plpgsql
security definer
set search_path to 'public'
as $$
declare
  uid uuid := auth.uid();
  plat text := coalesce(nullif(trim(p_platform), ''), 'unknown');
begin
  if uid is null then
    raise exception 'NOT_AUTHENTICATED';
  end if;
  if trim(coalesce(p_token, '')) = '' then
    raise exception 'TOKEN_REQUIRED';
  end if;
  if plat not in ('ios', 'android', 'web', 'unknown') then
    plat := 'unknown';
  end if;

  -- 동일 토큰이 다른 계정에 있으면 제거 (기기 재로그인)
  delete from public.user_push_tokens
  where token = trim(p_token) and user_id <> uid;

  -- 같은 유저·같은 플랫폼의 예전 토큰(값이 바뀐 것) 제거 — 기기당 1개만 유지
  delete from public.user_push_tokens
  where user_id = uid
    and platform = plat
    and token <> trim(p_token);

  insert into public.user_push_tokens (user_id, token, platform, updated_at)
  values (uid, trim(p_token), plat, now())
  on conflict (user_id, token) do update
    set platform = excluded.platform,
        updated_at = now();
end;
$$;

-- 2) 기존에 이미 쌓인 중복 토큰 정리: 유저·플랫폼별로 가장 최근(updated_at) 1개만 남김
delete from public.user_push_tokens t
using (
  select id,
         row_number() over (
           partition by user_id, platform
           order by updated_at desc
         ) as rn
  from public.user_push_tokens
) ranked
where t.id = ranked.id
  and ranked.rn > 1;
