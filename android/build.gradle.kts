// android/build.gradle.kts

// buildscript bloğu en üste veya allprojects'ten önce gelmeli
// ve kendi repositories tanımlamasını içermeli.
buildscript {
    repositories {
        google()        // Google'ın Maven deposu
        mavenCentral()  // Maven Central deposu
    }
    dependencies {
        // Android Gradle Plugin (AGP) için classpath.
        // Kullandığınız AGP sürümünü buraya eklemeniz gerekebilir.
        // Örnek: classpath("com.android.tools.build:gradle:8.2.0") // Projenizin AGP sürümünü kontrol edin
        // Kotlin Gradle Plugin için classpath.
        // Kullandığınız Kotlin sürümünü buraya eklemeniz gerekebilir.
        // Örnek: classpath("org.jetbrains.kotlin:kotlin-gradle-plugin:1.8.20") // Projenizin Kotlin sürümünü kontrol edin

        // Firebase için classpath
        classpath("com.google.gms:google-services:4.4.2") // 4.4.2 yerine 4.4.1 daha yaygın ve stabil olabilir,
        // Firebase dokümantasyonundan güncel ve uyumlu sürümü kontrol edin.
        // Eğer 4.4.2'de ısrarcıysanız onu kullanabilirsiniz.
    }
}

allprojects {
    repositories {
        google()
        mavenCentral()
    }
}

// --- POTANSİYEL SORUNLU BUILD DİZİNİ YÖNLENDİRMELERİ ---
// Bu bloklar standart Flutter projelerinde bulunmaz ve sorunlara yol açabilir.
// Şimdilik yorum satırı haline getiriyorum. Eğer bilerek eklemediyseniz,
// daha sonra tamamen silebilirsiniz.
/*
val newBuildDir: Directory = rootProject.layout.buildDirectory.dir("../../build").get()
rootProject.layout.buildDirectory.value(newBuildDir)

subprojects {
    val newSubprojectBuildDir: Directory = newBuildDir.dir(project.name)
    project.layout.buildDirectory.value(newSubprojectBuildDir)
}
subprojects {
    project.evaluationDependsOn(":app")
}
*/

tasks.register<Delete>("clean") {
    // Eğer yukarıdaki build dizini yönlendirmeleri kaldırılırsa,
    // bu satır standart build dizinini silecektir.
    delete(rootProject.layout.buildDirectory)
}