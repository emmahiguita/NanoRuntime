import 'dart:io';
import 'dart:convert';
import 'package:analyzer/dart/analysis/utilities.dart';
import 'package:analyzer/dart/ast/ast.dart';
void main(){
 for(final path in jsonDecode(File('docs/audits/universal-glass-2026-10-24/migrated-files.json').readAsStringSync()) as List){
  final file=File(path as String);var s=file.readAsStringSync();
  const added="import 'package:nanoai/core/widgets/nano_glass_window.dart';";
  if(!s.contains(added))continue;
  s=s.replaceAll('$added\n','');
  final unit=parseString(content:s,throwIfDiagnostics:false).unit;
  final imports=unit.directives.whereType<ImportDirective>();
  final offset=imports.isNotEmpty?imports.last.end:0;
  s=s.replaceRange(offset,offset,'\n$added');file.writeAsStringSync(s);
 }
}
