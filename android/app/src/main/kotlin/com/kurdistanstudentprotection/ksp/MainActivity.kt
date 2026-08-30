package com.kurdistanstudentprotection.ksp

import io.flutter.embedding.android.FlutterFragmentActivity

/**
 * A FragmentActivity, not a plain FlutterActivity.
 *
 * The biometric prompt is a fragment. On a plain FlutterActivity local_auth
 * throws "no_fragment_activity" the first time a parent tries to confirm a
 * leave request with a fingerprint — at the exact moment the app is asking them
 * to prove who they are.
 */
class MainActivity : FlutterFragmentActivity()
