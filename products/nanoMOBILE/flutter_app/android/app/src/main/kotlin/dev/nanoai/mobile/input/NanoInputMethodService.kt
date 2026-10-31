package dev.nanoai.mobile.input

import android.content.ClipboardManager
import android.content.Context
import android.content.Intent
import android.inputmethodservice.InputMethodService
import android.text.InputType
import android.view.View
import android.view.inputmethod.EditorInfo
import android.view.inputmethod.InputMethodManager
import android.widget.Toast

/**
 * QUÉ HACE: Servicio de método de entrada (IME) nativo completo de Nano AI.
 * POR QUÉ EXISTE: Vincula InputConnection con NanoKeyboardView, Nano Local, emojis y dictado por voz.
 */
class NanoInputMethodService : InputMethodService() {

    private var keyboardView: NanoKeyboardView? = null
    private var voiceInputHelper: NanoVoiceInputHelper? = null
    private var localAssistant: NanoLocalAssistant? = null

    override fun onCreate() {
        super.onCreate()
        voiceInputHelper = NanoVoiceInputHelper(
            context = this,
            onResult = { text -> type(text) },
            onStateChanged = { state -> handleVoiceStateChanged(state) },
        )
        localAssistant = NanoLocalAssistant(
            context = this,
            onTextGenerated = { generated -> type(generated) },
            onStatusUpdate = { msg -> Toast.makeText(this, msg, Toast.LENGTH_SHORT).show() },
        )
    }

    override fun onCreateInputView(): View {
        val view = NanoKeyboardView.create(this)
        keyboardView = view as? NanoKeyboardView
        return view
    }

    override fun onStartInputView(info: EditorInfo?, restarting: Boolean) {
        super.onStartInputView(info, restarting)
        keyboardView?.updateEnterActionLabel()
    }

    override fun onFinishInputView(finishingInput: Boolean) {
        voiceInputHelper?.stopListening()
        localAssistant?.cancel()
        NanoKeyPopup.dismiss()
        super.onFinishInputView(finishingInput)
    }

    override fun onDestroy() {
        voiceInputHelper?.stopListening()
        voiceInputHelper = null
        localAssistant?.cancel()
        localAssistant = null
        NanoKeyPopup.dismiss()
        super.onDestroy()
    }

    internal fun type(value: String) {
        currentInputConnection?.commitText(value, 1)
    }

    internal fun erase() {
        NanoInputConnectionHelper.safeDelete(currentInputConnection)
    }

    internal fun performEnterAction() {
        val connection = currentInputConnection ?: return
        val editor = currentInputEditorInfo
        val inputType = editor?.inputType ?: InputType.TYPE_CLASS_TEXT
        val isMultiline = (inputType and InputType.TYPE_TEXT_FLAG_MULTI_LINE) != 0

        val imeAction = editor?.imeOptions?.and(EditorInfo.IME_MASK_ACTION) ?: EditorInfo.IME_ACTION_NONE
        val noEnterAction = (editor?.imeOptions?.and(EditorInfo.IME_FLAG_NO_ENTER_ACTION)) != 0

        if (!noEnterAction && !isMultiline && imeAction != EditorInfo.IME_ACTION_NONE && imeAction != EditorInfo.IME_ACTION_UNSPECIFIED) {
            connection.performEditorAction(imeAction)
        } else {
            connection.commitText("\n", 1)
        }
    }

    internal fun getEnterActionLabel(): String {
        val editor = currentInputEditorInfo ?: return "↵"
        val inputType = editor.inputType
        val isMultiline = (inputType and InputType.TYPE_TEXT_FLAG_MULTI_LINE) != 0
        if (isMultiline) return "↵"

        return when (editor.imeOptions and EditorInfo.IME_MASK_ACTION) {
            EditorInfo.IME_ACTION_SEARCH -> "Buscar"
            EditorInfo.IME_ACTION_SEND -> "Enviar"
            EditorInfo.IME_ACTION_GO -> "Ir"
            EditorInfo.IME_ACTION_NEXT -> "Sig"
            EditorInfo.IME_ACTION_DONE -> "Listo"
            else -> "↵"
        }
    }

    internal fun startVoiceInput() {
        voiceInputHelper?.startListening()
    }

    private fun handleVoiceStateChanged(state: NanoVoiceInputHelper.VoiceState) {
        when (state) {
            NanoVoiceInputHelper.VoiceState.LISTENING -> Toast.makeText(this, "Escuchando...", Toast.LENGTH_SHORT).show()
            NanoVoiceInputHelper.VoiceState.PROCESSING -> Toast.makeText(this, "Procesando voz...", Toast.LENGTH_SHORT).show()
            NanoVoiceInputHelper.VoiceState.ERROR -> Toast.makeText(this, "Error de reconocimiento.", Toast.LENGTH_SHORT).show()
            else -> {}
        }
    }

    internal fun executeNanoAction(action: NanoLocalAssistant.Action) {
        val editor = currentInputEditorInfo
        if (editor != null && isSensitive(editor.inputType)) {
            Toast.makeText(this, "IA contextual deshabilitada en campos protegidos.", Toast.LENGTH_SHORT).show()
            return
        }

        val selected = currentInputConnection?.getSelectedText(0)?.toString()
        val textToProcess = if (!selected.isNullOrBlank()) {
            selected
        } else {
            currentInputConnection?.getTextBeforeCursor(200, 0)?.toString() ?: ""
        }
        localAssistant?.executeAction(action, textToProcess)
    }

    internal fun chooseKeyboard() {
        (getSystemService(Context.INPUT_METHOD_SERVICE) as InputMethodManager)
            .showInputMethodPicker()
    }

    internal fun pasteClipboard() {
        val editor = currentInputEditorInfo
        if (editor != null && isSensitive(editor.inputType)) {
            Toast.makeText(this, "Campo de contraseña protegido.", Toast.LENGTH_SHORT).show()
            return
        }
        val clipboard = getSystemService(Context.CLIPBOARD_SERVICE) as ClipboardManager
        val item = clipboard.primaryClip?.takeIf { it.itemCount > 0 }?.getItemAt(0)
        val text = item?.text
        val connection = currentInputConnection
        if (text.isNullOrEmpty() || connection == null || !connection.commitText(text, 1)) {
            Toast.makeText(this, "Portapapeles vacío.", Toast.LENGTH_SHORT).show()
        }
    }

    internal fun onOwlToolbarClicked() {
        val launchIntent = packageManager.getLaunchIntentForPackage(packageName)
        if (launchIntent != null) {
            launchIntent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            startActivity(launchIntent)
        } else {
            Toast.makeText(this, "Nano AI activo", Toast.LENGTH_SHORT).show()
        }
    }

    private fun isSensitive(type: Int): Boolean {
        val kind = type and InputType.TYPE_MASK_CLASS
        val variation = type and InputType.TYPE_MASK_VARIATION
        return (kind == InputType.TYPE_CLASS_TEXT && variation in setOf(
            InputType.TYPE_TEXT_VARIATION_PASSWORD,
            InputType.TYPE_TEXT_VARIATION_VISIBLE_PASSWORD,
            InputType.TYPE_TEXT_VARIATION_WEB_PASSWORD,
        )) || (kind == InputType.TYPE_CLASS_NUMBER &&
            variation == InputType.TYPE_NUMBER_VARIATION_PASSWORD) || type == InputType.TYPE_NULL
    }
}
