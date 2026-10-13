import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'health_step_repository.dart';
import 'mock_step_repository.dart';
import 'step_repository.dart';

/// Development builds use mock steps. Release builds never do.
const bool useMockSteps = bool.fromEnvironment(
  'USE_MOCK_STEPS',
  defaultValue: !bool.fromEnvironment('dart.vm.product'),
);

final stepRepositoryProvider = Provider<StepRepository>((ref) {
  if (useMockSteps) {
    return MockStepRepository();
  }
  return HealthStepRepository();
});
