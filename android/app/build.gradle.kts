import java.util.Properties
import java.io.FileInputStream

plugins {
    id("com.android.application")
    id("kotlin-android")
    id("dev.flutter.flutter-gradle-plugin")
    id("com.google.gms.google-services")
}

android {
    namespace = "com.example.grid_storage_nfc"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    // --- ŁADOWANIE KLUCZA (POPRAWIONE) ---
    val keystoreProperties = Properties()
    val keystorePropertiesFile = rootProject.file("key.properties")
    if (keystorePropertiesFile.exists()) {
        keystoreProperties.load(FileInputStream(keystorePropertiesFile))
    }
    // -------------------------------------

    flavorDimensions += "env"

    productFlavors {
        create("office") {
            dimension = "env"
            applicationIdSuffix = ".office"
            resValue("string", "app_name", "Grid Storage (Office)")
        }
        create("home") {
            dimension = "env"
            applicationId = "com.pryhodskyimykola.gridstorage"
            resValue("string", "app_name", "Grid Storage")
        }
    }

    compileOptions {
        isCoreLibraryDesugaringEnabled = true
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    kotlinOptions {
        jvmTarget = "17" // Poprawiona składnia (zamiast .toString())
    }

    defaultConfig {
        applicationId = "com.example.grid_storage_nfc"
        minSdk = 24
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    // --- KONFIGURACJA PODPISU ---
    signingConfigs {
        create("release") {
            // Używamy .getProperty, co jest bezpieczniejsze w Kotlinie dla Properties
            keyAlias = keystoreProperties.getProperty("keyAlias")
            keyPassword = keystoreProperties.getProperty("keyPassword")
            storeFile = if (keystoreProperties.getProperty("storeFile") != null) {
                file(keystoreProperties.getProperty("storeFile"))
            } else {
                null
            }
            storePassword = keystoreProperties.getProperty("storePassword")
        }
    }

    buildTypes {
        release {
            signingConfig = signingConfigs.getByName("release")
            
            isMinifyEnabled = true
            isShrinkResources = true
            proguardFiles(
                getDefaultProguardFile("proguard-android-optimize.txt"),
                "proguard-rules.pro"
            )
        }
    }
}

flutter {
    source = "../.."
}

dependencies {
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")
}