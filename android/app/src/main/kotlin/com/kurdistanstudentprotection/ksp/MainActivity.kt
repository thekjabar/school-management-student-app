package com.kurdistanstudentprotection.ksp

import android.content.pm.PackageManager
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

/**
 * A FragmentActivity, not a plain FlutterActivity.
 *
 * The biometric prompt is a fragment. On a plain FlutterActivity local_auth
 * throws "no_fragment_activity" the first time a parent tries to confirm a
 * leave request with a fingerprint — at the exact moment the app is asking them
 * to prove who they are.
 */
class MainActivity : FlutterFragmentActivity() {

    /**
     * One question, asked once, by the parent tracking screen: DID THE MAPS KEY
     * ARRIVE IN THIS BUILD?
     *
     * The key is substituted into the manifest from android/local.properties,
     * which is gitignored, so a fresh checkout has no key at all. Dart cannot
     * see the merged manifest, and the Maps SDK reports a missing key by
     * quietly rendering nothing — a grey rectangle where a parent is looking
     * for their child, with no way for the app to know it happened.
     *
     * So the value is read here and handed across. When it is empty the
     * tracking screen never builds a map at all: it says, in words, that the
     * key has not been set. Everything else on the screen — where she is, the
     * bus, the driver, the stop — needs no map and keeps working.
     */
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, MAPS_CHANNEL)
            .setMethodCallHandler { call, result ->
                if (call.method == "hasKey") {
                    result.success(mapsKeyPresent())
                } else {
                    result.notImplemented()
                }
            }
    }

    private fun mapsKeyPresent(): Boolean = try {
        val info = packageManager.getApplicationInfo(packageName, PackageManager.GET_META_DATA)
        // getString returns null for a value the manifest stored as anything
        // other than a string, which is the same answer we want anyway: not a
        // usable key.
        !info.metaData?.getString(MAPS_KEY_METADATA).isNullOrBlank()
    } catch (e: PackageManager.NameNotFoundException) {
        // The app asking about its own package. If this ever happens the honest
        // answer is "cannot tell", and the screen treats that as "no key".
        false
    }

    private companion object {
        const val MAPS_CHANNEL = "ksp/maps"
        const val MAPS_KEY_METADATA = "com.google.android.geo.API_KEY"
    }
}
