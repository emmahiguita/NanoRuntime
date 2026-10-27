import 'dart:io';
import 'dart:convert';
import 'package:analyzer/dart/analysis/utilities.dart';
import 'package:analyzer/dart/ast/ast.dart';
void main(){
 for(final path in jsonDecode(File('docs/audits/universal-glass-2026-10-24/changed-source-files.json').readAsStringSync()) as List){
  final file=File(path as String);final s=file.readAsStringSync();if(s.split('\n').length<200)continue;
  final unit=parseString(content:s).unit;
  print('\n$path');for(final d in unit.declarations){
   print('${d.runtimeType} ${s.substring(d.offset,d.end).split('\n').length}');
   if(d is ExtensionDeclaration){for(final m in d.members){
    print('  ${m is MethodDeclaration?m.name.lexeme:'field'} ${s.substring(m.offset,m.end).split('\n').length}');
   }}
   if(d is ClassDeclaration){print('  ${d.name.lexeme}');for(final m in d.members){
    if(m is MethodDeclaration)print('  ${m.name.lexeme} ${s.substring(m.offset,m.end).split('\n').length}');
   }}
  }
 }
}
