import 'dart:io';
import 'dart:convert';
import 'package:analyzer/dart/analysis/utilities.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';
class Calls extends RecursiveAstVisitor<void> {
  final List<Map<String,Object?>> items=[];
  @override
  void visitMethodInvocation(MethodInvocation n) {
    if (n.methodName.name=='showModalBottomSheet' || n.methodName.name=='showBottomSheet') {
      items.add({'name':n.methodName.name,'offset':n.offset,'end':n.end,
        'args':n.argumentList.arguments.whereType<NamedExpression>().map((a)=>{
          'name':a.name.label.name,'value':a.expression.toSource(),
          'offset':a.offset,'end':a.end}).toList()});
    }
    super.visitMethodInvocation(n);
  }
}
void main(){
 final result=[];
 for(final file in Directory('lib').listSync(recursive:true).whereType<File>()
     .where((f)=>f.path.endsWith('.dart'))) {
  final s=file.readAsStringSync();
  if(!s.contains('showModalBottomSheet')&&!s.contains('showBottomSheet'))continue;
  final unit=parseString(content:s,throwIfDiagnostics:false).unit;
  final c=Calls();unit.accept(c);if(c.items.isEmpty)continue;
  result.add({'path':file.path.replaceAll('\\','/'),'lines':s.split('\n').length,
   'directives':unit.directives.map((d)=>d.toSource()).toList(),'calls':c.items,
   'decls':unit.declarations.map((d)=>{'kind':d.runtimeType.toString(),
    'offset':d.offset,'end':d.end,'name':d is ClassDeclaration?d.name.lexeme:'other',
    'lines':s.substring(d.offset,d.end).split('\n').length,
    if(d is ClassDeclaration) 'members':d.members.map((m)=>{
      'name':m is MethodDeclaration?m.name.lexeme:'field',
      'offset':m.offset,'end':m.end,'lines':s.substring(m.offset,m.end).split('\n').length,
      'static':m is MethodDeclaration && m.isStatic,
      'signature':m is MethodDeclaration?s.substring(m.offset,m.body.offset):'',
    }).toList()}).toList()});
 }
 File('docs/audits/universal-glass-2026-10-24/modals-ast.json').writeAsStringSync(jsonEncode(result));
 print('Inspected ${result.length} modal files');
}
