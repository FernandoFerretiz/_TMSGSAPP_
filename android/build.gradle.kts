allprojects {
    repositories {
        google()
        mavenCentral()
    }
}

val newBuildDir: Directory =
    rootProject.layout.buildDirectory
        .dir("../../build")
        .get()
rootProject.layout.buildDirectory.value(newBuildDir)

subprojects {
    val newSubprojectBuildDir: Directory = newBuildDir.dir(project.name)
    project.layout.buildDirectory.value(newSubprojectBuildDir)
}
// file_picker (y otros plugins viejos) se compilan contra un compileSdk menor
// al que exige flutter_plugin_android_lifecycle (36): el build release falla en
// checkReleaseAarMetadata. Se sube el compileSdk de las librerías que queden
// por debajo — no cambia targetSdk ni minSdk. Debe registrarse antes de
// evaluationDependsOn(":app") para que afterEvaluate aún sea válido.
subprojects {
    afterEvaluate {
        extensions.findByType(com.android.build.gradle.LibraryExtension::class.java)?.let { lib ->
            if ((lib.compileSdk ?: 0) < 36) {
                lib.compileSdk = 36
            }
        }
    }
}
subprojects {
    project.evaluationDependsOn(":app")
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
