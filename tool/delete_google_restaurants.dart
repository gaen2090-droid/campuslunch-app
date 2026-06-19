// ignore_for_file: avoid_print
/// Google Places로만 등록된 매장 DB 삭제
///
///   dart run tool/delete_google_restaurants.dart
///   dart run tool/delete_google_restaurants.dart --dry-run
import 'dart:convert';
import 'dart:io';

import 'package:supabase/supabase.dart';

Future<void> main(List<String> args) async {
  final dryRun = args.contains('--dry-run');
  final secrets = await _readEnv('.env.secrets');
  final fallback = await _readEnv('.env');
  final url = secrets['SUPABASE_URL'] ?? fallback['SUPABASE_URL'] ?? '';
  final secret = secrets['SUPABASE_SECRET_KEY'] ?? '';
  if (url.isEmpty || secret.isEmpty) {
    stderr.writeln('`.env.secrets`에 SUPABASE_URL, SUPABASE_SECRET_KEY 필요');
    exit(1);
  }

  final client = SupabaseClient(url, secret);
  final rows = await client.from('restaurants').select('id, name, description');

  final targets = <Map<String, dynamic>>[];
  for (final raw in rows) {
    final row = Map<String, dynamic>.from(raw as Map);
    final desc = _parseDesc(row['description']);
    if (desc == null) continue;
    final hasGoogle = desc.containsKey('google_place_id') &&
        (desc['google_place_id'] as String?)?.isNotEmpty == true;
    final hasKakao = desc.containsKey('kakao_place_id') &&
        (desc['kakao_place_id'] as String?)?.isNotEmpty == true;
    if (hasGoogle && !hasKakao) {
      targets.add(row);
    }
  }

  if (targets.isEmpty) {
    print('삭제 대상 Google 전용 매장 없음');
    return;
  }

  print('삭제 대상 ${targets.length}개:');
  for (final t in targets) {
    print('  - ${t['name']} (${t['id']})');
  }

  if (dryRun) {
    print('\n--dry-run: 실제 삭제하지 않았습니다.');
    return;
  }

  final ids = targets.map((t) => t['id'] as String).toList();

  await client.from('crowd_reports').delete().inFilter('restaurant_id', ids);
  await client.from('owner_seat_updates').delete().inFilter('restaurant_id', ids);
  await client.from('crowd_status').delete().inFilter('restaurant_id', ids);
  await client.from('analytics_events').delete().inFilter('restaurant_id', ids);
  await client.from('restaurants').delete().inFilter('id', ids);

  for (final t in targets) {
    print('DELETED: ${t['name']}');
  }

  print('\n${targets.length}개 매장 삭제 완료');
}

Map<String, dynamic>? _parseDesc(dynamic raw) {
  if (raw == null) return null;
  if (raw is Map<String, dynamic>) return raw;
  if (raw is Map) return Map<String, dynamic>.from(raw);
  try {
    final d = jsonDecode(raw as String);
    if (d is Map<String, dynamic>) return d;
    if (d is Map) return Map<String, dynamic>.from(d);
  } catch (_) {}
  return null;
}

Future<Map<String, String>> _readEnv(String path) async {
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
