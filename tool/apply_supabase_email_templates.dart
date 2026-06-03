// ignore_for_file: avoid_print
/// Supabase 이메일 템플릿을 OTP(6자리) 전용으로 적용합니다.
///
///   dart run tool/apply_supabase_email_templates.dart
///
/// `.env.secrets` 필요:
///   SUPABASE_URL=https://xxxx.supabase.co
///   SUPABASE_ACCESS_TOKEN=sbp_...  (Dashboard → Account → Access Tokens)
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

Future<void> main() async {
  final secrets = await _loadEnv('.env.secrets');
  final fallback = await _loadEnv('.env');
  final url = secrets['SUPABASE_URL'] ?? fallback['SUPABASE_URL'] ?? '';
  final token = secrets['SUPABASE_ACCESS_TOKEN'] ?? '';
  if (url.isEmpty || token.isEmpty) {
    final envPath = File('.env.secrets').absolute.path;
    final found = secrets.keys.where((k) => k.startsWith('SUPABASE_')).toList()
      ..sort();
    stderr.writeln('`.env.secrets` 설정이 부족합니다. ($envPath)');
    stderr.writeln('  읽힌 키: ${found.isEmpty ? "(없음)" : found.join(", ")}');
    if (url.isEmpty) {
      stderr.writeln('  → SUPABASE_URL=... 추가');
    }
    if (token.isEmpty) {
      stderr.writeln('  → SUPABASE_ACCESS_TOKEN=sbp_... 추가 (파일 저장 Cmd+S 확인)');
      stderr.writeln('  토큰: https://supabase.com/dashboard/account/tokens');
    }
    exit(1);
  }

  final ref = _projectRef(url);
  if (ref == null) {
    stderr.writeln('SUPABASE_URL 형식을 확인해주세요: $url');
    exit(1);
  }

  final root = Directory.current;
  final magicBody = await File(
    '${root.path}/supabase/email_templates/magic_link.html',
  ).readAsString();
  final magicSubject = (await File(
    '${root.path}/supabase/email_templates/magic_link_subject.txt',
  ).readAsString())
      .trim();
  final confirmBody = await File(
    '${root.path}/supabase/email_templates/confirm_signup.html',
  ).readAsString();
  final confirmSubject = (await File(
    '${root.path}/supabase/email_templates/confirm_signup_subject.txt',
  ).readAsString())
      .trim();

  final body = jsonEncode({
    'mailer_otp_length': 6,
    'mailer_subjects_magic_link': magicSubject,
    'mailer_templates_magic_link_content': magicBody,
    'mailer_subjects_confirmation': confirmSubject,
    'mailer_templates_confirmation_content': confirmBody,
    'rate_limit_otp': 3600,
    'rate_limit_verify': 3600,
    'rate_limit_sms_sent': 3600,
    'rate_limit_token_refresh': 3600,
    'rate_limit_anonymous_users': 3600,
    'smtp_max_frequency': 1,
  });

  final uri = Uri.parse('https://api.supabase.com/v1/projects/$ref/config/auth');
  final res = await http.patch(
    uri,
    headers: {
      'Authorization': 'Bearer $token',
      'Content-Type': 'application/json',
    },
    body: body,
  );

  if (res.statusCode >= 200 && res.statusCode < 300) {
    print('적용 완료: Magic Link + Confirm signup → 6자리 OTP 메일');
    print('OTP/인증 한도: 시간당 3600 (재발송 간격 smtp_max_frequency=1초)');
    print('기본 SMTP 메일은 시간당 ~2통 제한 → 더 필요하면 SMTP 설정 후');
    print('  dart run tool/configure_supabase_rate_limits.dart');
    print('앱에서 새 이메일로 가입해 메일 본문을 확인하세요.');
    return;
  }

  stderr.writeln('실패 (${res.statusCode}): ${res.body}');
  exit(1);
}

String? _projectRef(String url) {
  final uri = Uri.tryParse(url);
  if (uri == null || uri.host.isEmpty) return null;
  final host = uri.host;
  if (!host.endsWith('.supabase.co')) return null;
  return host.split('.').first;
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
