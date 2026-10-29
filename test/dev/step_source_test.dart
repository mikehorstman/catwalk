import 'package:catwalk/features/settings/presentation/step_source_card.dart';
import 'package:catwalk/services/health/health_client.dart';
import 'package:catwalk/services/health/sensor_step_client.dart';
import 'package:catwalk/services/health/sensor_step_repository.dart';
import 'package:catwalk/services/health/step_breakdown.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/memory_store.dart';

class _Health implements HealthClient {
  _Health({this.total, this.sources, this.permission = true});
  final int? total;
  final Map<String, int>? sources;
  final bool permission;

  @override
  Future<bool> isAvailable() async => true;
  @override
  Future<bool> hasPermission() async => permission;
  @override
  Future<bool> requestPermission() async => permission;
  @override
  Future<int?> stepsBetween(DateTime start, DateTime end) async => total;
  @override
  Future<List<int>?> hourlyBetween(DateTime start, DateTime end) async => null;
  @override
  Future<Map<String, int>?> stepsBySource(DateTime s, DateTime e) async =>
      sources;
}

class _Sensor implements SensorStepClient {
  @override
  Future<bool> isAvailable() async => false;
  @override
  Future<int?> stepsSinceBoot() async => null;
}

SensorStepRepository _sensor() =>
    SensorStepRepository(store: MemoryStore(), client: _Sensor());

void main() {
  test('shows the total and each app that wrote steps', () async {
    final b = await buildStepBreakdown(
      health: _Health(
        total: 9000,
        sources: {'Galaxy Watch': 9000, 'Phone': 6500},
      ),
      sensor: _sensor(),
    );
    expect(b.healthTotal, 9000);
    expect(b.bySource, {'Galaxy Watch': 9000, 'Phone': 6500});
    expect(b.counting, 'Health Connect / Apple Health');
  });

  test('says so when the store is not readable', () async {
    final b = await buildStepBreakdown(
      health: _Health(permission: false),
      sensor: _sensor(),
    );
    expect(b.healthReadable, isFalse);
    expect(b.counting, 'No source answers yet');
  });

  testWidgets('the card lists both apps and the priority hint', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          stepBreakdownProvider.overrideWith(
            (ref) async => const StepBreakdown(
              healthTotal: 9000,
              bySource: {'Galaxy Watch': 9000, 'Phone': 6500},
              healthReadable: true,
            ),
          ),
        ],
        child: const MaterialApp(home: Scaffold(body: StepSourceCard())),
      ),
    );
    await tester.pump();
    await tester.pump();
    expect(find.text('Galaxy Watch: 9,000'), findsOneWidget);
    expect(find.text('Phone: 6,500'), findsOneWidget);
    expect(find.byKey(const Key('step-priority-hint')), findsOneWidget);
    expect(find.text('Total used: 9,000 steps'), findsOneWidget);
  });
}
