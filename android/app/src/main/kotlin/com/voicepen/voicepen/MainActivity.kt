package com.voicepen.voicepen

import android.os.Bundle
import androidx.core.splashscreen.SplashScreen.Companion.installSplashScreen
import io.flutter.embedding.android.FlutterActivity

class MainActivity : FlutterActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        // Initialize Android 12+ SplashScreen compat before super.onCreate
        installSplashScreen()
        super.onCreate(savedInstanceState)
    }
}
