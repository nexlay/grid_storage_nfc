plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
    id("com.google.gms.google-services")
}

android {
    namespace = "com.example.grid_storage_nfc"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion
    
    // Definiujemy wymiar dla wariantów (flavors)
    flavorDimensions += "env"

    productFlavors {
        // Wariant Office: Zostaje bez zmian (używany lokalnie)
        create("office") {
            dimension = "env"
            // Wynikowe ID: com.example.grid_storage_nfc.office
            applicationIdSuffix = ".office"
            resValue("string", "app_name", "Grid Storage (Office)")
        }
        
        // Wariant Home: Dostosowany do Google Play (PRODUKCJA)
        create("home") {
            dimension = "env"
            // Ustawiamy profesjonalne, unikalne ID dla sklepu (nadpisuje domyślne)
            applicationId = "com.pryhodskyimykola.gridstorage" 
            // Nazwa widoczna dla użytkownika w sklepie i na telefonie
            resValue("string", "app_name", "Grid Storage") 
        }
    }

    compileOptions {
        isCoreLibraryDesugaringEnabled = true
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17 
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_17.toString()
    }

    defaultConfig {
        // To ID jest bazą dla wariantu 'office'
        applicationId = "com.example.grid_storage_nfc"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = 24
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
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

dependencies {
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")
}