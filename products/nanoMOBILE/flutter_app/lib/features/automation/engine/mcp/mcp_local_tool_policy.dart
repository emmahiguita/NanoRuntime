import 'mcp_client_port.dart';
import 'mcp_tool.dart';

/// Solo los identificadores internos reservados obtienen clasificación local.
/// Las pistas de un servidor remoto nunca rebajan el efecto a lectura.
abstract final class McpLocalToolPolicy {
  static McpToolCategory category(McpRemoteTool tool) {
    final name = tool.name;
    if (tool.serverId == 'device') {
      if (const {
        'diagnostics',
        'app_summary',
        'system_features',
        'mobile_get_device_state',
        'mobile_observe',
        'mobile_find_element',
      }.contains(name)) {
        return McpToolCategory.read;
      }
      if (const {
        'mobile_back',
        'mobile_home',
        'mobile_open_app',
      }.contains(name)) {
        return McpToolCategory.device;
      }
    }
    if (tool.serverId == 'nano.mobile') {
      if (const {'observe', 'verify', 'get_ledger_history'}.contains(name)) {
        return McpToolCategory.read;
      }
      if (name == 'launch_app') return McpToolCategory.device;
    }
    if (tool.serverId == 'nano-linux' &&
        const {
          'nano.linux.fs.list',
          'nano.linux.fs.read',
          'nano.linux.fs.stat',
          'nano.linux.git.status',
          'nano.linux.git.diff',
          'nano.linux.git.log',
          'nano.linux.process.list',
          'nano.linux.process.inspect',
        }.contains(name)) {
      return McpToolCategory.read;
    }
    return McpToolCategory.externalWrite;
  }
}
