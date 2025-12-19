plugins {
    id("com.android.application")
    id("kotlin-android")
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "com.example.stock_alarm"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        isCoreLibraryDesugaringEnabled = true
        sourceCompatibility = JavaVersion.VERSION_11 // De 1_8 a 11
        targetCompatibility = JavaVersion.VERSION_11 // De 1_8 a 11
    }

    kotlinOptions {
        jvmTarget = "11" // De 1.8 a 11
    }

    defaultConfig {
        applicationId = "com.example.stock_alarm"
        // El servicio de segundo plano requiere mínimo nivel 21
        minSdk = flutter.minSdkVersion 
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
        
        // Evita errores de límite de métodos al añadir librerías
        multiDexEnabled = true
    }

    buildTypes {
        release {
            signingConfig = signingConfigs.getByName("debug")
        }
    }
}

flutter {
    source = "../.."
}

dependencies {
    // Esta librería es la que permite el desugaring
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.0.3")
}
