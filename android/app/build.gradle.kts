import java.util.Properties
import java.io.FileInputStream

plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

val localProperties = Properties().apply {
    val file = rootProject.file("local.properties")
    if (file.exists()) load(FileInputStream(file))
}

/// Git에 포함된 팀 공용 키 (private repo). sdk.dir 은 local.properties 만 사용.
val keysProperties = Properties().apply {
    val file = rootProject.file("keys.properties")
    if (file.exists()) load(FileInputStream(file))
}

/// 릴리스 서명용 keystore 정보 (git 제외 — android/key.properties).
val keystoreProperties = Properties().apply {
    val file = rootProject.file("key.properties")
    if (file.exists()) load(FileInputStream(file))
}

val dotEnv = Properties().apply {
    val file = rootProject.file("../.env")
    if (file.exists()) {
        file.readLines().forEach { line ->
            val t = line.trim()
            if (t.isEmpty() || t.startsWith("#")) return@forEach
            val i = t.indexOf('=')
            if (i > 0) setProperty(t.substring(0, i).trim(), t.substring(i + 1).trim())
        }
    }
}

fun prop(key: String): String =
    keysProperties.getProperty(key)?.takeIf { it.isNotBlank() }
        ?: dotEnv.getProperty(key)?.takeIf { it.isNotBlank() }
        ?: localProperties.getProperty(key, "")

android {
    namespace = "com.campuslunch.app"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
        isCoreLibraryDesugaringEnabled = true
    }

    defaultConfig {
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "com.campuslunch.app"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
        manifestPlaceholders["GOOGLE_MAPS_API_KEY"] = prop("GOOGLE_MAPS_API_KEY")
        val kakaoKey = prop("KAKAO_NATIVE_APP_KEY").trim()
        if (kakaoKey.isEmpty()) {
            throw GradleException(
                "KAKAO_NATIVE_APP_KEY 가 없습니다. git pull 후 android/keys.properties 또는 .env 를 확인하세요.\n" +
                    "또는: dart run tool/sync_env_to_native.dart",
            )
        }
        manifestPlaceholders["KAKAO_NATIVE_APP_KEY"] = kakaoKey
    }

    signingConfigs {
        create("release") {
            val storeFilePath = keystoreProperties.getProperty("storeFile")
            if (storeFilePath != null) {
                storeFile = rootProject.file("app/$storeFilePath")
                storePassword = keystoreProperties.getProperty("storePassword")
                keyAlias = keystoreProperties.getProperty("keyAlias")
                keyPassword = keystoreProperties.getProperty("keyPassword")
            }
        }
    }

    buildTypes {
        release {
            // key.properties 가 있으면 릴리스 키로, 없으면 debug 키로 서명한다.
            // (팀원이 keystore 없이도 디버그 빌드를 돌릴 수 있도록)
            signingConfig = if (keystoreProperties.getProperty("storeFile") != null) {
                signingConfigs.getByName("release")
            } else {
                signingConfigs.getByName("debug")
            }
        }
    }
}

kotlin {
    compilerOptions {
        jvmTarget = org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17
    }
}

flutter {
    source = "../.."
}

dependencies {
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")
}
