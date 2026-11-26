plugins {
    id("com.android.application")
    id("org.jetbrains.kotlin.android")
}

android {
    namespace = "uz.nazorat.app"
    compileSdk = 34

    defaultConfig {
        applicationId = "uz.nazorat.app"
        minSdk = 24
        targetSdk = 33
        versionCode = 9
        versionName = "0.9"
    }

    buildFeatures { buildConfig = true }

    flavorDimensions += "mode"
    productFlavors {
        create("yashirin") {
            dimension = "mode"
            // applicationId default: uz.nazorat.app ; nom: "VPN"
            buildConfigField("boolean", "OPEN", "false")
        }
        create("ochiq") {
            dimension = "mode"
            applicationId = "uz.nazorat.ochiq"
            buildConfigField("boolean", "OPEN", "true")
        }
    }

    buildTypes {
        release {
            isMinifyEnabled = false
            proguardFiles(
                getDefaultProguardFile("proguard-android-optimize.txt"),
                "proguard-rules.pro"
            )
        }
    }
    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }
    kotlinOptions {
        jvmTarget = "17"
    }
}

dependencies {
    implementation("androidx.core:core-ktx:1.12.0")
    implementation("androidx.appcompat:appcompat:1.6.1")
    implementation("com.google.android.material:material:1.11.0")
}
