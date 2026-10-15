import org.jetbrains.kotlin.gradle.dsl.JvmTarget

plugins {
    alias(libs.plugins.kotlinMultiplatform)
    alias(libs.plugins.androidLibrary)
}

kotlin {
    // ── Targets ──────────────────────────────────────────────────────────────
    androidTarget {
        compilerOptions { jvmTarget.set(JvmTarget.JVM_17) }
        publishLibraryVariants("release")
    }

    // iOS: arm64 (device) + simulator (intel + apple silicon)
    iosArm64()
    iosSimulatorArm64()
    iosX64()

    // ── Source sets ───────────────────────────────────────────────────────────
    sourceSets {
        // ── common ────────────────────────────────────────────────────────────
        commonMain.dependencies {
            implementation(libs.kotlinx.coroutines.core)
        }
        commonTest.dependencies {
            implementation(libs.kotlin.test)
            implementation(libs.kotlinx.coroutines.test)
        }

        // ── android ───────────────────────────────────────────────────────────
        androidMain.dependencies {
            // Las clases Android del módulo flutter_app ya existen; aquí
            // NO se recompilan — se usan como implementación `actual` en los
            // adaptadores de este módulo.
            implementation(libs.kotlinx.coroutines.android)
        }

        // ── ios ───────────────────────────────────────────────────────────────
        iosMain.dependencies {
            // Kotlin/Native puede llamar a CoreML, AVFoundation y AppIntents
            // directamente a través del bridge Objective-C / C interop.
            // No se necesitan dependencias adicionales aquí.
        }
    }
}

android {
    namespace = "dev.nanoai.core"
    compileSdk = 35
    defaultConfig { minSdk = 26 }
    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }
}
