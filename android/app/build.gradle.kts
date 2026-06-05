
plugins {
    id("com.android.application")
    // START: FlutterFire Configuration
    id("com.google.gms.google-services")
    // END: FlutterFire Configuration
    id("kotlin-android")
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "com.grademate.talktandem"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    // Configure your release signing properties manually
    signingConfigs {
        create("release") {
            keyAlias = "upload"
            keyPassword = "Ganeshgana@4262"
            storePassword = "Ganeshgana@4262"
            // Ensure double backslashes are used for Windows paths
            storeFile = file("C:\\Users\\ganesh\\talktandem-keystore.jks")
        }
    }

    defaultConfig {
        applicationId = "com.grademate.talktandem"
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    buildTypes {
        release {
            // Apply your manual release configuration here
            signingConfig = signingConfigs.getByName("release")
            
            // FIXED KOTLIN DSL SYNTAX HERE:
            isMinifyEnabled = false
            isShrinkResources = false
        }
    }
}

flutter {
    source = "../.."
}

kotlin {
    jvmToolchain(17)
}