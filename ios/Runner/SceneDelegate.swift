import Flutter
import UIKit

/// Flutter UIScene 경로.
///
/// 카카오톡 OAuth 복귀(`kakao{KEY}://oauth?code=`)는
/// - `google_sign_in_ios` Scene/App delegate가 먼저 받으면 카카오 SDK까지 URL이 안 감
/// - Flutter `handleDeeplink` → app_links / (구) supabase PKCE 충돌
/// → legacy 플러그인 fallback(`sceneFallbackOpenURLContexts`)으로 카카오 SDK만 전달한다.
class SceneDelegate: FlutterSceneDelegate {
  override func scene(
    _ scene: UIScene,
    openURLContexts URLContexts: Set<UIOpenURLContext>
  ) {
    let oauth = URLContexts.filter { KakaoOAuthForwarder.isKakaoOAuthUrl($0.url) }
    let rest = URLContexts.subtracting(oauth)

    if !oauth.isEmpty {
      KakaoOAuthForwarder.forwardToLegacyPlugins(oauth)
      // super 호출 금지: Google scene handler + Flutter handleDeeplink 방지
    }
    if !rest.isEmpty {
      super.scene(scene, openURLContexts: rest)
    }
  }
}

enum KakaoOAuthForwarder {
  static func isKakaoOAuthUrl(_ url: URL) -> Bool {
    guard let scheme = url.scheme, scheme.hasPrefix("kakao") else { return false }
    return url.host == "oauth"
  }

  /// Scene plugin(Google 등)을 건너뛰고 legacy app delegate(Kakao SDK)에만 전달.
  static func forwardToLegacyPlugins(_ contexts: Set<UIOpenURLContext>) {
    guard let appDelegate = UIApplication.shared.delegate as? NSObject,
          let lifeCycle = appDelegate.value(forKey: "lifeCycleDelegate") as? NSObject
    else {
      NSLog("[KakaoOAuth] lifeCycleDelegate unavailable")
      return
    }
    let selector = NSSelectorFromString("sceneFallbackOpenURLContexts:")
    guard lifeCycle.responds(to: selector) else {
      NSLog("[KakaoOAuth] sceneFallbackOpenURLContexts unavailable")
      return
    }
    _ = lifeCycle.perform(selector, with: contexts as NSSet)
  }
}
