import java.util.Properties
import java.io.FileInputStream

plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
    id("com.google.gms.google-services")
}

// 讀取 key.properties（KTS 寫法）
val keystoreProperties = Properties()
val keystorePropertiesFile = rootProject.file("key.properties")
if (keystorePropertiesFile.exists()) {
    FileInputStream(keystorePropertiesFile).use { fis ->
        keystoreProperties.load(fis)
    }
}

android {
    namespace = "com.example.chcg_iot_app"
    compileSdk = 36
    ndkVersion = "28.2.13676358"

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_11
        targetCompatibility = JavaVersion.VERSION_11
    }
    kotlin {
        compilerOptions {
            jvmTarget.set(org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_11)
        }
    }

    defaultConfig {
        applicationId = "com.agritalk.chcg_iot_app"
        minSdk = 23
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    // 先宣告簽章，再在 buildTypes 使用
    signingConfigs {
        create("release") {
            val alias = keystoreProperties["keyAlias"] as String?
            val keyPass = keystoreProperties["keyPassword"] as String?
            val store = keystoreProperties["storeFile"] as String?
            val storePass = keystoreProperties["storePassword"] as String?

            if (alias != null) keyAlias = alias
            if (keyPass != null) keyPassword = keyPass
            if (store != null) storeFile = file(store)
            if (storePass != null) storePassword = storePass
        }
    }

    buildTypes {
        release {
            signingConfig = signingConfigs.getByName("release")
            // 依需要開/關混淆與資源壓縮
            isMinifyEnabled = false
            isShrinkResources = false
            // 若後續要開混淆，別忘了 proguard-android-optimize.txt / proguard-rules.pro
        }
        debug {
            // 確保 debug 不會誤用 release 簽章
            signingConfig = signingConfigs.getByName("debug")
        }
    }

    packaging {
        jniLibs {
            pickFirsts += listOf("**/libc++_shared.so")
        }
    }
}

flutter {
    source = "../.."
}
