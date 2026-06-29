# 카카오맵/카카오 SDK는 JNI·리플렉션으로 내부 클래스를 호출하므로
# R8이 이를 제거/난독화하면 release 빌드에서만 크래시가 발생한다.
-keep class com.kakao.** { *; }
-keep interface com.kakao.** { *; }
-dontwarn com.kakao.**

-keep class io.seunghwanly.kakao_maps_flutter.** { *; }
-dontwarn io.seunghwanly.kakao_maps_flutter.**
