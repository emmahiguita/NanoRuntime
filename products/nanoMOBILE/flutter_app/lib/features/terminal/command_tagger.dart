/// Clasifica un comando en una categoría (tag) basado en su nombre.
///
/// Extraído de _TermState._tagFor (SRP). Sin estado, sin dependencias.
/// Usado por NoarPersistence para etiquetar comandos guardados.
class CommandTagger {
  const CommandTagger._();

  /// Retorna el tag para [cmd] basado en el nombre del binario.
  static String tag(String cmd) {
    final name = cmd.split(' ').first;
    if ([
      'ls',
      'cat',
      'cd',
      'pwd',
      'mkdir',
      'touch',
      'rm',
      'cp',
      'mv',
      'echo',
      'grep',
      'find',
      'wc',
      'head',
      'tail',
      'diff',
      'chmod',
      'tree',
    ].contains(name)) {
      return 'fs';
    }
    if (['apt', 'pkg', 'pip', 'npm', 'gem', 'cargo'].contains(name)) {
      return 'pkgs';
    }
    if (['docker'].contains(name)) return 'containers';
    if (['kali'].contains(name)) return 'kali';
    if (['ps', 'kill', 'htop', 'top', 'pstree', 'free', 'df'].contains(name)) {
      return 'monitor';
    }
    if (['git', 'ssh', 'curl', 'wget', 'scp'].contains(name)) return 'remote';
    if (['ai', 'infer', 'stat', 'tune', 'gpu', 'nvtop'].contains(name)) {
      return 'ai';
    }
    if (['bootstrap'].contains(name)) return 'rootfs';
    if (['bash', 'toybox'].contains(name)) return 'shell';
    if (cmd.startsWith('!')) return 'shell';
    return 'general';
  }
}
