import java.util.Properties
import java.io.FileInputStream

plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

// Ключ подписи держим вне репозитория: android/key.properties в .gitignore.
// Если файла нет (у нового разработчика или в CI без секретов) — release
// собирается debug-ключом, чтобы сборка не падала. Такой артефакт годится
// только для проверки, RuStore его не примет.
val keystoreProperties = Properties()
val keystorePropertiesFile = rootProject.file("key.properties")
val hasReleaseKey = keystorePropertiesFile.exists()
if (hasReleaseKey) {
    keystoreProperties.load(FileInputStream(keystorePropertiesFile))
}

android {
    namespace = "ru.effectvr.vr_booking_web"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        // Менять до первой публикации: в RuStore applicationId закрепляется
        // за приложением навсегда.
        applicationId = "ru.effectvr.vr_booking_web"
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    // Два приложения из одного кода:
    // client — «Бронирование VR» для клиентов (публикуется в RuStore);
    // staff  — «VR Админка» для персонала, ставится на телефоны сотрудников
    //          вручную. Свой applicationId, поэтому оба живут на одном
    //          телефоне рядом. Временное решение до переноса онлайн-броней
    //          в приложение-менеджер.
    // Название приложения задаётся во флейворе через resValue — в новых AGP
    // эта возможность по умолчанию выключена.
    buildFeatures {
        resValues = true
    }

    flavorDimensions += "app"
    productFlavors {
        create("client") {
            dimension = "app"
            resValue("string", "app_name", "Бронирование VR")
        }
        create("staff") {
            dimension = "app"
            applicationIdSuffix = ".staff"
            resValue("string", "app_name", "VR Админка")
        }
    }

    signingConfigs {
        if (hasReleaseKey) {
            create("release") {
                keyAlias = keystoreProperties["keyAlias"] as String
                keyPassword = keystoreProperties["keyPassword"] as String
                storeFile = keystoreProperties["storeFile"]?.let { file(it) }
                storePassword = keystoreProperties["storePassword"] as String
            }
        }
    }

    buildTypes {
        release {
            signingConfig = if (hasReleaseKey) {
                signingConfigs.getByName("release")
            } else {
                signingConfigs.getByName("debug")
            }
        }
    }
}

kotlin {
    compilerOptions {
        jvmTarget = org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17
    }
}

flutter {
    source = "../.."
}
