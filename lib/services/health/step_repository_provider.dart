import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../storage/local_store_provider.dart';
import 'composite_step_repository.dart';
import 'health_step_repository.dart';
import 'mock_step_repository.dart';
import 'sensor_step_repository.dart';
import 'step_repository.dart';

/// Development builds use mock steps. Release builds never do.
///
/// The product flag wins over the dart-define, so a release build reads the
/// phone whatever the define says.
const bool useMockSteps =
    bool.fromEnvironment('dart.vm.product')
    ? false
    : bool.fromEnvironment('USE_MOCK_STEPS', defaultValue: true);

/// The phone's steps: health store first, step sensor second, nothing third.
StepRepository createStepRepository(Ref ref) {
  if (useMockSteps) return MockStepRepository();
  return CompositeStepRepository(
    health: HealthStepRepository(),
    sensor: SensorStepRepository(store: ref.watch(localStoreProvider)),
  );
}

final stepRepositoryProvider = Provider<StepRepository>(createStepRepository);
