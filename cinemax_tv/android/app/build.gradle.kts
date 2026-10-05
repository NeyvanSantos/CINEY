import java.util.Properties

plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

// Carrega propriedades da keystore de release
val keystoreProperties = Properties().apply {
    val keystoreFile = sequenceOf(
        rootProject.file("key.properties"),
        rootProject.file("app/key.properties"),
        file("key.properties")
    ).firstOrNull { it.exists() }
    keystoreFile?.let { load(it.inputStream()) }
}

android {
    namespace = "com.cinemax.cinemax"
    ndkVersion = "28.2.13676358"
    compileSdk = flutter.compileSdkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_17.toString()
    }

    defaultConfig {
        applicationId = "com.ciney.tv"
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
        resValue(
            "string",
            "cast_receiver_application_id",
            providers.gradleProperty("cinemaxCastReceiverAppId").orElse("CC1AD845").get()
        )
    }

    signingConfigs {
        create("release") {
            keyAlias = keystoreProperties["keyAlias"] as String?
            keyPassword = keystoreProperties["keyPassword"] as String?
            storeFile = file(keystoreProperties["storeFile"] as String? ?: "cinemax-release-key.jks")
            storePassword = keystoreProperties["storePassword"] as String?
            enableV1Signing = true
            enableV2Signing = true
        }
    }

    buildTypes {
        release {
            signingConfig = signingConfigs.getByName("release")
            isMinifyEnabled = false
            isShrinkResources = false
        }
    }
}

flutter {
    source = "../.."
}

dependencies {
    implementation("androidx.appcompat:appcompat:1.7.1")
    implementation("com.google.android.gms:play-services-cast-framework:22.3.1")
}
