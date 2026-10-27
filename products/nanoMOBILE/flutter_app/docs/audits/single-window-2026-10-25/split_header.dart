import 'dart:io';
import 'package:analyzer/dart/analysis/utilities.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';
class CloseButton extends RecursiveAstVisitor<void> {
 MethodInvocation? node;
 @override
 void visitMethodInvocation(MethodInvocation n) {
  if(n.methodName.name=='InkWell' && n.toSource().contains('CupertinoIcons.xmark'))node=n;
  super.visitMethodInvocation(n);
 }
}
void main(){
 final file=File('lib/features/automation/presentation/widgets/conversation_detail_header_view.dart');
 var s=file.readAsStringSync();var unit=parseString(content:s).unit;
 final find=CloseButton();unit.accept(find);
 final n=find.node!;final expression=s.substring(n.offset,n.end);
 s=s.replaceRange(n.offset,n.end,"Semantics(label: 'Cerrar conversación', button: true, child: $expression)");
 unit=parseString(content:s).unit;
 final extension=unit.declarations.whereType<ExtensionDeclaration>().single;
 final methods=extension.members.whereType<MethodDeclaration>().toList();
 String source(MethodDeclaration m)=>s.substring(m.documentationComment?.offset??m.offset,m.end);
 file.writeAsStringSync("part of 'conversation_detail_sheet.dart';\n\n"+
   '/// Cabecera: identidad del chat, transferencia y único cierre de la ventana.\n'+
   'extension ConversationDetailHeaderView on _ConversationDetailSheetState {\n'+
   source(methods.firstWhere((m)=>m.name.lexeme=='_buildHeader'))+'\n}\n');
 File('lib/features/automation/presentation/widgets/conversation_detail_control_bar.part.dart')
  .writeAsStringSync("part of 'conversation_detail_sheet.dart';\n\n"+
   '/// Alternancia Bot/Humano: conserva la lógica de propiedad del chat.\n'+
   'extension ConversationDetailControlBar on _ConversationDetailSheetState {\n'+
   methods.where((m)=>m.name.lexeme!='_buildHeader').map(source).join('\n\n')+'\n}\n');
 final owner=File('lib/features/automation/presentation/widgets/conversation_detail_sheet.dart');
 final text=owner.readAsStringSync();
 owner.writeAsStringSync(text.replaceFirst("part 'conversation_detail_header_view.dart';",
   "part 'conversation_detail_header_view.dart';\npart 'conversation_detail_control_bar.part.dart';"));
 print('Header and ownership controls separated; single close has a semantic label');
}
