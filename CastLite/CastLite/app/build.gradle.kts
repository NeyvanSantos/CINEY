plugins {
    id("com.android.application")
    id("org.jetbrains.kotlin.android")
}

android {
    namespace = "com.example.castlite"
    compileSdk = 35

    defaultConfig {
        applicationId = "com.example.castlite"
        minSdk = 26
        targetSdk = 35
        versionCode = 1
        versionName = "0.1.0"
    }

    buildTypes {
        debug {
            applicationIdSuffix = ".debug"
        }
        release {
            isMinifyEnabled = false
        }
    }
    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }
    kotlinOptions {
        jvmTarget = "17"
    }
    buildFeatures {
        viewBinding = true
    }
    testOptions {
        unitTests.all {
            it.jvmArgs("-Dfile.encoding=UTF-8")
        }
    }
}

dependencies {
    implementation("androidx.core:core-ktx:1.13.1")
    implementation("androidx.appcompat:appcompat:1.7.0")
    implementation("androidx.webkit:webkit:1.15.0")
    implementation("com.google.android.material:material:1.12.0")
    implementation("androidx.mediarouter:mediarouter:1.7.0")
    implementation("com.google.android.gms:play-services-cast-framework:21.5.0")
    // DLNA/UPnP
    implementation("org.jupnp:org.jupnp:3.0.2")
    implementation("org.jupnp:org.jupnp.support:3.0.2")
    implementation("javax.enterprise:cdi-api:1.2")
    implementation("org.eclipse.jetty:jetty-server:9.4.54.v20240208")
    implementation("org.eclipse.jetty:jetty-servlet:9.4.54.v20240208")
    implementation("org.eclipse.jetty:jetty-client:9.4.54.v20240208")
    // Coroutines
    implementation("org.jetbrains.kotlinx:kotlinx-coroutines-android:1.8.1")
    testImplementation("junit:junit:4.13.2")
}
