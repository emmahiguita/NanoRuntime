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
}
