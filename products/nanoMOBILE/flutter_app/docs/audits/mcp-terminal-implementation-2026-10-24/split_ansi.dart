import 'dart:io';
import 'package:analyzer/dart/analysis/utilities.dart';
import 'package:analyzer/dart/ast/ast.dart';
void main(){
 final file=File('lib/features/terminal/ansi_terminal.dart');
 final source=file.readAsStringSync();final unit=parseString(content:source).unit;
 final classes=unit.declarations.whereType<ClassDeclaration>().toList();
 final names={'AnsiMetrics':'ansi_cell_metrics.part.dart','AnsiTerminal':'ansi_terminal_buffer.part.dart',
 'AnsiTerminalView':'ansi_terminal_view.part.dart','_AnsiTerminalViewState':'ansi_terminal_view_state.part.dart','_TermLine':'ansi_terminal_line.part.dart'};
 final backup=File('docs/audits/mcp-terminal-implementation-2026-10-24/before/lib/features/terminal/ansi_terminal.dart.txt');
 backup.parent.createSync(recursive:true);if(!backup.existsSync())backup.writeAsStringSync(source);
 for(final cls in classes){
  final name=names[cls.name.lexeme];if(name==null)throw StateError(cls.name.lexeme);
  File('lib/features/terminal/$name').writeAsStringSync("part of 'ansi_terminal.dart';\n\n/// Componente ANSI: conserva el protocolo y separa su representación.\n"+source.substring(cls.documentationComment?.offset??cls.offset,cls.end)+'\n');
 }
 final imports=unit.directives.last.end;
 final first=classes.first.documentationComment?.offset??classes.first.offset;
 file.writeAsStringSync(source.substring(0,imports)+'\n'+names.values.map((n)=>"part '$n';\n").join()+source.substring(imports,first));
}
