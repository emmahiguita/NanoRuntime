plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "dev.nanoai.mobile"
    compileSdk = 36
    ndkVersion = "28.2.13676358"

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    // A14.4: habilita la compilación de AIDL (UserService de Shizuku) y BuildConfig.
    buildFeatures {
        aidl = true
        buildConfig = true
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_17.toString()
    }

    defaultConfig {
        applicationId = "dev.nanoai.mobile"
        testInstrumentationRunner =
            "dev.nanoai.mobile.services.RemoteInputFixtureInstrumentation"
        // minSdk 26 = Android 8.0 (linker namespaces require API 24+;
        // 26 chosen for Treble/VNDK stability and >=95% device coverage).
        minSdk = 26
        // Play exige targetSdk 36 (Android 16) a partir de 31-ago-2026.
        targetSdk = 36
        versionCode = flutter.versionCode
        versionName = flutter.versionName

        ndk {
            // Solo arm64-v8a: todos los binarios nativos (Xvnc, openbox,
            // libnanoshell.so, libnanoroot.so) son aarch64.
            abiFilters.add("arm64-v8a")
        }
    }

    flavorDimensions += listOf("distribution")

    productFlavors {
        create("playStore") {
            dimension = "distribution"
            applicationId = "dev.nanoai.mobile"
            buildConfigField("boolean", "PLAY_STORE_BUILD", "true")
        }
        create("fullSideload") {
            dimension = "distribution"
            applicationId = "dev.nanoai.mobile"
            buildConfigField("boolean", "PLAY_STORE_BUILD", "false")
        }
    }

    externalNativeBuild {
        cmake {
            path = file("src/main/cpp/CMakeLists.txt")
            version = "3.22.1"
        }
    }

    signingConfigs {
        create("release") {
            // Signing config lee credenciales de variables de entorno.
            // Si no están definidas, fallback a debug keystore (solo desarrollo).
            val keystorePath = System.getenv("NANOAI_KEYSTORE")
            if (keystorePath != null) {
                storeFile = file(keystorePath)
                storePassword = System.getenv("NANOAI_KEYSTORE_PASS")
                keyAlias = System.getenv("NANOAI_KEY_ALIAS")
                keyPassword = System.getenv("NANOAI_KEY_PASS")
                println("NanoAI: release signing con keystore externo.")
            } else {
                storeFile = signingConfigs.getByName("debug").storeFile
                storePassword = signingConfigs.getByName("debug").storePassword
                keyAlias = signingConfigs.getByName("debug").keyAlias
                keyPassword = signingConfigs.getByName("debug").keyPassword
                println("NanoAI: release signing con debug keystore (SOLO DESARROLLO)")
            }
        }
    }

    packaging {
        jniLibs {
            // El runtime abre .so por ruta: deben ir comprimidas y extraerse.
            useLegacyPackaging = true
        }
        resources {
            excludes += "/META-INF/{AL2.0,LGPL2.1}"
            pickFirsts += "assets/mlkit-google-ocr-models/**"
            pickFirsts += "assets/mlkit_label_default_model/**"
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
    testImplementation("junit:junit:4.13.2")
    implementation("org.jetbrains.kotlinx:kotlinx-coroutines-core:1.8.1")
    implementation("org.jetbrains.kotlinx:kotlinx-coroutines-android:1.8.1")
    implementation("org.tukaani:xz:1.9")
    implementation("com.google.mlkit:text-recognition:16.0.1")
    implementation("com.google.mlkit:barcode-scanning:17.3.0")
    implementation("com.google.mlkit:image-labeling:17.0.8")
    implementation("dev.rikka.shizuku:api:13.1.5")
    implementation("dev.rikka.shizuku:provider:13.1.5")
}
