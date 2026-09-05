allprojects {
    repositories {
        google()
        mavenCentral()

        // The Mapbox Maps SDK does not come from pub.dev or Maven Central. It is
        // served from Mapbox's own repository behind HTTP basic auth, and the
        // password is a SECRET token (sk., scope DOWNLOADS:READ) — a different
        // credential from the public pk. one the app ships with to draw tiles.
        //
        // Read from a Gradle property or the environment, never written here:
        // this file is committed, the token is not. It lives in the developer's
        // ~/.gradle/gradle.properties, which is outside every repository, and CI
        // supplies it as MAPBOX_DOWNLOADS_TOKEN.
        //
        // Missing, the build fails at dependency resolution with a 401 on
        // com.mapbox.maps:android rather than anything mentioning a token, so
        // the message below is worth more than it looks.
        maven {
            url = uri("https://api.mapbox.com/downloads/v2/releases/maven")
            authentication { create<BasicAuthentication>("basic") }
            credentials {
                username = "mapbox"
                password = (project.findProperty("MAPBOX_DOWNLOADS_TOKEN") as String?)
                    ?: System.getenv("MAPBOX_DOWNLOADS_TOKEN")
                    ?: ""
            }
        }
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
subprojects {
    project.evaluationDependsOn(":app")
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
