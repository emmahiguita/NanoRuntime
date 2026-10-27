package dev.nanoai.mobile.services

import android.content.Context
import android.view.Gravity
import android.view.View
import android.widget.*

/** Panel Android compacto con un único desplazamiento. Reutiliza los callbacks
 * existentes y los tokens de Nano; no sustituye la animación de la burbuja. */
internal class NanoGeminiOverlayView(
    context: Context,
    onClose: () -> Unit,
    onOpenFullApp: () -> Unit,
    onAction: (tool: String, provider: String, prompt: String) -> Unit,
    private val onDownloadRequest: (String, Boolean) -> Unit,
    initialTool: String = "Chat",
    initialDraft: String = "",
    onDraftChanged: (String) -> Unit = {},
    onToolSelected: (String) -> Unit = {},
) : LinearLayout(context) {
    /** Reutiliza dimensiones del tema para resultados y controles adaptativos. */
    private fun dp(n: Int) = NanoOverlayStyle.dp(context, n)
    private val resultBox = TextView(context)
    private val mediaActionsCol = LinearLayout(context)
    private lateinit var inputBar: NanoGeminiInputBar
    private val scroll = ScrollView(context)
    private val speechControl = NanoPanelSpeechControl(context, onAction)

    init {
        NanoOverlayStyle.configure(context)
        orientation = VERTICAL
        background = NanoOverlayStyle.glassCard(context, 28)
        elevation = dp(12).toFloat()
        val body = LinearLayout(context).apply { orientation = VERTICAL }
        body.addView(NanoGeminiHeaderView(context, onClose, onOpenFullApp) {
            onAction("Historial", "nano", "")
        })
        resultBox.apply {
            textSize = 13.5f
            setTextColor(NanoOverlayStyle.onSurface)
            setLineSpacing(dp(2).toFloat(), 1.2f)
            setPadding(dp(16), dp(4), dp(16), dp(12))
            setTextIsSelectable(true)
            visibility = GONE
        }
        body.addView(resultBox)
        body.addView(speechControl)
        mediaActionsCol.apply {
            orientation = VERTICAL
            setPadding(dp(16), 0, dp(16), dp(4))
        }
        body.addView(mediaActionsCol)
        inputBar = NanoGeminiInputBar(context, onAction, initialTool, initialDraft, onDraftChanged, onToolSelected)
        body.addView(inputBar)
        scroll.addView(body)
        addView(scroll, LayoutParams(LayoutParams.MATCH_PARENT, LayoutParams.WRAP_CONTENT))
    }

    /** Limita la ventana al espacio disponible; el contenido puede desplazarse
     * en horizontal, con teclado o con fuentes grandes, sin una altura vacía fija. */
    override fun onMeasure(widthSpec: Int, heightSpec: Int) {
        val cap = (resources.displayMetrics.heightPixels * .72f).toInt()
        val available = if (View.MeasureSpec.getMode(heightSpec) == View.MeasureSpec.UNSPECIFIED)
            cap else minOf(cap, View.MeasureSpec.getSize(heightSpec))
        super.onMeasure(widthSpec, View.MeasureSpec.makeMeasureSpec(available, View.MeasureSpec.AT_MOST))
    }

    /** Ocupado bloquea el editor. Solo consultas con cancelación conectada
     * convierten la acción principal en solicitud de detener. */
    fun setLoading(message: String, canStop: Boolean = false) {
        speechControl.clear()
        inputBar.setBusy(true, canStop)
        resultBox.visibility = VISIBLE
        resultBox.text = message
        resultBox.setTextColor(NanoOverlayStyle.onSurfaceMuted)
        mediaActionsCol.removeAllViews()
    }

    /** Muestra el resultado que entrega el puente, sin inventar confirmación. */
    fun showResult(content: String, detectedLinks: List<String> = emptyList()) {
        speechControl.prepare(content)
        inputBar.setBusy(false)
        resultBox.visibility = VISIBLE
        resultBox.text = content
        resultBox.setTextColor(NanoOverlayStyle.onSurface)
        mediaActionsCol.removeAllViews()
        val urls = detectedLinks.filter {
            NanoMediaDownloader.isMediaUrl(it) || NanoMediaResolver.isSupportedSocialUrl(it)
        }
        for (url in urls) {
            val domain = url.substringAfter("://").substringBefore("/")
            mediaActionsCol.addView(NanoOverlayStyle.text(context, domain, 11.5f,
                color = NanoOverlayStyle.onSurfaceMuted))
            val row = LinearLayout(context).apply { orientation = HORIZONTAL }
            row.addView(mediaButton("Vídeo original") { onDownloadRequest(url, false) },
                LayoutParams(0, LayoutParams.WRAP_CONTENT, 1f))
            row.addView(mediaButton("Audio original") { onDownloadRequest(url, true) },
                LayoutParams(0, LayoutParams.WRAP_CONTENT, 1f))
            mediaActionsCol.addView(row)
        }
    }

    /** Informa errores reales de voz sin sustituir respuesta ni estado del editor. */
    fun showSpeechFailure(message: String) { speechControl.showFailure(message) }

    /** Conserva las descargas existentes sin superficies anidadas ni texto multicolor. */
    private fun mediaButton(title: String, action: () -> Unit) = TextView(context).apply {
        text = title
        textSize = 12f
        gravity = Gravity.CENTER
        minHeight = dp(48)
        setTextColor(NanoOverlayStyle.onSurface)
        background = NanoOverlayStyle.inputCard(context)
        setPadding(dp(8), dp(6), dp(8), dp(6))
        isClickable = true
        setOnClickListener { action(); isEnabled = false }
    }
}
