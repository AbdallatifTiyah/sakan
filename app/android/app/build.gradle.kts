import java.util.Properties
import java.io.FileInputStream

plugins {
    id("com.android.application")
    // START: FlutterFire Configuration
    id("com.google.gms.google-services")
    // END: FlutterFire Configuration
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

// key.properties/keystore يعيشان برّا الريبو عمداً (قاعدة ٥ بـCLAUDE.md — ممنوع
// أي مفتاح سري بالريبو). على أي جهاز تاني بدون هالملف، البناء بيرجع تلقائياً
// لتوقيع debug بدل ما يفشل بالكامل.
val sakannaKeyPropertiesFile = file("C:/Users/abdti/sakanna-keystore/key.properties")
val sakannaKeyProperties = Properties()
if (sakannaKeyPropertiesFile.exists()) {
    sakannaKeyProperties.load(FileInputStream(sakannaKeyPropertiesFile))
}

android {
    namespace = "ps.sakanna.app"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "ps.sakanna.app"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    signingConfigs {
        if (sakannaKeyPropertiesFile.exists()) {
            create("release") {
                keyAlias = sakannaKeyProperties.getProperty("keyAlias")
                keyPassword = sakannaKeyProperties.getProperty("keyPassword")
                storeFile = file(sakannaKeyProperties.getProperty("storeFile"))
                storePassword = sakannaKeyProperties.getProperty("storePassword")
            }
        }
    }

    buildTypes {
        release {
            signingConfig = if (sakannaKeyPropertiesFile.exists()) {
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
