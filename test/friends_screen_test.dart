import 'package:catwalk/features/map/data/location_service.dart';
import 'package:catwalk/features/reminders/data/notification_service.dart';
import 'package:catwalk/features/social/data/account_service.dart';
import 'package:catwalk/features/social/data/social_repository.dart';
import 'package:catwalk/features/social/presentation/friends_screen.dart';
import 'package:catwalk/services/health/mock_step_repository.dart';
import 'package:catwalk/services/health/step_repository_provider.dart';
import 'package:catwalk/services/storage/local_store_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'map_controller_test.dart' show seededStore;
import 'social_test.dart' show mara, noor, profile;

Future<void> frames(WidgetTester tester, [int n = 12]) async {
  for (var i = 0; i < n; i++) {
    await tester.pump(const Duration(milliseconds: 30));
  }
}

Future<void> show(
  WidgetTester tester, {
  required AccountService account,
  required FakeSocialRepository repo,
}) async {
  final store = await seededStore();
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        localStoreProvider.overrideWithValue(store),
        stepRepositoryProvider.overrideWithValue(
          MockStepRepository(stepsByDate: {}),
        ),
        locationServiceProvider.overrideWithValue(FakeLocationService()),
        notificationServiceProvider.overrideWithValue(
          FakeNotificationService(),
        ),
        accountServiceProvider.overrideWithValue(account),
        socialRepositoryProvider.overrideWithValue(repo),
      ],
      child: const MaterialApp(home: FriendsScreen()),
    ),
  );
  await frames(tester);
}

/// Noor is already Mara's friend, with 9,000 steps this week.
Future<FakeSocialRepository> withFriend() async {
  final repo = FakeSocialRepository();
  final maraCode = await repo.claimFriendCode(mara);
  final noorCode = await repo.claimFriendCode(noor);
  await repo.publish(profile(mara, code: maraCode));
  await repo.publish(profile(noor, week: 9000, streak: 4, code: noorCode));
  await repo.sendRequest(me: noor, code: maraCode);
  await repo.accept(me: mara, request: (await repo.incoming(mara.uid)).single);
  return repo;
}

void main() {
  testWidgets('signed out, it offers Google sign-in and nothing else', (
    tester,
  ) async {
    await show(
      tester,
      account: FakeAccountService(willSignIn: mara),
      repo: FakeSocialRepository(),
    );
    expect(find.byKey(const Key('sign-in')), findsOneWidget);
    expect(find.textContaining('never needs an account'), findsOneWidget);
    expect(find.byKey(const Key('my-code')), findsNothing);

    await tester.tap(find.byKey(const Key('sign-in')));
    await frames(tester, 25);

    expect(find.byKey(const Key('sign-in')), findsNothing);
    final code = tester.widget<Text>(find.byKey(const Key('my-code'))).data!;
    expect(code, hasLength(6));
  });

  testWidgets('a failed sign-in says so and stays signed out', (tester) async {
    await show(
      tester,
      account: FakeAccountService(),
      repo: FakeSocialRepository(),
    );
    await tester.tap(find.byKey(const Key('sign-in')));
    await frames(tester, 10);
    expect(find.textContaining('did not work'), findsOneWidget);
    expect(find.byKey(const Key('sign-in')), findsOneWidget);
  });

  testWidgets('the leaderboard puts the leader first and marks you', (
    tester,
  ) async {
    await show(
      tester,
      account: FakeAccountService(user: mara),
      repo: await withFriend(),
    );
    expect(find.textContaining('9,000 steps · 4 day streak'), findsOneWidget);
    expect(find.text('Mara (you)'), findsOneWidget);
    final noorY = tester.getTopLeft(find.byKey(Key('row-${noor.uid}'))).dy;
    final maraY = tester.getTopLeft(find.byKey(Key('row-${mara.uid}'))).dy;
    expect(noorY, lessThan(maraY));
  });

  testWidgets('a friend\'s room opens and a wave can be sent once', (
    tester,
  ) async {
    final repo = await withFriend();
    await show(
      tester,
      account: FakeAccountService(user: mara),
      repo: repo,
    );

    await tester.tap(find.byKey(Key('row-${noor.uid}')));
    await frames(tester, 20);
    expect(find.text('Noor\'s room'), findsOneWidget);
    expect(find.textContaining('4 day streak'), findsOneWidget);

    await tester.tap(find.byKey(const Key('wave')));
    await frames(tester, 10);
    expect(await repo.nudges(noor.uid), hasLength(1));
    expect(find.text('Waved today'), findsOneWidget);
    expect(
      tester.widget<FilledButton>(find.byKey(const Key('wave'))).onPressed,
      isNull,
    );
  });

  testWidgets('a friend who reached the goal gets no wave button', (
    tester,
  ) async {
    final repo = await withFriend();
    await repo.publish(profile(noor, week: 9000, met: true));
    await show(
      tester,
      account: FakeAccountService(user: mara),
      repo: repo,
    );
    await tester.tap(find.byKey(Key('row-${noor.uid}')));
    await frames(tester, 20);
    expect(find.byKey(const Key('wave')), findsNothing);
    expect(find.text('Today\'s goal is reached.'), findsOneWidget);
  });

  testWidgets('a request can be accepted', (tester) async {
    final repo = FakeSocialRepository();
    final maraCode = await repo.claimFriendCode(mara);
    await repo.claimFriendCode(noor);
    await repo.publish(profile(mara, code: maraCode));
    await repo.publish(profile(noor, week: 100));
    await repo.sendRequest(me: noor, code: maraCode);
    await show(
      tester,
      account: FakeAccountService(user: mara),
      repo: repo,
    );

    expect(find.text('Noor wants to be friends'), findsOneWidget);
    await tester.tap(find.byKey(Key('accept-${noor.uid}')));
    await frames(tester, 20);
    expect(find.text('Noor wants to be friends'), findsNothing);
    expect(find.byKey(Key('row-${noor.uid}')), findsOneWidget);
  });

  testWidgets('typing a friend\'s code sends a request, a wrong one says so', (
    tester,
  ) async {
    final repo = FakeSocialRepository();
    final noorCode = await repo.claimFriendCode(noor);
    await show(
      tester,
      account: FakeAccountService(user: mara),
      repo: repo,
    );

    await tester.enterText(find.byKey(const Key('friend-code')), 'zzzzzz');
    await tester.tap(find.byKey(const Key('send-request')));
    await frames(tester, 10);
    expect(find.textContaining('Nobody has that code'), findsOneWidget);

    await tester.enterText(find.byKey(const Key('friend-code')), noorCode);
    await tester.tap(find.byKey(const Key('send-request')));
    await frames(tester, 10);
    expect(find.textContaining('Request sent'), findsOneWidget);
    expect(await repo.incoming(noor.uid), hasLength(1));
  });

  testWidgets('deleting online data asks first, then signs out', (
    tester,
  ) async {
    final repo = await withFriend();
    final account = FakeAccountService(user: mara);
    await show(tester, account: account, repo: repo);
    await tester.scrollUntilVisible(
      find.byKey(const Key('delete-online')),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.byKey(const Key('delete-online')));
    await frames(tester);
    expect(find.text('Delete your online data?'), findsOneWidget);
    await tester.tap(find.text('Cancel'));
    await frames(tester);
    expect(account.user, isNotNull);

    await tester.tap(find.byKey(const Key('delete-online')));
    await frames(tester);
    await tester.tap(find.byKey(const Key('confirm-delete')));
    await frames(tester, 25);
    expect(account.user, isNull);
    expect(find.byKey(const Key('sign-in')), findsOneWidget);
    expect(await repo.friends(noor.uid), isEmpty);
  });
}
