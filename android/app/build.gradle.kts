import java.util.Properties
import java.io.FileInputStream

plugins {
    id("com.google.gms.google-services")
    id("com.android.application")
    id("kotlin-android")
    id("dev.flutter.flutter-gradle-plugin")
}

val keystoreProperties = Properties()
val keystorePropertiesFile = rootProject.file("key.properties")
if (keystorePropertiesFile.exists()) {
    keystoreProperties.load(FileInputStream(keystorePropertiesFile))
}

// 네이버 로그인 client secret — 이 저장소는 공개라 절대 커밋하지 않는다.
// 우선순위: android/secrets.properties(로컬, gitignore) → NAVER_CLIENT_SECRET 환경변수(CI).
// 둘 다 없으면 빈 문자열 → 네이버 로그인 버튼이 숨겨진 빌드가 나온다(빌드는 정상).
// (네이버 모바일 SDK가 secret을 앱에 요구하는 구조라 불가피하게 바이너리에는 포함된다.)
val secretsProperties = Properties()
val secretsPropertiesFile = rootProject.file("secrets.properties")
if (secretsPropertiesFile.exists()) {
    secretsProperties.load(FileInputStream(secretsPropertiesFile))
}
val naverClientSecret: String =
    (secretsProperties["naverClientSecret"] as String?)
        ?: System.getenv("NAVER_CLIENT_SECRET")
        ?: ""

android {
    namespace = "com.nulloongzi.nulloongzido"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_1_8
        targetCompatibility = JavaVersion.VERSION_1_8
    }

    kotlinOptions {
        jvmTarget = "1.8"
    }

    sourceSets {
        getByName("main").java.srcDirs("src/main/kotlin")
    }

    defaultConfig {
        applicationId = "com.nulloongzi.nulloongzido"
        minSdk = maxOf(flutter.minSdkVersion, 23)  // Firebase Android SDK 최소 23
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName

        // strings.xml 대신 빌드 시점에 주입 (AndroidManifest의 com.naver.sdk.clientSecret 참조)
        resValue("string", "naver_client_secret", naverClientSecret)
    }

    signingConfigs {
        create("release") {
            if (keystorePropertiesFile.exists()) {
                keyAlias = keystoreProperties["keyAlias"] as String?
                keyPassword = keystoreProperties["keyPassword"] as String?
                storeFile = keystoreProperties["storeFile"]?.let { rootProject.file(it) }
                storePassword = keystoreProperties["storePassword"] as String?
            }
        }
        // 고정 디버그 키스토어 → CI/로컬 어디서 빌드해도 SHA-1 동일 → 구글 로그인/App Links 1회 등록.
        // (디버그 키스토어는 비밀이 아님 — 표준 관행)
        getByName("debug") {
            storeFile = file("debug-fixed.keystore")
            storePassword = "android"
            keyAlias = "androiddebugkey"
            keyPassword = "android"
        }
    }

    buildTypes {
        getByName("release") {
            if (keystorePropertiesFile.exists()) {
                signingConfig = signingConfigs.getByName("release")
            }
            isMinifyEnabled = false
            isShrinkResources = false
        }
    }
}

dependencies {
    implementation(platform("com.google.firebase:firebase-bom:34.8.0"))
    implementation("com.google.firebase:firebase-analytics")
    implementation("org.jetbrains.kotlin:kotlin-stdlib-jdk7:1.7.0")
}
