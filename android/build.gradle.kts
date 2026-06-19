allprojects {
    repositories {
        google()
        mavenCentral()
        maven { url = uri("https://devrepo.kakao.com/nexus/repository/kakaomap-releases/") }
    }
}

val newBuildDir: Directory =
    rootProject.layout.buildDirectory
        .dir("../../build")
        .get()
rootProject.layout.buildDirectory.value(newBuildDir)

subprojects {
    val newSubprojectBuildDir: Directory = newBuildDir.dir(project.name)
    project.layout.buildDirectory.value(newSubprojectBuildDir)
}
// file_picker 8.x 등 일부 플러그인이 compileSdk 34 로 고정되어 있어
// flutter_plugin_android_lifecycle(컴파일 SDK 36 요구)과 충돌한다.
// 모든 안드로이드 라이브러리 모듈의 compileSdk 를 36 으로 강제한다.
// afterEvaluate 를 evaluationDependsOn 보다 먼저 등록해야
// "already evaluated" 오류를 피할 수 있다.
subprojects {
    afterEvaluate {
        val androidExtension = project.extensions.findByName("android")
        if (androidExtension is com.android.build.gradle.BaseExtension) {
            androidExtension.compileSdkVersion(36)
        }
    }
    project.evaluationDependsOn(":app")
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
