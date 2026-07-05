// ignore_for_file: avoid_print
/// Supabase Auth에 Resend(또는 SMTP) 연동 + 메일 발송 한도 상향
///
/// `.env.secrets`의 SMTP_ADMIN_EMAIL 을 바꿔도 Supabase 서버에는 자동 반영되지 않습니다.
/// 반드시 이 스크립트를 실행해야 Dashboard Auth SMTP 설정이 갱신됩니다.
///
///   /Users/dongha/develop/flutter/bin/dart run tool/setup_supabase_smtp.dart
///
/// `.env.secrets` (또는 실행 시 입력):
///   SUPABASE_URL, SUPABASE_ACCESS_TOKEN
///   RESEND_API_KEY=re_...          ← Resend 권장
///   SMTP_ADMIN_EMAIL=onboarding@resend.dev  (도메인 없을 때 테스트용)
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

const _maxPerHour = 3600;

Future<void> main(List<String> args) async {
  final secrets = await _loadEnv('.env.secrets');
  final fallback = await _loadEnv('.env');
  final url = secrets['SUPABASE_URL'] ?? fallback['SUPABASE_URL'] ?? '';
  final token = secrets['SUPABASE_ACCESS_TOKEN'] ?? '';
  if (url.isEmpty || token.isEmpty) {
    stderr.writeln('`.env.secrets`에 SUPABASE_URL, SUPABASE_ACCESS_TOKEN 필요');
    exit(1);
  }

  var apiKey = secrets['RESEND_API_KEY'] ??
      secrets['SMTP_PASS'] ??
      _argValue(args, '--resend-key') ??
      _argValue(args, '--key');
  var adminEmail = secrets['SMTP_ADMIN_EMAIL'] ?? '';
  var senderName = secrets['SMTP_SENDER_NAME'] ?? '캠퍼스런치';
  var smtpHost = (secrets['SMTP_HOST'] ?? '').trim();
  var smtpUser = (secrets['SMTP_USER'] ?? '').trim();
  var smtpPort = int.tryParse(secrets['SMTP_PORT'] ?? '') ?? 0;
  final customSmtp = smtpHost.isNotEmpty && (apiKey?.isNotEmpty ?? false);

  if (apiKey == null || apiKey.isEmpty) {
    stdout.writeln(
      'Resend API 키가 없습니다.\n'
      '1) https://resend.com 가입 → API Keys → Create\n'
      '2) 아래에 re_ 로 시작하는 키를 붙여넣기 (입력은 화면에 안 보임)\n',
    );
    stdout.write('RESEND_API_KEY: ');
    stdin.echoMode = false;
    apiKey = stdin.readLineSync()?.trim() ?? '';
    stdin.echoMode = true;
    stdout.writeln();
    if (apiKey.isEmpty) {
      stderr.writeln('키가 비어 있어 중단합니다.');
      exit(1);
    }
    await _persistResendKey(apiKey);
  }

  // Resend 기본값 (SMTP_HOST+비밀번호 직접 지정 시 유지)
  if (!customSmtp) {
    smtpHost = 'smtp.resend.com';
    smtpUser = 'resend';
    smtpPort = 465;
  } else {
    if (smtpUser.isEmpty) smtpUser = 'resend';
    if (smtpPort <= 0) smtpPort = 587;
  }
  if (adminEmail.isEmpty) {
    adminEmail = 'onboarding@resend.dev';
    print(
      '발신 주소 기본값: $adminEmail\n'
      '  → Resend 무료 테스트용. 본인 Resend 가입 이메일로만 수신 가능할 수 있어요.\n'
      '  → 누구에게나내려면 Resend에서 도메인 인증 후 .env.secrets 의\n'
      '    SMTP_ADMIN_EMAIL=noreply@yourdomain.com 으로 바꾸고 다시 실행하세요.',
    );
  }

  final ref = _projectRef(url);
  if (ref == null) {
    stderr.writeln('SUPABASE_URL 형식 오류: $url');
    exit(1);
  }

  final patch = {
    'external_email_enabled': true,
    'smtp_host': smtpHost.trim(),
    'smtp_port': smtpPort.toString(),
    'smtp_user': smtpUser.trim(),
    'smtp_pass': apiKey.trim(),
    'smtp_admin_email': adminEmail.trim(),
    'smtp_sender_name': senderName.trim(),
    'rate_limit_email_sent': _maxPerHour,
    'rate_limit_otp': _maxPerHour,
    'rate_limit_verify': _maxPerHour,
    'smtp_max_frequency': 1,
  };

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
    stderr.writeln('Supabase 설정 실패 (${res.statusCode}): ${res.body}');
    exit(1);
  }

  final cfg = jsonDecode(res.body) as Map<String, dynamic>;
  print('SMTP 연동 완료');
  print('  host: ${cfg['smtp_host']}');
  print('  port: ${cfg['smtp_port']}');
  print('  from: ${cfg['smtp_admin_email']} (${cfg['smtp_sender_name']})');
  print('  rate_limit_email_sent: ${cfg['rate_limit_email_sent']} /시간');
  print('  rate_limit_otp: ${cfg['rate_limit_otp']} /시간');
  print('\n앱에서 회원가입 → 메일 수신을 확인하세요.');
}

Future<void> _persistResendKey(String apiKey) async {
  final file = File('.env.secrets');
  if (!await file.exists()) return;
  var text = await file.readAsString();
  if (text.contains('RESEND_API_KEY=')) {
    final lines = text.split('\n').map((line) {
      if (line.trim().startsWith('RESEND_API_KEY=')) {
        return 'RESEND_API_KEY=$apiKey';
      }
      return line;
    });
    text = lines.join('\n');
  } else {
    if (!text.endsWith('\n')) text += '\n';
    text += 'RESEND_API_KEY=$apiKey\n';
  }
  await file.writeAsString(text);
  print('.env.secrets 에 RESEND_API_KEY 저장함');
}

String? _argValue(List<String> args, String name) {
  for (final a in args) {
    if (a.startsWith('$name=')) return a.substring(name.length + 1).trim();
  }
  return null;
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
