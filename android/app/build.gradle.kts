import java.util.Properties
import java.io.FileInputStream

plugins {
    id("com.android.application")
    // START: FlutterFire Configuration
    id("com.google.gms.google-services")
    // END: FlutterFire Configuration
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

val keystoreProperties = Properties()
val keystorePropertiesFile = rootProject.file("key.properties")
if (keystorePropertiesFile.exists()) {
    keystoreProperties.load(FileInputStream(keystorePropertiesFile))
}

android {
    namespace = "com.waterdropapp.adecommerce.development"
    compileSdk = flutter.compileSdkVersion
    // ndkVersion = flutter.ndkVersion
    ndkVersion = "27.0.12077973"

    compileOptions {
        isCoreLibraryDesugaringEnabled = true
        sourceCompatibility = JavaVersion.VERSION_11
        targetCompatibility = JavaVersion.VERSION_11
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_11.toString()
    }

    defaultConfig {
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    
        multiDexEnabled = true
    }

    signingConfigs {
        create("release") {
            keyAlias = keystoreProperties["keyAlias"] as String
            keyPassword = keystoreProperties["keyPassword"] as String
            storeFile = keystoreProperties["storeFile"]?.let { file(it) }
            storePassword = keystoreProperties["storePassword"] as String
        }
    }

    buildTypes {
        release {
            // TODO: Add your own signing config for the release build.
            // Signing with the debug keys for now, so `flutter run --release` works.
            signingConfig = signingConfigs.getByName("release")
        }
    }

    flavorDimensions += "environment"

    productFlavors {
        create("dev") {
            dimension = "environment"
            applicationId = "com.waterdropapp.adecommerce.development"
            manifestPlaceholders["appLabel"] = "水滴APP(Dev)"
            manifestPlaceholders["deepLinkScheme"] = "waterdrop-dev"
            manifestPlaceholders["deepLinkHost"] = "api.waterdropping.com"
        }

        create("stg") {
            dimension = "environment"
            applicationId = "com.waterdropapp.adecommerce.stg"
            manifestPlaceholders["appLabel"] = "水滴APP(Stg)"
            manifestPlaceholders["deepLinkScheme"] = "waterdrop-stg"
            manifestPlaceholders["deepLinkHost"] = "stg-api.waterdropping.com"
        }
    }
}

dependencies {
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")
}

flutter {
    source = "../.."
}
