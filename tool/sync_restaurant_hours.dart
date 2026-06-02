// ignore_for_file: avoid_print
/// DB 매장 영업시간을 Google Places 기준으로 갱신
///
///   dart run tool/sync_restaurant_hours.dart
///   dart run tool/sync_restaurant_hours.dart --name 칠기마라
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:supabase/supabase.dart';

import '../lib/utils/business_hours.dart';

Future<void> main(List<String> args) async {
  final nameFilter = _argValue(args, '--name');
  final secrets = await _readEnv('.env.secrets');
  final fallback = await _readEnv('.env');
  final url = secrets['SUPABASE_URL'] ?? fallback['SUPABASE_URL'] ?? '';
  final secret = secrets['SUPABASE_SECRET_KEY'] ?? '';
  final mapsKey =
      secrets['GOOGLE_MAPS_API_KEY'] ?? fallback['GOOGLE_MAPS_API_KEY'] ?? '';
  if (url.isEmpty || secret.isEmpty) {
    stderr.writeln('`.env.secrets`에 SUPABASE_URL, SUPABASE_SECRET_KEY 필요');
    exit(1);
  }
  if (mapsKey.isEmpty) {
    stderr.writeln('`.env`에 GOOGLE_MAPS_API_KEY 필요');
    exit(1);
  }

  final client = SupabaseClient(url, secret);
  final httpClient = http.Client();
  final rows = await client.from('restaurants').select().eq('is_active', true);

  var updated = 0;
  for (final raw in rows) {
    final row = Map<String, dynamic>.from(raw as Map);
    final name = row['name'] as String? ?? '';
    if (nameFilter != null && !name.contains(nameFilter)) continue;

    final desc = _parseDesc(row['description']);
    var placeId = desc?['google_place_id'] as String?;

    Map<String, dynamic>? opening;
    if (placeId != null && placeId.isNotEmpty) {
      opening = await _fetchOpening(httpClient, mapsKey, placeId);
    }
    if (opening == null) {
      final q = '$name ${row['address'] ?? ''} 중앙대학교'.trim();
      placeId = await _searchPlaceId(httpClient, mapsKey, q);
      if (placeId == null) {
        print('SKIP (Places 없음): $name');
        continue;
      }
      opening = await _fetchOpening(httpClient, mapsKey, placeId);
    }
    if (opening == null) {
      print('SKIP (영업시간 없음): $name');
      continue;
    }

    final bh = BusinessHoursData.fromGoogleOpeningHours(opening);
    final next = Map<String, dynamic>.from(desc ?? {});
    next.addAll(bh.toDescriptionFields());
    next['google_place_id'] = placeId;

    await client
        .from('restaurants')
        .update({'description': jsonEncode(next)})
        .eq('id', row['id']);

    print('OK: $name → ${bh.hoursCanonical}');
    if (bh.hoursDisplay.isNotEmpty) print('    ${bh.hoursDisplay}');
    updated++;
  }

  httpClient.close();
  print('\n$updated개 매장 영업시간 갱신 완료');
}

Future<String?> _searchPlaceId(
  http.Client client,
  String key,
  String query,
) async {
  final uri = Uri.https('maps.googleapis.com', '/maps/api/place/textsearch/json', {
    'query': query,
    'key': key,
    'language': 'ko',
    'region': 'kr',
  });
  final res = await client.get(uri);
  final data = jsonDecode(res.body) as Map<String, dynamic>;
  if (data['status'] != 'OK') return null;
  final results = data['results'] as List<dynamic>?;
  if (results == null || results.isEmpty) return null;
  return (results.first as Map)['place_id'] as String?;
}

Future<Map<String, dynamic>?> _fetchOpening(
  http.Client client,
  String key,
  String placeId,
) async {
  final uri = Uri.https('maps.googleapis.com', '/maps/api/place/details/json', {
    'place_id': placeId,
    'key': key,
    'language': 'ko',
    'fields': 'opening_hours',
  });
  final res = await client.get(uri);
  final data = jsonDecode(res.body) as Map<String, dynamic>;
  if (data['status'] != 'OK') return null;
  final result = data['result'] as Map<String, dynamic>?;
  return result?['opening_hours'] as Map<String, dynamic>?;
}

String? _argValue(List<String> args, String key) {
  final i = args.indexOf(key);
  if (i < 0 || i + 1 >= args.length) return null;
  return args[i + 1];
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
