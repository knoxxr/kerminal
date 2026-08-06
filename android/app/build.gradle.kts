import java.util.Properties
import java.io.FileInputStream

plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

// Release signing config is read from android/key.properties (gitignored).
// See android/key.properties.example and DEPLOY.md. When the file is absent
// (e.g. local dev / CI without secrets) the release build falls back to the
// debug key so `flutter run --release` still works.
val keystoreProperties = Properties()
val keystorePropertiesFile = rootProject.file("key.properties")
val hasReleaseSigning = keystorePropertiesFile.exists()
if (hasReleaseSigning) {
    keystoreProperties.load(FileInputStream(keystorePropertiesFile))
}

android {
    namespace = "kr.minary.kerminal"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "kr.minary.kerminal"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    signingConfigs {
        if (hasReleaseSigning) {
            create("release") {
                keyAlias = keystoreProperties["keyAlias"] as String
                keyPassword = keystoreProperties["keyPassword"] as String
                storeFile = keystoreProperties["storeFile"]?.let { file(it) }
                storePassword = keystoreProperties["storePassword"] as String
                // The CI keystore is a PKCS#12 (.p12); a .jks made by keytool
                // needs no storeType. Declaring it explicitly avoids relying on
                // the JDK default, which differs between versions.
                keystoreProperties["storeType"]?.let { storeType = it as String }
            }
        }
    }

    buildTypes {
        release {
            // Use the real release key when key.properties is present, otherwise
            // fall back to debug signing so `flutter run --release` still works.
            //
            // The fallback must never reach users: a debug keystore is generated
            // per machine, so two CI runs produce different signatures and
            // Android refuses to update one build with the next
            // (INSTALL_FAILED_UPDATE_INCOMPATIBLE). Release CI injects
            // key.properties from secrets — see .github/workflows/release.yml.
            signingConfig = if (hasReleaseSigning) {
                signingConfigs.getByName("release")
            } else {
                logger.warn(
                    "kerminal: no android/key.properties — signing the release " +
                        "build with the DEBUG key. Do not distribute this APK."
                )
                signingConfigs.getByName("debug")
            }
            isMinifyEnabled = true
            isShrinkResources = true
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
