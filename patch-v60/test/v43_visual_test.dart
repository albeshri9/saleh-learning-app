import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:saleh_app/core/design/widgets/letter_glyph.dart';
import 'package:saleh_app/features/lesson/writing/letter_trace_template.dart';
import 'v38_test.dart' as support;

class TracePreview extends CustomPainter {
  TracePreview(this.template);
  final LetterTraceTemplate template;
  @override
  void paint(Canvas canvas,Size size){
    final rect=template.drawingRect(size);
    for(final part in template.guideParts){
      canvas.drawPath(part.outlinePath(rect),Paint()..color=const Color(0xFFDFD3E8));
      canvas.drawPath(part.centerlinePath(rect),Paint()..color=Colors.deepPurple..style=PaintingStyle.stroke..strokeWidth=2);
      final start=part.samples(rect).first;
      canvas.drawCircle(start,3,Paint()..color=Colors.green);
    }
  }
  @override
  bool shouldRepaint(TracePreview old)=>false;
}
void main(){
  testWidgets('v43 writing and picture review',(tester) async {
    support.viewport(tester,const Size(844,390));
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await (FontLoader('Tajawal')..addFont(rootBundle.load('assets/fonts/Tajawal-Bold.ttf'))).load();
    await tester.pumpWidget(MaterialApp(home:Scaffold(body:RepaintBoundary(key:const ValueKey('preview'),child:Row(textDirection:TextDirection.rtl,children:[
      for(final t in [thaaFathaTemplate,jeemFathaTemplate,haaFathaTemplate]) Expanded(child:Column(children:[
        SizedBox(height:180,child:CustomPaint(painter:TracePreview(t),child:const SizedBox.expand())),
        SizedBox(height:60,width:60,child:LetterGlyph(t==thaaFathaTemplate?'ثَ':t==jeemFathaTemplate?'جَ':'حَ')),
        SizedBox(height:140,child:Image.asset('assets/images/assessment/${t==thaaFathaTemplate?'fox.png':t==jeemFathaTemplate?'camel_v43.png':'rope_v43.png'}')),
      ])),
    ])))));
    await tester.pumpAndSettle();
    await tester.runAsync(()=>Future<void>.delayed(const Duration(seconds:1)));
    await tester.pump();
    await expectLater(find.byKey(const ValueKey('preview')),matchesGoldenFile('goldens/v43-writing-preview.png'));
  },tags:['visual']);
}
