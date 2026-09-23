package dev.nanoai.mobile.services

import android.content.Context
import android.graphics.Color
import android.view.Gravity
import android.widget.FrameLayout
import android.widget.LinearLayout
import android.widget.ScrollView
import android.widget.TextView

/**
 * NanoGeminiOverlayView — Panel Glass flotante desplegado directamente sobre otras apps.
 *
 * QUÉ: Interfaz de usuario flotante estilo Gemini / Snaptube que no abre MainActivity.
 * CÓMO: Encapsula la cabecera, área de resultados scrolleable y barra de herramientas.
 *       Ofrece opciones de descarga de video MP4 y audio MP3 para YouTube, X, Instagram, FB, etc.
 * POR QUÉ: Permite al usuario interactuar con Búho AI y descargar multimedia sin salir de WhatsApp/YouTube.
 * SOLID-S: Única responsabilidad: orquestar los componentes visuales del panel flotante.
 */
internal class NanoGeminiOverlayView(
    context: Context,
    onClose: () -> Unit,
    onOpenFullApp: () -> Unit,
    onAction: (tool: String, provider: String, prompt: String) -> Unit,
    private val onDownloadRequest: (url: String, audioOnly: Boolean) -> Unit,
) : LinearLayout(context) {

    private fun dp(n: Int) = NanoOverlayStyle.dp(context, n)

    private val resultBox = TextView(context)
    private val mediaActionsCol = LinearLayout(context)
    private val resultScrollView = ScrollView(context)

    init {
        orientation = VERTICAL
        background = NanoOverlayStyle.glassCard(context, radiusDp = 24)
        elevation = dp(16).toFloat()

        // 1. Barra de agarre superior (Handle bar para gesto de swipe)
        val handleBar = FrameLayout(context).apply {
            val pill = TextView(context).apply { background = NanoOverlayStyle.chip(context, active = false) }
            addView(pill, FrameLayout.LayoutParams(dp(40), dp(4), Gravity.CENTER))
        }
        addView(handleBar, LayoutParams(LayoutParams.MATCH_PARENT, dp(14)))

        // 2. Cabecera con Búho, aro cósmico y controles
        addView(NanoGeminiHeaderView(context, onClose, onOpenFullApp))

        // 3. Área de visualización de respuestas y contenido contextual
        resultBox.apply {
            text = "Listo para ayudarte. Puedes resumir esta pantalla o descargar videos MP4 y audios MP3."
            textSize = 12.5f
            setTextColor(NanoOverlayStyle.onSurface)
            setLineSpacing(dp(2).toFloat(), 1.15f)
            setPadding(dp(16), dp(6), dp(16), dp(6))
        }

        mediaActionsCol.apply {
            orientation = VERTICAL
            setPadding(dp(16), 0, dp(16), dp(6))
        }

        val scrollContent = LinearLayout(context).apply {
            orientation = VERTICAL
            addView(resultBox)
            addView(mediaActionsCol)
        }
        resultScrollView.apply {
            isVerticalScrollBarEnabled = true
            addView(scrollContent)
        }
        addView(resultScrollView, LayoutParams(LayoutParams.MATCH_PARENT, 0, 1f))

        // 4. Barra inferior de entrada y herramientas
        addView(NanoGeminiInputBar(context, onAction))
    }

    fun setLoading(message: String) {
        resultBox.text = "✦ $message…"
        resultBox.setTextColor(NanoOverlayStyle.cyanGlow)
        mediaActionsCol.removeAllViews()
    }

    /** Muestra la respuesta generada y botones de descarga MP4/MP3 estilo Snaptube. */
    fun showResult(content: String, detectedLinks: List<String> = emptyList()) {
        resultBox.text = content
        resultBox.setTextColor(NanoOverlayStyle.onSurface)
        mediaActionsCol.removeAllViews()

        // Filtrar enlaces multimedia directos o de redes sociales (YouTube, X, Insta, TikTok, FB)
        val validUrls = detectedLinks.filter { NanoMediaDownloader.isMediaUrl(it) || NanoMediaResolver.isSupportedSocialUrl(it) }
        for (url in validUrls) {
            val isDirect = NanoMediaDownloader.isMediaUrl(url)
            val domain = url.substringAfter("://").substringBefore("/")

            // Fila horizontal con botones de descarga rápida MP4 y MP3
            val row = LinearLayout(context).apply {
                orientation = HORIZONTAL
                val label = TextView(context).apply {
                    text = "📥 $domain:"
                    textSize = 11f
                    setTextColor(NanoOverlayStyle.onSurfaceMuted)
                    setPadding(0, 0, dp(6), 0)
                }
                addView(label, LayoutParams(LayoutParams.WRAP_CONTENT, LayoutParams.WRAP_CONTENT))

                // Botón Video MP4
                val btnMp4 = createMediaButton("🎬 Video MP4") {
                    onDownloadRequest(url, false)
                    resultBox.text = "⏳ Resolviendo descarga de Video MP4…"
                }
                addView(btnMp4, LayoutParams(0, LayoutParams.WRAP_CONTENT, 1f).apply { rightMargin = dp(4) })

                // Botón Audio MP3
                val btnMp3 = createMediaButton("🎵 Audio MP3") {
                    onDownloadRequest(url, true)
                    resultBox.text = "⏳ Resolviendo descarga de Audio MP3…"
                }
                addView(btnMp3, LayoutParams(0, LayoutParams.WRAP_CONTENT, 1f))
            }
            mediaActionsCol.addView(row, LayoutParams(LayoutParams.MATCH_PARENT, LayoutParams.WRAP_CONTENT).apply {
                topMargin = dp(6)
            })
        }
        resultScrollView.post { resultScrollView.fullScroll(ScrollView.FOCUS_DOWN) }
    }

    private fun createMediaButton(title: String, onClick: () -> Unit): TextView =
        TextView(context).apply {
            text = title
            textSize = 11f
            setTextColor(Color.WHITE)
            gravity = Gravity.CENTER
            background = NanoOverlayStyle.actionButton(context)
            setPadding(dp(8), dp(7), dp(8), dp(7))
            isClickable = true
            setOnClickListener { onClick(); isEnabled = false }
        }
}
