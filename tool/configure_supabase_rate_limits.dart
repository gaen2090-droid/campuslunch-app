// ignore_for_file: avoid_print
/// Supabase Auth 메일/OTP 발송 한도를 개발·테스트에 맞게 최대로 올립니다.
///
///   /Users/dongha/develop/flutter/bin/dart run tool/configure_supabase_rate_limits.dart
///
/// `.env.secrets`:
///   SUPABASE_URL, SUPABASE_ACCESS_TOKEN (필수)
///   SMTP_HOST, SMTP_PORT, SMTP_USER, SMTP_PASS, SMTP_ADMIN_EMAIL (선택)
///   → 있으면 커스텀 SMTP + 시간당 메일 한도(기본 3600)까지 함께 설정
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

/// OTP·인증 시도 한도 (시간당). Supabase 대시보드와 동일 단위.
const _maxOtpPerHour = 3600;

/// 커스텀 SMTP 사용 시 시간당 메일 발송 한도.
const _maxEmailSentPerHour = 3600;

Future<void> main() async {
  final secrets = await _loadEnv('.env.secrets');
  final fallback = await _loadEnv('.env');
  final url = secrets['SUPABASE_URL'] ?? fallback['SUPABASE_URL'] ?? '';
  final token = secrets['SUPABASE_ACCESS_TOKEN'] ?? '';
  if (url.isEmpty || token.isEmpty) {
    stderr.writeln('`.env.secrets`에 SUPABASE_URL, SUPABASE_ACCESS_TOKEN 필요');
    exit(1);
  }

  final ref = _projectRef(url);
  if (ref == null) {
    stderr.writeln('SUPABASE_URL 형식 오류: $url');
    exit(1);
  }

  final patch = <String, dynamic>{
    'rate_limit_otp': _maxOtpPerHour,
    'rate_limit_verify': _maxOtpPerHour,
    'rate_limit_sms_sent': _maxOtpPerHour,
    'rate_limit_token_refresh': _maxOtpPerHour,
    'rate_limit_anonymous_users': _maxOtpPerHour,
  };

  final smtpHost = secrets['SMTP_HOST'] ?? '';
  final smtpUser = secrets['SMTP_USER'] ?? '';
  final smtpPass =
      secrets['SMTP_PASS'] ?? secrets['RESEND_API_KEY'] ?? '';
  final smtpAdmin = secrets['SMTP_ADMIN_EMAIL'] ?? secrets['SMTP_USER'] ?? '';
  final smtpPort = int.tryParse(secrets['SMTP_PORT'] ?? '') ?? 587;
  final smtpSender = secrets['SMTP_SENDER_NAME'] ?? '캠퍼스런치';

  if (smtpHost.isNotEmpty &&
      smtpUser.isNotEmpty &&
      smtpPass.isNotEmpty &&
      smtpAdmin.isNotEmpty) {
    patch.addAll({
      'external_email_enabled': true,
      'smtp_host': smtpHost,
      'smtp_port': smtpPort.toString(),
      'smtp_user': smtpUser,
      'smtp_pass': smtpPass,
      'smtp_admin_email': smtpAdmin,
      'smtp_sender_name': smtpSender,
      'rate_limit_email_sent': _maxEmailSentPerHour,
      'smtp_max_frequency': 1,
    });
    print('커스텀 SMTP + 시간당 메일 $_maxEmailSentPerHour건 설정 포함');
  } else {
    print(
      '참고: 기본 Supabase 메일은 시간당 약 2통 제한(변경 불가). '
      '한도를 더 올리려면: dart run tool/setup_supabase_smtp.dart (docs/SMTP_SETUP.md)',
    );
  }

  final uri = Uri.parse('https://api.supabase.com/v1/projects/$ref/config/auth');
  final res = await http.patch(
    uri,
    headers: {
      'Authorization': 'Bearer $token',
      'Content-Type': 'application/json',
    },
    body: jsonEncode(patch),
  );

  if (res.statusCode < 200 || res.statusCode >= 300) {
    stderr.writeln('실패 (${res.statusCode}): ${res.body}');
    exit(1);
  }

  final cfg = jsonDecode(res.body) as Map<String, dynamic>;
  print('적용 완료:');
  print('  rate_limit_otp        = ${cfg['rate_limit_otp']}');
  print('  rate_limit_verify     = ${cfg['rate_limit_verify']}');
  print('  rate_limit_email_sent = ${cfg['rate_limit_email_sent']} '
      '(null이면 기본 SMTP 한도 적용)');
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
