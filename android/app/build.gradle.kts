plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "com.edupulse.student_app"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_17.toString()
    }

    defaultConfig {
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "com.edupulse.student_app"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    // One codebase, five apps. Each audience gets its own applicationId so all
    // of them can sit on one phone at once — which is what a school actually
    // needs when it is testing, and what a family needs when a parent is also
    // a teacher at the same school.
    flavorDimensions += "role"
    productFlavors {
        create("parent") {
            dimension = "role"
            applicationIdSuffix = ".parent"
            resValue("string", "app_name", "EduPulse Parent")
        }
        create("student") {
            dimension = "role"
            applicationIdSuffix = ".student"
            resValue("string", "app_name", "EduPulse Student")
        }
        create("teacher") {
            dimension = "role"
            applicationIdSuffix = ".teacher"
            resValue("string", "app_name", "EduPulse Teacher")
        }
        create("driver") {
            dimension = "role"
            applicationIdSuffix = ".driver"
            resValue("string", "app_name", "EduPulse Driver")
        }
        create("admin") {
            dimension = "role"
            applicationIdSuffix = ".admin"
            resValue("string", "app_name", "EduPulse Admin")
        }
    }

    buildTypes {
        release {
            // TODO: Add your own signing config for the release build.
            // Signing with the debug keys for now, so `flutter run --release` works.
            signingConfig = signingConfigs.getByName("debug")
        }
    }
}

flutter {
    source = "../.."
}
