package dev.nanoai.mobile.services

import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

/** Regresiones basadas en entry observado mediante ARTEMIS y diagnóstico de Nano. */
class NanoWhatsAppComposerEvidenceTest {
    /** Caso real OPPO: enfocado, longitud 7 de ayuda, sin hint y selección desconocida. */
    @Test fun acceptsObservedUnknownSelectionWithEmptyControls() {
        assertTrue(NanoWhatsAppComposerEvidence.isEmpty(-1, -1, 0, 1))
    }

    /** Un borrador con Enviar visible sigue protegido incluso sin selección publicada. */
    @Test fun protectsDraftWhenSendExists() {
        assertFalse(NanoWhatsAppComposerEvidence.isEmpty(-1, -1, 1, 0))
        assertFalse(NanoWhatsAppComposerEvidence.isEmpty(0, 0, 1, 1))
    }

    /** Un cursor sobre contenido, controles ausentes o duplicados no acreditan vacío. */
    @Test fun rejectsContradictoryOrIncompleteEvidence() {
        assertFalse(NanoWhatsAppComposerEvidence.isEmpty(7, 7, 0, 1))
        assertFalse(NanoWhatsAppComposerEvidence.isEmpty(-1, -1, 0, 0))
        assertFalse(NanoWhatsAppComposerEvidence.isEmpty(-1, -1, 0, 2))
        assertFalse(NanoWhatsAppComposerEvidence.isEmpty(-2, -2, 0, 1))
    }
}
