import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:suikouji/features/transaction/domain/entities/transaction_entity.dart';
import 'package:suikouji/features/transaction/presentation/widgets/transfer_fields.dart';

void main() {
  Widget buildApp(TransferFields widget) {
    return MaterialApp(
      home: Scaffold(body: SingleChildScrollView(child: widget)),
    );
  }

  testWidgets('renders direction and counterparty field', (tester) async {
    await tester.pumpWidget(
      buildApp(
        TransferFields(
          direction: TransferDirection.outbound,
          onDirectionChanged: (_) {},
          onCounterpartyChanged: (_) {},
        ),
      ),
    );

    expect(find.text('转出'), findsOneWidget);
    expect(find.text('转入'), findsOneWidget);
    expect(find.text('对方 (可选)'), findsOneWidget);
  });

  testWidgets('controller disposes without error', (tester) async {
    await tester.pumpWidget(
      buildApp(
        TransferFields(
          direction: TransferDirection.outbound,
          counterparty: 'test',
          onDirectionChanged: (_) {},
          onCounterpartyChanged: (_) {},
        ),
      ),
    );

    // Removing the widget should dispose the controller cleanly
    await tester.pumpWidget(
      const MaterialApp(home: Scaffold(body: SizedBox())),
    );
    await tester.pump();
    // No exception thrown = success
  });

  testWidgets('external counterparty update syncs to controller', (
    tester,
  ) async {
    String? currentCounterparty = 'Alice';
    late StateSetter setOuterState;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: StatefulBuilder(
            builder: (context, setState) {
              setOuterState = setState;
              return SingleChildScrollView(
                child: TransferFields(
                  direction: TransferDirection.outbound,
                  counterparty: currentCounterparty,
                  onDirectionChanged: (_) {},
                  onCounterpartyChanged: (_) {},
                ),
              );
            },
          ),
        ),
      ),
    );

    final textField = tester.widget<TextField>(find.byType(TextField));
    expect(textField.controller!.text, 'Alice');

    setOuterState(() => currentCounterparty = 'Bob');
    await tester.pump();

    final updatedTextField = tester.widget<TextField>(find.byType(TextField));
    expect(updatedTextField.controller!.text, 'Bob');
  });
}
