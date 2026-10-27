import 'dart:io';
import 'dart:convert';
import 'package:analyzer/dart/analysis/utilities.dart';
import 'package:analyzer/dart/ast/ast.dart';
void main() {
  final source=File('lib/features/terminal/terminal_core.dart').readAsStringSync();
  final unit=parseString(content:source).unit;
  final result=<Object?>[];
  for(final cls in unit.declarations.whereType<ClassDeclaration>()) {
    final members=<Object?>[];
    for(final m in cls.members) {
      members.add({'kind':m.runtimeType.toString(),'name':m is MethodDeclaration?m.name.lexeme:'field','offset':m.offset,'end':m.end, 'raw':source.substring(m.documentationComment?.offset ?? m.offset,m.end),
      'lines':source.substring(m.offset,m.end).split('\n').length,
      if(m is MethodDeclaration) 'signature':source.substring(m.offset,m.body.offset), if(m is MethodDeclaration) 'getter':m.isGetter,
      if(m is MethodDeclaration && m.name.lexeme=='_buildRegistry') 'statements':(m.body as BlockFunctionBody).block.statements.map((s)=>{'offset':s.offset,'end':s.end,'lines':source.substring(s.offset,s.end).split('\n').length,'raw':source.substring(s.offset,s.end),'preview':s.toSource().substring(0,s.toSource().length.clamp(0,100))}).toList()});
    }
    result.add({'class':cls.name.lexeme,'source':source.substring(cls.offset,cls.end),'members':members});
  }
  File('docs/audits/mcp-terminal-implementation-2026-10-24/terminal-ast.json').writeAsStringSync(jsonEncode(result));
  for(final cls in result.cast<Map>()) {print(cls['class']);for(final m in cls['members'] as List){print('${m['name']}: ${m['lines']}');if(m['statements']!=null){for(final s in m['statements']){print('  ${s['lines']}: ${s['preview']}');}}}}
}
