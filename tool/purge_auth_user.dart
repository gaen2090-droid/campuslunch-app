// ignore_for_file: avoid_print
/// 이메일로 Supabase 회원 완전 삭제 (auth.users + public.users + 연관 테이블)
///
///   dart run tool/purge_auth_user.dart --email=test@example.com
///
/// 최초 1회: Dashboard → SQL Editor → supabase/rpc_purge_user_by_email.sql 실행
import 'dart:io';

import 'package:supabase/supabase.dart';

Future<void> main(List<String> args) async {
  String? email;
  for (final a in args) {
    if (a.startsWith('--email=')) email = a.substring('--email='.length).trim();
  }
  if (email == null || email.isEmpty || !email.contains('@')) {
    stderr.writeln('사용법: dart run tool/purge_auth_user.dart --email=you@example.com');
    exit(1);
  }

  final secrets = await _loadEnv('.env.secrets');
  final fallback = await _loadEnv('.env');
  final url = secrets['SUPABASE_URL'] ?? fallback['SUPABASE_URL'] ?? '';
  final secret = secrets['SUPABASE_SECRET_KEY'] ?? '';
  if (url.isEmpty || secret.isEmpty) {
    stderr.writeln('`.env.secrets`에 SUPABASE_URL, SUPABASE_SECRET_KEY 필요');
    exit(1);
  }

  final client = SupabaseClient(url, secret);

  try {
    await client.rpc('purge_user_by_email', params: {'p_email': email});
    print('완료: $email (RPC purge_user_by_email). 앱에서 다시 회원가입하세요.');
    return;
  } catch (e) {
    stderr.writeln('[purge] RPC 실패 — rpc_purge_user_by_email.sql 을 Dashboard에서 먼저 실행하세요.');
    stderr.writeln('  $e');
    stderr.writeln('레거시 삭제(테이블별)로 재시도합니다…');
  }

  final normalized = email.toLowerCase();
  String? userId;
  var page = 1;
  while (userId == null) {
    final batch = await client.auth.admin.listUsers(page: page, perPage: 200);
    if (batch.isEmpty) break;
    for (final u in batch) {
      if (u.email?.toLowerCase() == normalized) {
        userId = u.id;
        break;
      }
    }
    if (batch.length < 200) break;
    page++;
  }

  if (userId == null) {
    print('auth.users 에 없음: $email (이미 삭제됨)');
    exit(0);
  }

  print('삭제 대상 auth id: $userId');

  await _deleteByUserId(client, 'bookmarks', userId);
  await _deleteByUserId(client, 'notification_settings', userId);
  await _deleteByUserId(client, 'user_devices', userId);
  await _deleteByUserId(client, 'crowd_reports', userId);
  await _deleteByUserId(client, 'analytics_events', userId);
  await _deleteByUserId(client, 'app_feedback', userId);
  await _deleteByUserId(client, 'owner_seat_updates', userId, column: 'owner_id');
  await _deleteByUserId(client, 'user_rewards', userId);
  await client
      .from('gifticons')
      .update({'assigned_user_id': null, 'assigned_at': null})
      .eq('assigned_user_id', userId);
  await client.from('restaurants').update({'owner_id': null}).eq('owner_id', userId);
  await client.from('users').delete().eq('id', userId);

  await client.auth.admin.deleteUser(userId);

  print('완료: $email (public + auth 삭제). 앱에서 다시 회원가입하세요.');
}

Future<void> _deleteByUserId(
  SupabaseClient client,
  String table,
  String userId, {
  String column = 'user_id',
}) async {
  try {
    await client.from(table).delete().eq(column, userId);
  } catch (e) {
    stderr.writeln('[purge] $table 삭제 스kip (테이블 없음 또는 오류): $e');
  }
}

Future<Map<String, String>> _loadEnv(String path) async {
  final file = File(path);
  if (!await file.exists()) return {};
  final map = <String, String>{};
  for (final line in await file.readAsLines()) {
    final t = line.trim();
    if (t.isEmpty || t.startsWith('#')) continue;
    final i = t.indexOf('=');
    if (i <= 0) continue;
    map[t.substring(0, i).trim()] = t.substring(i + 1).trim();
  }
  return map;
}
