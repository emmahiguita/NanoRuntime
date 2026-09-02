package dev.nanoai.mobile.channels

/**
 * Nombres de canales constantes para evitar duplicación de strings.
 */
object ChannelNames {
    const val DEVICE_METRICS = DeviceMetricsChannelHandler.CHANNEL_NAME
    const val EXEC_BIN = ExecBinChannelHandler.CHANNEL_NAME
    const val PTY = PtyChannelHandler.CHANNEL_NAME
    const val NAVIGATION = NavigationChannelHandler.CHANNEL_NAME
    const val RUNTIME = RuntimeChannelHandler.CHANNEL_NAME
    const val AGENT = AgentChannelHandler.CHANNEL_NAME
    const val ENGINE = EngineChannelHandler.CHANNEL_NAME
    const val MODEL_STORAGE = ModelStorageChannelHandler.CHANNEL_NAME
    const val SHARE = ShareChannelHandler.CHANNEL_NAME
    const val NOTIFICATIONS = NotificationAutomationChannelHandler.CHANNEL_NAME
    const val DEVICE_PERMISSIONS = DevicePermissionsChannelHandler.CHANNEL_NAME
    const val SPEECH = SpeechChannelHandler.CHANNEL_NAME
    const val SYSTEM = SystemInventoryChannelHandler.CHANNEL_NAME
}
