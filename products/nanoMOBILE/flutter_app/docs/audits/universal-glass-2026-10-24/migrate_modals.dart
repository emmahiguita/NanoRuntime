import 'dart:io';
import 'dart:convert';
import 'package:analyzer/dart/analysis/utilities.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';
import 'package:path/path.dart' as p;
class Migrate extends RecursiveAstVisitor<void> {
 final List<({int start,int end,String text})> edits=[];
 @override
 void visitMethodInvocation(MethodInvocation n) {
  if(n.methodName.name=='showModalBottomSheet') {
   edits.add((start:n.methodName.offset,end:n.methodName.end,text:'showNanoGlassWindow'));
   final args=n.argumentList.arguments;
   for(final a in args.whereType<NamedExpression>()) {
    final name=a.name.label.name;
    if(['isScrollControlled','backgroundColor','useSafeArea','showDragHandle','shape'].contains(name)) {
     var end=a.end; final next=a.endToken.next;
     if(next?.lexeme==',')end=next!.end;
     edits.add((start:a.offset,end:end,text:''));
    } else if(name=='sheetAnimationStyle') {
     edits.add((start:a.name.label.offset,end:a.name.label.end,text:'animationStyle'));
    }
   }
  }
  super.visitMethodInvocation(n);
 }
}
void main(){
 final changed=<String>{};var calls=0;
 final files=Directory('lib').listSync(recursive:true).whereType<File>()
  .where((f)=>f.path.endsWith('.dart')).toList();
 final backup=Directory('docs/audits/universal-glass-2026-10-24/before');
 void save(File file) {
  final dest=File(p.join(backup.path,file.path));dest.parent.createSync(recursive:true);
  if(!dest.existsSync())dest.writeAsStringSync(file.readAsStringSync());
 }
 final owners=<String>{};
 for(final file in files) {
  final s=file.readAsStringSync();if(!s.contains('showModalBottomSheet'))continue;
  final unit=parseString(content:s).unit;final visitor=Migrate();unit.accept(visitor);
  if(visitor.edits.isEmpty)continue;
  calls+=visitor.edits.where((e)=>e.text=='showNanoGlassWindow').length;
  save(file);var output=s;
  for(final e in visitor.edits..sort((a,b)=>b.start.compareTo(a.start))) {
   output=output.replaceRange(e.start,e.end,e.text);
  }
  output=output.replaceAll('[showModalBottomSheet]','[showNanoGlassWindow]');
  file.writeAsStringSync(output);changed.add(file.path);
  final partOf=unit.directives.whereType<PartOfDirective>().firstOrNull;
  if(partOf?.uri!=null) {
   owners.add(p.normalize(p.join(file.parent.path,partOf!.uri!.stringValue!)));
  } else { owners.add(file.path); }
 }
 for(final path in owners){
  final file=File(path);save(file);var s=file.readAsStringSync();
  final import="import 'package:nanoai/core/widgets/nano_glass_window.dart';";
  if(!s.contains(import))s='$import\n$s';
  file.writeAsStringSync(s);changed.add(path);
 }
 File('docs/audits/universal-glass-2026-10-24/migrated-files.json')
   .writeAsStringSync(jsonEncode(changed.map((s)=>s.replaceAll('\\','/')).toList()));
 print('$calls calls migrated in ${changed.length} files');
}
