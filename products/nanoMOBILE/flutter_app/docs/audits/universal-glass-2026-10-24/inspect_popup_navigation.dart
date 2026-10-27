import 'dart:io';
import 'package:analyzer/dart/analysis/utilities.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';
class Pops extends RecursiveAstVisitor<void> {
 final String file, parameter;
 Pops(this.file,this.parameter);
 @override
 void visitMethodInvocation(MethodInvocation n) {
  if(n.methodName.name=='pop') {
   final target=n.target;
   Expression? ctx;
   if(target is MethodInvocation && target.methodName.name=='of' && target.target.toString()=='Navigator') {
    ctx=target.argumentList.arguments.first;
   } else if(target.toString()=='Navigator' && n.argumentList.arguments.isNotEmpty) {
    ctx=n.argumentList.arguments.first;
   }
   if(ctx!=null && ctx.toSource()!=parameter)print('$file: builder=$parameter; popContext=$ctx; $n');
  }
  super.visitMethodInvocation(n);
 }
}
class Windows extends RecursiveAstVisitor<void> {
 final String file;
 Windows(this.file);
 @override
 void visitMethodInvocation(MethodInvocation n){
  if(n.methodName.name=='showNanoGlassWindow') {
   final builder=n.argumentList.arguments.whereType<NamedExpression>().firstWhere((a)=>a.name.label.name=='builder').expression;
   if(builder is FunctionExpression){
    builder.accept(Pops(file,builder.parameters!.parameters.first.toSource()));
   }
  }
  super.visitMethodInvocation(n);
 }
}
void main(){
 for(final f in Directory('lib').listSync(recursive:true).whereType<File>().where((f)=>f.path.endsWith('.dart'))){
  final s=f.readAsStringSync();if(!s.contains('showNanoGlassWindow'))continue;
  parseString(content:s).unit.accept(Windows(f.path));
 }
}
