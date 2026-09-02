import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:lv_dli/main.dart';

class _FakeClient extends http.BaseClient {
  _FakeClient(this.response);

  final http.Response response;
  http.BaseRequest? request;

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    this.request = request;
    return http.StreamedResponse(
      Stream.value(utf8.encode(response.body)),
      response.statusCode,
      headers: response.headers,
    );
  }
}

void main() {
  testWidgets('submits valid lineage with mandatory metadata', (tester) async {
    final client = _FakeClient(http.Response('{"status":"verified"}', 200));
    await tester.pumpWidget(
      MaterialApp(home: LsaVerificationScreen(client: client)),
    );

    await tester.tap(find.text('Verify & Submit'));
    await tester.pumpAndSettle();

    expect(find.text('Success'), findsOneWidget);
    expect(
      client.request!.headers['x-trace-id'],
      '8f3d1b2a-4c9e-4a11-b8d2-9901ef23a011',
    );
    expect(
      client.request!.headers['x-logic-hash'],
      'e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855',
    );
  });

  testWidgets('quarantines missing predecessor without a network call', (
    tester,
  ) async {
    final client = _FakeClient(http.Response('{"status":"verified"}', 200));
    await tester.pumpWidget(
      MaterialApp(home: LsaVerificationScreen(client: client)),
    );
    await tester.enterText(find.byKey(const Key('predecessor_id')), '');
    await tester.tap(find.text('Verify & Submit'));
    await tester.pump();

    expect(find.text('Data Quarantined – Compliance Failure'), findsOneWidget);
    expect(client.request, isNull);
  });

  testWidgets('quarantines null API status and locks submission', (
    tester,
  ) async {
    final client = _FakeClient(http.Response('{"status":null}', 200));
    await tester.pumpWidget(
      MaterialApp(home: LsaVerificationScreen(client: client)),
    );
    await tester.tap(find.text('Verify & Submit'));
    await tester.pumpAndSettle();

    expect(find.text('Data Quarantined – Compliance Failure'), findsOneWidget);
    expect(
      tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
      isNull,
    );
    expect(find.byKey(const Key('predecessor_id')), findsOneWidget);
  });
}
