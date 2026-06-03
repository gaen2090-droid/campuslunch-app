// ignore_for_file: avoid_print
/// 이메일로 Supabase 회원 완전 삭제 (auth.users + public.users)
///
///   dart run tool/purge_auth_user.dart --email=test@example.com
///
/// public.users 만 Table Editor에서 지운 경우에도 auth.users 가 남아
/// 「이미 가입된 이메일」이 뜹니다. 이 스크립트로 둘 다 삭제하세요.
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

  await client.from('bookmarks').delete().eq('user_id', userId);
  await client.from('notification_settings').delete().eq('user_id', userId);
  await client.from('user_devices').delete().eq('user_id', userId);
  await client.from('crowd_reports').delete().eq('user_id', userId);
  await client.from('analytics_events').delete().eq('user_id', userId);
  await client.from('restaurants').update({'owner_id': null}).eq('owner_id', userId);
  await client.from('users').delete().eq('id', userId);

  await client.auth.admin.deleteUser(userId);

  print('완료: $email (public + auth 삭제). 앱에서 다시 회원가입하세요.');
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
