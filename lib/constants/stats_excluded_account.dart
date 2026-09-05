/// 통계·지표 수집에서 완전히 제외되는 내부 제보 전용 계정.
/// 서버(supabase/stats_excluded_users.sql)의 is_stats_excluded()와 동일 대상이어야 함.
///
/// 이 계정은 제보(crowd_reports)는 정상 반영되지만, 5분 쿨다운·GPS 거리 체크 같은
/// 클라이언트 사전 게이트는 서버 RPC까지 가지 못하게 막아버리므로 여기서도 함께 우회한다.
abstract final class StatsExcludedAccount {
  static const String email = 'campuslunch2026@gmail.com';

  static bool isEmail(String? email) =>
      email != null && email.toLowerCase() == StatsExcludedAccount.email;
}
