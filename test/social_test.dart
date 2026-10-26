import 'package:catwalk/core/utils/calendar_date.dart';
import 'package:catwalk/features/cat/domain/cat.dart';
import 'package:catwalk/features/cat/domain/cat_appearance.dart';
import 'package:catwalk/features/cat/domain/cat_mood.dart';
import 'package:catwalk/features/cat/domain/cat_status.dart';
import 'package:catwalk/features/map/data/location_service.dart';
import 'package:catwalk/features/map/domain/inventory.dart';
import 'package:catwalk/features/reminders/data/notification_service.dart';
import 'package:catwalk/features/social/application/social_controller.dart';
import 'package:catwalk/features/social/data/account_service.dart';
import 'package:catwalk/features/social/data/social_repository.dart';
import 'package:catwalk/features/social/domain/social_models.dart';
import 'package:catwalk/services/health/mock_step_repository.dart';
import 'package:catwalk/services/health/step_repository_provider.dart';
import 'package:catwalk/services/storage/local_store_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'map_controller_test.dart' show seededStore;

const mara = AccountUser(uid: 'uid-mara', name: 'Mara');
const noor = AccountUser(uid: 'uid-noor', name: 'Noor');

PublicProfile profile(
  AccountUser user, {
  int week = 0,
  int streak = 0,
  String code = 'ABCDEF',
  bool met = false,
}) => PublicProfile(
  uid: user.uid,
  displayName: user.name,
  friendCode: code,
  streak: streak,
  bestStreak: streak,
  totalSteps: 1000,
  weekSteps: week,
  todaySteps: 100,
  todayGoalMet: met,
  dailyGoal: 6000,
  cats: const [],
  toys: const [],
  beds: 1,
);

Cat cat() => Cat(
  id: '1',
  name: 'Jip',
  appearance: CatAppearance.ginger,
  mood: CatMood.happy,
  status: CatStatus.active,
  consecutiveMissedDays: 0,
  createdAt: DateTime(2026, 10, 1),
);

/// Two players on one fake server.
Future<(FakeSocialRepository, String, String)> twoPlayers() async {
  final repo = FakeSocialRepository();
  final m = await repo.claimFriendCode(mara);
  final n = await repo.claimFriendCode(noor);
  return (repo, m, n);
}

void main() {
  group('friend codes', () {
    test('are six easy characters, the same for the same account', () {
      final code = friendCodeFor('uid-mara');
      expect(code, hasLength(6));
      expect(looksLikeFriendCode(code), isTrue);
      expect(friendCodeFor('uid-mara'), code);
    });

    test('differ between accounts and between attempts', () {
      expect(friendCodeFor('uid-mara'), isNot(friendCodeFor('uid-noor')));
      expect(
        friendCodeFor('uid-mara', attempt: 1),
        isNot(friendCodeFor('uid-mara')),
      );
    });

    test('never use the look-alike characters', () {
      for (var i = 0; i < 300; i++) {
        expect(friendCodeFor('uid-$i'), isNot(matches(RegExp('[01OIL]'))));
      }
    });

    test('typed codes are cleaned up and checked', () {
      expect(normaliseFriendCode(' ab-cd ef '), 'ABCDEF');
      expect(looksLikeFriendCode('ABCDEF'), isTrue);
      expect(looksLikeFriendCode('ABC'), isFalse);
      expect(looksLikeFriendCode('ABCDE0'), isFalse);
    });
  });

  group('the week', () {
    test('starts on Monday', () {
      expect(weekStart(CalendarDate(2026, 10, 26)), CalendarDate(2026, 10, 26));
      expect(weekStart(CalendarDate(2026, 10, 25)), CalendarDate(2026, 10, 19));
      expect(weekStart(CalendarDate(2026, 10, 28)), CalendarDate(2026, 10, 26));
    });
  });

  group('the leaderboard', () {
    test('most steps first, with you marked', () {
      final rows = rankWeek(
        me: profile(mara, week: 5000),
        friends: [profile(noor, week: 9000)],
      );
      expect(rows.map((r) => r.profile.displayName), ['Noor', 'Mara']);
      expect(rows.map((r) => r.rank), [1, 2]);
      expect(rows.map((r) => r.isMe), [false, true]);
    });

    test('equal steps share a rank and are ordered by name', () {
      final rows = rankWeek(
        me: profile(noor, week: 4000),
        friends: [
          profile(mara, week: 4000),
          profile(const AccountUser(uid: 'z', name: 'Zed'), week: 1000),
        ],
      );
      expect(rows.map((r) => r.profile.displayName), ['Mara', 'Noor', 'Zed']);
      expect(rows.map((r) => r.rank), [1, 1, 3]);
    });

    test('you alone are first', () {
      expect(rankWeek(me: profile(mara), friends: const []).single.rank, 1);
    });
  });

  group('the profile friends see', () {
    test('summarises the player and leaves out ids and places', () {
      final built = buildPublicProfile(
        user: mara,
        friendCode: 'ABCDEF',
        cats: [cat()],
        inventory: const Inventory(toys: ['ball'], beds: 2),
        streak: 3,
        bestStreak: 9,
        totalSteps: 50000,
        weekSteps: 12000,
        todaySteps: 6500,
        dailyGoal: 6000,
      );
      expect(built.todayGoalMet, isTrue);
      expect(built.cats.single.name, 'Jip');
      expect(built.toys, ['ball']);
      expect(built.beds, 2);
      final json = built.toJson();
      expect(json.keys, isNot(contains('uid')));
      expect(json.toString(), isNot(contains('id: 1')));
    });

    test('survives a round trip through JSON', () {
      final built = buildPublicProfile(
        user: mara,
        friendCode: 'ABCDEF',
        cats: [cat()],
        inventory: const Inventory(),
        streak: 1,
        bestStreak: 2,
        totalSteps: 3,
        weekSteps: 4,
        todaySteps: 5,
        dailyGoal: 6,
      );
      final back = PublicProfile.fromJson(mara.uid, built.toJson());
      expect(back.displayName, 'Mara');
      expect(back.cats.single.mood, 'happy');
      expect(back.weekSteps, 4);
    });

    test('a long name is cut to 40 and an empty one becomes Walker', () {
      PublicProfile named(String name) => buildPublicProfile(
        user: AccountUser(uid: 'u', name: name),
        friendCode: 'ABCDEF',
        cats: const [],
        inventory: const Inventory(),
        streak: 0,
        bestStreak: 0,
        totalSteps: 0,
        weekSteps: 0,
        todaySteps: 0,
        dailyGoal: 6000,
      );
      expect(named('x' * 80).displayName, hasLength(40));
      expect(named('  ').displayName, 'Walker');
    });

    test('odd or missing values fall back to safe ones', () {
      final back = PublicProfile.fromJson('u', {
        'cats': [{}],
        'beds': 0,
      });
      expect(back.displayName, 'Walker');
      expect(back.beds, 1);
      expect(back.cats.single.appearance, 'cream');
    });
  });

  group('friends on the fake server', () {
    test('a request needs accepting before the two are friends', () async {
      final (repo, _, noorCode) = await twoPlayers();
      await repo.publish(profile(mara, week: 100));
      await repo.publish(profile(noor, week: 200));
      expect(
        await repo.sendRequest(me: mara, code: noorCode),
        RequestResult.sent,
      );
      expect(await repo.friends(mara.uid), isEmpty);
      final request = (await repo.incoming(noor.uid)).single;
      expect(request.fromName, 'Mara');
      await repo.accept(me: noor, request: request);
      expect((await repo.friends(mara.uid)).single.displayName, 'Noor');
      expect((await repo.friends(noor.uid)).single.displayName, 'Mara');
      expect(await repo.incoming(noor.uid), isEmpty);
    });

    test('only the person asked can accept', () async {
      final (repo, _, noorCode) = await twoPlayers();
      await repo.sendRequest(me: mara, code: noorCode);
      final request = (await repo.incoming(noor.uid)).single;
      await repo.accept(me: mara, request: request);
      expect(await repo.friends(mara.uid), isEmpty);
    });

    test('odd requests are told apart', () async {
      final (repo, maraCode, noorCode) = await twoPlayers();
      expect(
        await repo.sendRequest(me: mara, code: maraCode),
        RequestResult.yourself,
      );
      expect(
        await repo.sendRequest(me: mara, code: 'ZZZZZZ'),
        RequestResult.unknownCode,
      );
      await repo.sendRequest(me: mara, code: noorCode);
      expect(
        await repo.sendRequest(me: mara, code: noorCode),
        RequestResult.alreadyRequested,
      );
      expect(
        await repo.sendRequest(me: noor, code: maraCode),
        RequestResult.alreadyRequested,
      );
      await repo.accept(
        me: noor,
        request: (await repo.incoming(noor.uid)).single,
      );
      expect(
        await repo.sendRequest(me: mara, code: noorCode),
        RequestResult.alreadyFriends,
      );
    });

    test('a code stays the same each time it is claimed', () async {
      final repo = FakeSocialRepository();
      expect(
        await repo.claimFriendCode(mara),
        await repo.claimFriendCode(mara),
      );
    });

    test('a wave goes once a day, and only to a friend', () async {
      final (repo, _, noorCode) = await twoPlayers();
      final today = CalendarDate(2026, 10, 26);
      expect(
        await repo.sendNudge(me: mara, toUid: noor.uid, today: today),
        isFalse,
      );
      await repo.sendRequest(me: mara, code: noorCode);
      await repo.accept(
        me: noor,
        request: (await repo.incoming(noor.uid)).single,
      );
      expect(
        await repo.sendNudge(me: mara, toUid: noor.uid, today: today),
        isTrue,
      );
      expect(
        await repo.sendNudge(me: mara, toUid: noor.uid, today: today),
        isFalse,
      );
      expect(
        await repo.sendNudge(
          me: mara,
          toUid: noor.uid,
          today: today.addDays(1),
        ),
        isTrue,
      );
      expect((await repo.nudges(noor.uid)), hasLength(2));
      await repo.clearNudges(noor.uid);
      expect(await repo.nudges(noor.uid), isEmpty);
    });

    test('removing a friend ends it for both', () async {
      final (repo, _, noorCode) = await twoPlayers();
      await repo.publish(profile(mara));
      await repo.publish(profile(noor));
      await repo.sendRequest(me: mara, code: noorCode);
      await repo.accept(
        me: noor,
        request: (await repo.incoming(noor.uid)).single,
      );
      await repo.removeFriend(uid: mara.uid, friendUid: noor.uid);
      expect(await repo.friends(noor.uid), isEmpty);
    });

    test(
      'deleting your data removes the profile, code and friendships',
      () async {
        final (repo, maraCode, noorCode) = await twoPlayers();
        await repo.publish(profile(mara));
        await repo.publish(profile(noor));
        await repo.sendRequest(me: mara, code: noorCode);
        await repo.accept(
          me: noor,
          request: (await repo.incoming(noor.uid)).single,
        );
        await repo.deleteMine(mara.uid);
        expect(await repo.friends(noor.uid), isEmpty);
        expect(await repo.lookupCode(maraCode), isNull);
      },
    );

    test('a bad network throws, so callers can show "try later"', () async {
      final repo = FakeSocialRepository()..offline = true;
      expect(() => repo.claimFriendCode(mara), throwsStateError);
    });
  });

  group('the social controller', () {
    Future<ProviderContainer> start({
      required AccountService account,
      required FakeSocialRepository repo,
    }) async {
      final store = await seededStore();
      final container = ProviderContainer(
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
      );
      addTearDown(container.dispose);
      return container;
    }

    test('signed out there is nothing to show', () async {
      final container = await start(
        account: FakeAccountService(),
        repo: FakeSocialRepository(),
      );
      final state = await container.read(socialControllerProvider.future);
      expect(state.user, isNull);
      expect(state.leaderboard, isEmpty);
    });

    test('signing in publishes your profile and gives you a code', () async {
      final repo = FakeSocialRepository();
      final container = await start(
        account: FakeAccountService(willSignIn: mara),
        repo: repo,
      );
      await container.read(socialControllerProvider.future);
      final ok = await container
          .read(socialControllerProvider.notifier)
          .signIn();
      expect(ok, isTrue);
      final state = container.read(socialControllerProvider).requireValue;
      expect(state.user?.name, 'Mara');
      expect(state.me!.friendCode, hasLength(6));
      expect(state.me!.cats.single.name, 'Jip');
      expect(state.leaderboard.single.isMe, isTrue);
      expect((await repo.lookupCode(state.me!.friendCode))?.uid, mara.uid);
    });

    test('a failed sign-in stays signed out', () async {
      final container = await start(
        account: FakeAccountService(),
        repo: FakeSocialRepository(),
      );
      await container.read(socialControllerProvider.future);
      expect(
        await container.read(socialControllerProvider.notifier).signIn(),
        isFalse,
      );
      expect(
        container.read(socialControllerProvider).requireValue.user,
        isNull,
      );
    });

    test(
      'adds a friend by a typed code, and the friend appears once accepted',
      () async {
        final repo = FakeSocialRepository();
        final noorCode = await repo.claimFriendCode(noor);
        await repo.publish(profile(noor, week: 9000, code: noorCode));
        final container = await start(
          account: FakeAccountService(user: mara),
          repo: repo,
        );
        final controller = container.read(socialControllerProvider.notifier);
        await container.read(socialControllerProvider.future);

        expect(
          await controller.addByCode(' ${noorCode.toLowerCase()} '),
          RequestResult.sent,
        );
        await repo.accept(
          me: noor,
          request: (await repo.incoming(noor.uid)).single,
        );
        await controller.refresh();
        final state = container.read(socialControllerProvider).requireValue;
        expect(state.friends.single.displayName, 'Noor');
        expect(state.leaderboard.first.profile.displayName, 'Noor');
      },
    );

    test('a badly typed code is not even sent', () async {
      final repo = FakeSocialRepository();
      final container = await start(
        account: FakeAccountService(user: mara),
        repo: repo,
      );
      await container.read(socialControllerProvider.future);
      expect(
        await container.read(socialControllerProvider.notifier).addByCode('12'),
        RequestResult.unknownCode,
      );
    });

    test('accepting a request makes the two friends', () async {
      final repo = FakeSocialRepository();
      final maraCode = await repo.claimFriendCode(mara);
      await repo.publish(profile(mara, code: maraCode));
      final noorCode = await repo.claimFriendCode(noor);
      await repo.sendRequest(me: noor, code: maraCode);
      expect(noorCode, isNotEmpty);
      final container = await start(
        account: FakeAccountService(user: mara),
        repo: repo,
      );
      await container.read(socialControllerProvider.future);
      await repo.publish(profile(noor, code: noorCode));
      final request = container
          .read(socialControllerProvider)
          .requireValue
          .requests
          .single;
      await container.read(socialControllerProvider.notifier).accept(request);
      final state = container.read(socialControllerProvider).requireValue;
      expect(state.requests, isEmpty);
      expect(state.friends.single.displayName, 'Noor');
    });

    test('waving is allowed once and remembered', () async {
      final repo = FakeSocialRepository();
      final maraCode = await repo.claimFriendCode(mara);
      await repo.publish(profile(mara, code: maraCode));
      await repo.claimFriendCode(noor);
      await repo.publish(profile(noor));
      await repo.sendRequest(me: noor, code: maraCode);
      final container = await start(
        account: FakeAccountService(user: mara),
        repo: repo,
      );
      final controller = container.read(socialControllerProvider.notifier);
      await container.read(socialControllerProvider.future);
      await controller.accept(
        container.read(socialControllerProvider).requireValue.requests.single,
      );
      final friend = container
          .read(socialControllerProvider)
          .requireValue
          .friends
          .single;
      expect(await controller.nudge(friend), isTrue);
      expect(await controller.nudge(friend), isFalse);
      expect(
        container.read(socialControllerProvider).requireValue.nudgedToday,
        {noor.uid},
      );
      expect(await repo.nudges(noor.uid), hasLength(1));
    });

    test('when the server cannot be reached the state says offline', () async {
      final repo = FakeSocialRepository()..offline = true;
      final container = await start(
        account: FakeAccountService(user: mara),
        repo: repo,
      );
      final state = await container.read(socialControllerProvider.future);
      expect(state.offline, isTrue);
      expect(state.user?.name, 'Mara');
    });

    test(
      'deleting your online data signs you out and clears the server',
      () async {
        final repo = FakeSocialRepository();
        final account = FakeAccountService(user: mara);
        final container = await start(account: account, repo: repo);
        final controller = container.read(socialControllerProvider.notifier);
        final code = (await container.read(socialControllerProvider.future))
            .me!
            .friendCode;
        await controller.deleteOnline();
        expect(account.user, isNull);
        expect(await repo.lookupCode(code), isNull);
        expect(
          container.read(socialControllerProvider).requireValue.user,
          isNull,
        );
      },
    );
  });
}
