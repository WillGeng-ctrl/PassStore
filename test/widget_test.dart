import 'package:flutter_test/flutter_test.dart';
import 'package:passstore/main.dart';

void main() {
  testWidgets('shows PassStore create vault flow', (tester) async {
    await tester.pumpWidget(const PassStoreApp());

    expect(find.text('PassStore'), findsOneWidget);
    expect(find.text('创建密码库'), findsWidgets);
  });
}
