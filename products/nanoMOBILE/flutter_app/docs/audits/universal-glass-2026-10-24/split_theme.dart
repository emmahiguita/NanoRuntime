import 'dart:io';
import 'dart:convert';
import 'package:analyzer/dart/analysis/utilities.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';
class FindTheme extends RecursiveAstVisitor<void> {
 MethodInvocation? node;
 @override
 void visitMethodInvocation(MethodInvocation n){
  if(n.methodName.name=='ThemeData')node=n;
  super.visitMethodInvocation(n);
 }
}
void main(){
 final f=File('lib/core/theme/app_theme.dart');final s=f.readAsStringSync();
 final cls=parseString(content:s).unit.declarations.whereType<ClassDeclaration>().single;
 final method=cls.members.whereType<MethodDeclaration>().firstWhere((m)=>m.name.lexeme=='_base');
 final finder=FindTheme();method.accept(finder);final node=finder.node!;
 final args={for(final a in node.argumentList.arguments.whereType<NamedExpression>())
   a.name.label.name:s.substring(a.offset,a.end)};
 const controls=['elevatedButtonTheme','filledButtonTheme','outlinedButtonTheme',
   'textButtonTheme','floatingActionButtonTheme','inputDecorationTheme','switchTheme','sliderTheme'];
 const surfaces=['cardTheme','appBarTheme','navigationBarTheme','dividerTheme',
   'listTileTheme','chipTheme','snackBarTheme','dialogTheme','bottomSheetTheme'];
 final dir=f.parent;final parts=<String>[];
 void writePart(String name,String comment,String body){
  parts.add(name);File('${dir.path}/$name').writeAsStringSync(
   "part of 'app_theme.dart';\n\n/// $comment\n$body\n");
 }
 final text=cls.members.whereType<FieldDeclaration>().firstWhere((d)=>d.fields.variables.any((v)=>v.name.lexeme=='_textTheme'));
 final textSource=s.substring(text.offset,text.end).replaceFirst('static const _textTheme','const _nanoTextTheme');
 writePart('app_theme_typography.part.dart','Tipografía local compartida, sin descargas ni colores por módulo.',textSource);
 for(final entry in {'controls':controls,'surfaces':surfaces}.entries){
  final body=entry.value.map((n)=>args.remove(n)!).join(',\n');
  final function=entry.key=='controls'?'_nanoThemeControls':'_nanoThemeSurfaces';
  writePart('app_theme_${entry.key}.part.dart',
    entry.key=='controls'?'Controles Material que leen la misma paleta y brillo global.':
      'Superficies y ventanas: colores semánticos sin un segundo tema.',
    'ThemeData $function(ThemeData base, NanoColors c, bool isDark) => base.copyWith(\n$body,\n);');
 }
 final core=args.values.join(',\n').replaceAll('_textTheme','_nanoTextTheme');
 final newMethod=s.substring(method.offset,method.body.offset)+"{\n"+
   '  final isDark = NanoPaletteBrightness.isDark(c);\n'+
   '  final base = ThemeData(\n$core,\n);\n'+
   '  return _nanoThemeControls(_nanoThemeSurfaces(base,c,isDark),c,isDark);\n}';
 final members=cls.members.where((m)=>m!=method && m!=text).map((m)=>s.substring(m.documentationComment?.offset??m.offset,m.end)).join('\n\n');
 f.writeAsStringSync("import 'package:flutter/material.dart';\nimport 'design_tokens.dart';\nimport 'nano_transitions.dart';\n"+
  parts.map((name)=>"part '$name';").join('\n')+
  '\n\n/// Tema global: la paleta define el brillo, el texto y los controles.\nclass AppTheme {\n'+newMethod+'\n'+members+'\n}\n');
 print('Shared theme split into foundation, typography, controls and surfaces');
}
