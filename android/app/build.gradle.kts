import java.util.Properties
import java.io.FileInputStream

plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

// Release signing: android/key.properties (git-ignored, never committed) with
// storeFile, storePassword, keyAlias and keyPassword. See README.md
// ("Release signing").
val keystoreProperties = Properties()
val keystorePropertiesFile = rootProject.file("key.properties")
val hasReleaseKeystore = keystorePropertiesFile.exists()
if (hasReleaseKeystore) {
    FileInputStream(keystorePropertiesFile).use { keystoreProperties.load(it) }
}

fun keystoreProperty(name: String): String =
    keystoreProperties.getProperty(name)?.trim()?.takeIf { it.isNotEmpty() }
        ?: throw GradleException(
            "android/key.properties has no \"$name\". It needs storeFile, " +
                "storePassword, keyAlias and keyPassword: see README.md " +
                "(\"Release signing\")."
        )

// A production release without the upload key is refused (see the task graph
// check at the end of this file) unless this is set to 1, which is meant for
// a local smoke build of the minified app only.
val allowDebugSignedReleaseVariable = "LEDGERZERO_ALLOW_DEBUG_SIGNED_RELEASE"
val allowDebugSignedRelease =
    providers.environmentVariable(allowDebugSignedReleaseVariable).orNull == "1"

android {
    namespace = "com.ledgerzero.app"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
        isCoreLibraryDesugaringEnabled = true
    }

    defaultConfig {
        applicationId = "com.ledgerzero.app"
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    buildFeatures {
        // AGP 9 disables resValue by default; the flavors set app_name with it.
        resValues = true
    }

    flavorDimensions += "env"

    productFlavors {
        create("development") {
            dimension = "env"
            applicationIdSuffix = ".dev"
            versionNameSuffix = "-dev"
            resValue("string", "app_name", "LedgerZero Dev")
        }
        create("staging") {
            dimension = "env"
            applicationIdSuffix = ".staging"
            versionNameSuffix = "-staging"
            resValue("string", "app_name", "LedgerZero Staging")
        }
        create("production") {
            dimension = "env"
            resValue("string", "app_name", "LedgerZero")
        }
    }

    signingConfigs {
        if (hasReleaseKeystore) {
            create("release") {
                keyAlias = keystoreProperty("keyAlias")
                keyPassword = keystoreProperty("keyPassword")
                // A relative storeFile is resolved against android/app.
                storeFile = file(keystoreProperty("storeFile"))
                storePassword = keystoreProperty("storePassword")
                if (storeFile?.isFile != true) {
                    throw GradleException(
                        "android/key.properties: storeFile \"$storeFile\" " +
                            "does not exist. A relative path is resolved " +
                            "against android/app."
                    )
                }
            }
        }
    }

    buildTypes {
        release {
            // Without android/key.properties the release build type is
            // configured with the debug key. The development and staging
            // flavors may be built that way (testing only). The production
            // flavor may not, unless LEDGERZERO_ALLOW_DEBUG_SIGNED_RELEASE=1
            // is set: the task graph check at the end of this file stops
            // the build before anything is compiled.
            signingConfig = signingConfigs.findByName("release")
                ?: signingConfigs.getByName("debug")
            isMinifyEnabled = true
            isShrinkResources = true
            proguardFiles(getDefaultProguardFile("proguard-android-optimize.txt"), "proguard-rules.pro")
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
    // BiometricPrompt for the app lock (AppLockChannel.kt).
    implementation("androidx.biometric:biometric:1.1.0")
    // Google Play's in-app rating dialog (ReviewChannel.kt). Called directly:
    // the in_app_review plugin does not build with AGP 9.
    implementation("com.google.android.play:review:2.0.2")
}

// The production release is what goes to Google Play, and Play accepts only
// the upload key. Building it with the debug key must never happen by
// accident (a missing or misplaced key.properties), so the build stops here,
// before any task runs, and says what to do.
gradle.taskGraph.whenReady {
    if (hasReleaseKeystore) {
        return@whenReady
    }
    val releaseTasks = allTasks.filter {
        it.project == project && it.name.contains("Release")
    }
    if (releaseTasks.isEmpty()) {
        return@whenReady
    }
    if (releaseTasks.any { it.name.contains("ProductionRelease") }) {
        if (!allowDebugSignedRelease) {
            throw GradleException(
                """
                |
                |The production release has no signing key: android/key.properties was not found.
                |
                |  * To build the app for Google Play, create the upload keystore and
                |    android/key.properties as described in README.md ("Release signing").
                |  * To build a debug-signed release for a local test only (it cannot be
                |    uploaded to Play), set $allowDebugSignedReleaseVariable=1, for example:
                |      $allowDebugSignedReleaseVariable=1 flutter build appbundle --release --flavor production -t lib/main_production.dart
                |
                """.trimMargin()
            )
        }
        logger.warn(
            "WARNING: $allowDebugSignedReleaseVariable=1: the production release " +
                "is signed with the DEBUG key. Do not upload it to Play."
        )
    } else {
        logger.warn(
            "key.properties not found: signing the release build with the DEBUG key."
        )
    }
}
