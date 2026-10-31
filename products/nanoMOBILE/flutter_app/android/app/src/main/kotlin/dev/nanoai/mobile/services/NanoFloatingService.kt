package dev.nanoai.mobile.services

/** Entrada Android estable. El único panel es Flutter y comparte su sesión. */
class NanoFloatingService : NanoOwlWindowService() {
    companion object {
        val isActive: Boolean get() = NanoOwlWindowService.isActive
    }
}
