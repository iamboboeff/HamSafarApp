import java.util.Properties
import java.io.FileInputStream

plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
    // Wires `google-services.json` into the Android resource pipeline so the
    // Firebase SDK can self-configure at runtime.
    id("com.google.gms.google-services")
}

// Load `android/key.properties` so the release build is signed with our own
// upload keystore (not the auto-generated debug one). The file is gitignored;
// keystore itself lives outside the repo at `~/Documents/keystores/`.
val keystoreProperties = Properties()
val keystorePropertiesFile = rootProject.file("key.properties")
if (keystorePropertiesFile.exists()) {
    keystoreProperties.load(FileInputStream(keystorePropertiesFile))
}

android {
    namespace = "com.hamsafar.hamsafar"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        // Required by flutter_local_notifications (QA #86) — backports
        // java.time and other APIs to our minSdk.
        isCoreLibraryDesugaringEnabled = true
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_17.toString()
    }

    defaultConfig {
        applicationId = "com.hamsafar.hamsafar"
        // minSdk = 29 (Android 10, August 2019). Picked over the older
        // iPhone-X-matching API 26 to skip pre-Q permission models and
        // scoped-storage shims — gives us native dark-mode signaling, the
        // current photo-picker contract, and TLS 1.3 out of the box.
        // Excludes Android 5–9 (combined ≈ 8–10% of the 2026 install base);
        // acceptable trade-off for a much simpler runtime surface.
        minSdk = 29
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    signingConfigs {
        create("release") {
            keyAlias = keystoreProperties["keyAlias"] as String?
            keyPassword = keystoreProperties["keyPassword"] as String?
            storeFile = (keystoreProperties["storeFile"] as String?)?.let { file(it) }
            storePassword = keystoreProperties["storePassword"] as String?
        }
    }

    buildTypes {
        release {
            // Falls back to debug signing only if `key.properties` is missing
            // (e.g. on a fresh clone before someone restores the keystore from
            // 1Password). Real release builds always sign with the upload key.
            signingConfig = if (keystorePropertiesFile.exists()) {
                signingConfigs.getByName("release")
            } else {
                signingConfigs.getByName("debug")
            }
        }
    }
}

flutter {
    source = "../.."
}

dependencies {
    // Core library desugaring runtime — required by flutter_local_notifications.
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")
}
