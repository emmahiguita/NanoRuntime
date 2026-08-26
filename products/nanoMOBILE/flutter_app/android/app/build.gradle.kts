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

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_17.toString()
    }

    defaultConfig {
        applicationId = "dev.nanoai.mobile"
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
            //
            // Variables requeridas para firma de producción:
            //   NANOAI_KEYSTORE       — ruta absoluta al archivo .jks/.keystore
            //   NANOAI_KEYSTORE_PASS  — contraseña del almacén
            //   NANOAI_KEY_ALIAS      — alias de la clave dentro del almacén
            //   NANOAI_KEY_PASS       — contraseña de la clave
            //
            // CI/CD: configurar como secrets en GitHub Actions / Codemagic.
            // Local:  export NANOAI_KEYSTORE=/ruta/a/release.keystore && flutter build apk --release
            val keystorePath = System.getenv("NANOAI_KEYSTORE")
            if (keystorePath != null) {
                storeFile = file(keystorePath)
                storePassword = System.getenv("NANOAI_KEYSTORE_PASS")
                keyAlias = System.getenv("NANOAI_KEY_ALIAS")
                keyPassword = System.getenv("NANOAI_KEY_PASS")
                println("NanoAI: release signing con keystore externo: $keystorePath")
            } else {
                // Fallback a debug keystore para `flutter run --release` en desarrollo.
                // ⚠️ NO distribuir APKs firmadas con este certificado.
                storeFile = signingConfigs.getByName("debug").storeFile
                storePassword = signingConfigs.getByName("debug").storePassword
                keyAlias = signingConfigs.getByName("debug").keyAlias
                keyPassword = signingConfigs.getByName("debug").keyPassword
                println("NanoAI: release signing con debug keystore (SOLO DESARROLLO)")
            }
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
    // Coroutines para operaciones async en platform channel handlers
    // (download/extract del rootfs Termux en background thread).
    implementation("org.jetbrains.kotlinx:kotlinx-coroutines-core:1.8.1")
    implementation("org.jetbrains.kotlinx:kotlinx-coroutines-android:1.8.1")
    implementation("org.tukaani:xz:1.9")
    // A9: OCR on-device (bundled, sin Google Play Services) como fallback de
    // percepción cuando Accessibility no resuelve. Detrás de OcrBackend.
    implementation("com.google.mlkit:text-recognition:16.0.1")
    // A14.3: API oficial de Shizuku (dev.rikka.shizuku:api) — SOLO disponibilidad
    // FACTUAL (pingBinder/checkSelfPermission, ambas pasivas: sin diálogo, sin
    // acciones privilegiadas). La ejecución Shizuku es A14.4 con capacidades
    // tipadas, nunca shell arbitrario. Apache-2.0, minSdk 23 <= nuestro minSdk 26.
    // Artefacto: github.com/rikkaapps/shizuku (api/manifest.gradle, v13.1.5).
    implementation("dev.rikka.shizuku:api:13.1.5")
}

