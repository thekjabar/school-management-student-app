plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

// The Google Maps key, which is NOT in this repository and must not be.
//
// The parent tracking screen draws a Google map. The native SDK reads its key
// from the merged manifest, so it has to be in the APK — but a key committed to
// a repository is a key that has to be rotated the first time the repository is
// copied. So it is read from android/local.properties, which is already
// gitignored, and substituted into the manifest at build time.
//
// Absent, this is the empty string, and the build still succeeds. That is
// deliberate: a checkout with no key must compile and run so the rest of the
// app can be worked on, and the tracking screen asks the platform whether the
// key arrived and says so in words rather than showing a dead grey rectangle.
//
// The owner adds one line to android/local.properties:
//     maps.apiKey=AIza...
val mapsApiKey: String = java.util.Properties().apply {
    val file = rootProject.file("local.properties")
    if (file.exists()) file.inputStream().use { load(it) }
}.getProperty("maps.apiKey", "")

android {
    namespace = "com.kurdistanstudentprotection.ksp"
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
        // Kurdistan Student Protection. Each flavour suffixes this, so the five
        // audiences can sit on one phone at once.
        //
        // Changed from com.edupulse.student_app during the rebrand. Android
        // treats a new id as a different app, so an existing install has to be
        // removed rather than upgraded — done now, while that costs one
        // uninstall, because an id that reaches Play is fixed for the life of
        // the listing.
        applicationId = "com.kurdistanstudentprotection.ksp"
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName

        // Substituted into AndroidManifest.xml's com.google.android.geo.API_KEY.
        // Empty when the property is absent — see the note at the top of this
        // file for why that is allowed to build.
        manifestPlaceholders["mapsApiKey"] = mapsApiKey
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
            resValue("string", "app_name", "KSP Parent")
        }
        create("student") {
            dimension = "role"
            applicationIdSuffix = ".student"
            resValue("string", "app_name", "KSP Student")
        }
        create("teacher") {
            dimension = "role"
            applicationIdSuffix = ".teacher"
            resValue("string", "app_name", "KSP Teacher")
        }
        create("driver") {
            dimension = "role"
            applicationIdSuffix = ".driver"
            resValue("string", "app_name", "KSP Driver")
        }
        create("admin") {
            dimension = "role"
            applicationIdSuffix = ".admin"
            resValue("string", "app_name", "KSP Admin")
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
