// ─────────────────────────────────────────────────────────────────────────────
// commonMain · dev.nanoai.core.agent · TargetMatchPolicy.kt
//
// QUÉ  : Política de coincidencia de nodos UI para acciones de automatización.
//         Puerto de TargetMatchPolicy.kt (Android) a commonMain.
// POR QUÉ: La política de tolerancia de coordenadas y la comparación de
//           identidad de elementos son idénticas en cualquier plataforma.
//           En iOS se alimenta desde XCUIElement / Accessibility Inspector
//           en lugar de AccessibilityNodeInfo.
// ─────────────────────────────────────────────────────────────────────────────
package dev.nanoai.core.agent

/** Identidad inmutable que une una acción al nodo observado por la UI. */
data class TargetIdentity(
    val packageName: String,
    val resourceId: String,
    val className: String,
    val text: String,
    val description: String,
    val bounds: IntArray,       // [left, top, right, bottom] en px
) {
    override fun equals(other: Any?): Boolean =
        other is TargetIdentity &&
            packageName == other.packageName &&
            resourceId  == other.resourceId  &&
            className   == other.className   &&
            text        == other.text        &&
            description == other.description &&
            bounds.contentEquals(other.bounds)

    override fun hashCode(): Int =
        listOf(packageName, resourceId, className, text, description).hashCode() * 31 +
            bounds.contentHashCode()
}

/** Política pura y testeable para la coincidencia de nodos UI. */
object TargetMatchPolicy {
    private const val BOUNDS_TOLERANCE_PX = 8

    fun matches(actual: TargetIdentity, expected: TargetIdentity): Boolean =
        actual.packageName == expected.packageName &&
            optionalExact(actual.resourceId,  expected.resourceId)  &&
            optionalExact(actual.className,   expected.className)    &&
            optionalExact(actual.text,        expected.text)         &&
            optionalExact(actual.description, expected.description)  &&
            boundsCompatible(actual.bounds,   expected.bounds)

    private fun optionalExact(actual: String, expected: String): Boolean =
        expected.isBlank() || actual == expected

    fun boundsCompatible(actual: IntArray, expected: IntArray): Boolean {
        if (actual.size != 4 || expected.size != 4) return false
        return actual.indices.all { i ->
            kotlin.math.abs(actual[i] - expected[i]) <= BOUNDS_TOLERANCE_PX
        }
    }
}
