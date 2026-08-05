package com.nanoai

import android.os.Bundle
import androidx.activity.ComponentActivity
import androidx.activity.compose.setContent
import androidx.activity.enableEdgeToEdge
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import com.nanoai.ui.navigation.NanoNavHost
import com.nanoai.ui.theme.NanoAITheme
import com.nanoai.ui.theme.ThemeViewModel

class MainActivity : ComponentActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        enableEdgeToEdge()
        setContent {
            val themeMode by ThemeViewModel.mode.collectAsState()
            NanoAITheme(themeMode = themeMode) {
                NanoNavHost()
            }
        }
    }
}
