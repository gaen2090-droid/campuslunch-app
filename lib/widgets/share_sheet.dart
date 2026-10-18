import 'package:flutter/material.dart' hide ImageInfo;
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:kakao_flutter_sdk_share/kakao_flutter_sdk_share.dart';

import '../constants/app_colors.dart';
import '../constants/app_links.dart';
import '../models/restaurant.dart';
import '../utils/crowd_status_label.dart';

String buildShareLink(Restaurant r) {
  if (r.linkNo > 0) return AppLinks.restaurantUrl(r.linkNo);
  return AppLinks.homeUrl();
}

String _shareSummary(Restaurant r) {
  final statusLine = r.status == '영업안함'
      ? '지금 영업 종료예요'
      : r.hasCrowdUpdate
          ? '지금 ${crowdStatusLabel(r.status)} ·${formatUpdateAgeFromDateTime(r.updatedAt)}'
          : '아직 제보가 없어요';
  return '${r.name}\n$statusLine\n캠퍼스런치에서 다른 매장도 확인해보세요!';
}

/// 클립보드 복사용 — 카톡 외 다른 곳에 붙여넣어도 링크가 같이 따라가도록 포함
String buildShareText(Restaurant r) => '${_shareSummary(r)}\n${buildShareLink(r)}';

/// 카카오톡 템플릿용 — 링크는 템플릿의 버튼이 대신하므로 본문에는 넣지 않음
String buildKakaoShareText(Restaurant r) => _shareSummary(r);

Uri? _kakaoShareImageUri(String raw) {
  final uri = Uri.tryParse(raw.trim());
  if (uri == null || uri.host.isEmpty) return null;
  if (uri.scheme != 'https' && uri.scheme != 'http') return null;
  return uri;
}

Link _restaurantShareLink(Restaurant restaurant) {
  final url = Uri.parse(buildShareLink(restaurant));
  final params = restaurant.linkNo > 0
      ? <String, String>{'r': '${restaurant.linkNo}'}
      : <String, String>{'path': 'home'};
  return Link(
    webUrl: url,
    mobileWebUrl: url,
    androidExecutionParams: params,
    iosExecutionParams: params,
  );
}

TextTemplate _restaurantTextTemplate({
  required Restaurant restaurant,
  required String title,
  required String description,
}) {
  final link = _restaurantShareLink(restaurant);
  return TextTemplate(
    text: '$title\n$description',
    link: link,
    buttons: [Button(title: '앱에서 열기', link: link)],
  );
}

/// 매장 페이지 이미지를 카카오에 올려 피드 카드에 쓸 주소를 받는다.
/// 구글 사진 주소는 카카오 서버가 직접 받지 못하는 경우가 있어, 그때는 앱이 받아 올린다.
Future<ImageInfo?> _hostedShareImage(String raw) async {
  final uri = _kakaoShareImageUri(raw);
  if (uri == null) return null;
  try {
    final scraped =
        await ShareClient.instance.scrapImage(imageUrl: uri.toString());
    return scraped.infos.original;
  } catch (e) {
    debugPrint('[Share] scrap image failed: $e');
  }
  try {
    final res = await http.get(uri).timeout(const Duration(seconds: 8));
    if (res.statusCode != 200 || res.bodyBytes.isEmpty) return null;
    if (res.bodyBytes.length > 5 * 1024 * 1024) return null;
    final uploaded =
        await ShareClient.instance.uploadImage(byteData: res.bodyBytes);
    return uploaded.infos.original;
  } catch (e) {
    debugPrint('[Share] upload image failed: $e');
    return null;
  }
}

/// 점메추·룰렛 결과를 카카오톡으로 연다. 매장 이미지가 있으면 카드에 넣고, 없으면 글만 보낸다.
Future<void> launchRestaurantKakaoShare({
  required Restaurant restaurant,
  required String title,
  required String description,
}) async {
  final image = await _hostedShareImage(restaurant.imageUrl);
  final link = _restaurantShareLink(restaurant);
  final DefaultTemplate template = image == null
      ? _restaurantTextTemplate(
          restaurant: restaurant,
          title: title,
          description: description,
        )
      : FeedTemplate(
          content: Content(
            title: title,
            description: description,
            imageUrl: Uri.parse(image.url),
            imageWidth: image.width,
            imageHeight: image.height,
            link: link,
          ),
          buttons: [Button(title: '앱에서 열기', link: link)],
        );
  try {
    final uri = await ShareClient.instance.shareDefault(template: template);
    await ShareClient.instance.launchKakaoTalk(uri);
  } catch (_) {
    if (template is! FeedTemplate) rethrow;
    final plain = _restaurantTextTemplate(
      restaurant: restaurant,
      title: title,
      description: description,
    );
    final uri = await ShareClient.instance.shareDefault(template: plain);
    await ShareClient.instance.launchKakaoTalk(uri);
  }
}

Future<void> showShareSheet(BuildContext context, Restaurant restaurant) {
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => _ShareSheet(restaurant: restaurant),
  );
}

class _ShareSheet extends StatelessWidget {
  final Restaurant restaurant;
  const _ShareSheet({required this.restaurant});

  Future<void> _copyLink(BuildContext context) async {
    await Clipboard.setData(ClipboardData(text: buildShareText(restaurant)));
    if (!context.mounted) return;
    Navigator.pop(context);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text(
          '클립보드에 복사했어요.',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: Colors.white),
        ),
        backgroundColor: AppColors.primaryCta,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 24),
      ),
    );
  }

  Future<void> _shareToKakao(BuildContext context) async {
    Navigator.pop(context);
    try {
      final url = Uri.parse(buildShareLink(restaurant));
      final params = restaurant.linkNo > 0
          ? <String, String>{'r': '${restaurant.linkNo}'}
          : <String, String>{'path': 'home'};
      final link = Link(
        webUrl: url,
        mobileWebUrl: url,
        androidExecutionParams: params,
        iosExecutionParams: params,
      );
      final template = TextTemplate(
        text: buildKakaoShareText(restaurant),
        link: link,
        buttons: [
          Button(title: '앱에서 열기', link: link),
        ],
      );
      if (await ShareClient.instance.isKakaoTalkSharingAvailable()) {
        final uri = await ShareClient.instance.shareDefault(template: template);
        await ShareClient.instance.launchKakaoTalk(uri);
      } else {
        throw KakaoClientException(ClientErrorCause.notSupported, '카카오톡 미설치');
      }
    } catch (_) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('카카오톡 공유에 실패했어요. 카카오톡 설치를 확인해주세요.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).padding.bottom),
      child: Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: const Color(0xFFE5E7EB),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const Text(
              '공유하기',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w900,
                color: Color(0xFF000000),
              ),
            ),
            const SizedBox(height: 16),
            _ShareOption(
              icon: Icons.link,
              label: '링크 복사하기',
              onTap: () => _copyLink(context),
            ),
            const SizedBox(height: 8),
            _ShareOption(
              icon: Icons.chat_bubble,
              label: '카카오톡 공유하기',
              iconColor: const Color(0xFF3C1E1E),
              iconBg: const Color(0xFFFEE500),
              onTap: () => _shareToKakao(context),
            ),
          ],
        ),
      ),
    );
  }
}

class _ShareOption extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final Color? iconColor;
  final Color? iconBg;

  const _ShareOption({
    required this.icon,
    required this.label,
    required this.onTap,
    this.iconColor,
    this.iconBg,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        decoration: BoxDecoration(
          color: const Color(0xFFF9FAFB),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: iconBg ?? const Color(0xFFF3F4F6),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 18, color: iconColor ?? const Color(0xFF374151)),
            ),
            const SizedBox(width: 12),
            Flexible(
              child: Text(
                label,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF000000),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
