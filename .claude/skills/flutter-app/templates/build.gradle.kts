import java.util.Properties

// 업로드 키. 저장소 밖 ~/keystores/myapp-upload.jks — android/key.properties(gitignore)가 가리킨다:
//   storeFile=/home/noble/keystores/myapp-upload.jks
//   keyAlias=myapp-upload
//   passwordFile=/home/noble/keystores/myapp-upload.password.txt
// 없으면 release 도 디버그 키로 서명한다(키를 만들기 전, 다른 PC 에서 빌드만 해 볼 때).
val keyProps = Properties().apply {
    val f = rootProject.file("key.properties")
    if (f.exists()) f.inputStream().use { load(it) }
}
val uploadPassword: String? = keyProps.getProperty("passwordFile")?.let { file(it).readText().trim() }

// API 키 같은 비밀값은 android/secrets.properties(gitignore)에: MAPS_API_KEY=…
val secrets = Properties().apply {
    val f = rootProject.file("secrets.properties")
    if (f.exists()) f.inputStream().use { load(it) }
}

plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "com.junorion.myapp"
    compileSdk = flutter.compileSdkVersion // 플러그인이 더 높은 걸 요구하면 그 숫자로. 런타임 동작은 targetSdk 가 정한다
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        // Play 에 올린 뒤에는 바꿀 수 없다.
        applicationId = "com.junorion.myapp"
        minSdk = 26 // Android 8.0
        targetSdk = 36 // Play 요구 수준(2026-08-31 부터 API 36) — 매년 오르니 출시 전 확인
        // 버전은 pubspec.yaml 의 version: 1.0.0+1 (이름+코드)
        versionCode = flutter.versionCode
        versionName = flutter.versionName
        manifestPlaceholders["MAPS_API_KEY"] = secrets.getProperty("MAPS_API_KEY", "")
    }

    // dev 는 패키지명이 달라 정식 앱과 나란히 설치된다(진단·실험 빌드). 앱 이름은 src/<flavor>/res/values(-ko)
    flavorDimensions += "env"
    productFlavors {
        create("dev") {
            dimension = "env"
            applicationIdSuffix = ".dev"
            versionNameSuffix = "-dev"
        }
        create("prod") {
            dimension = "env"
        }
    }

    signingConfigs {
        if (uploadPassword != null) {
            create("upload") {
                storeFile = file(keyProps.getProperty("storeFile"))
                storePassword = uploadPassword
                keyAlias = keyProps.getProperty("keyAlias")
                keyPassword = uploadPassword
            }
        }
    }

    buildTypes {
        release {
            // 코드 축소 규칙 — SDK 가 이름으로 찾는 클래스를 R8 이 지우지 않게 (광고 SDK 는 ads 스킬 참고)
            proguardFiles(getDefaultProguardFile("proguard-android-optimize.txt"), "proguard-rules.pro")
            // 시험폰에 깔 APK 는 디버그 키로(-PdebugSign=true): 폰의 기존 앱(디버그 서명)을 지우지 않고 덮어 깐다.
            // Play 에 올릴 AAB 만 업로드 키로.
            signingConfig = if (project.hasProperty("debugSign")) signingConfigs.getByName("debug")
                else signingConfigs.findByName("upload") ?: signingConfigs.getByName("debug")
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
