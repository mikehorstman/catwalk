import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/utils/calendar_date.dart';
import '../../daily_goal/data/history_repository.dart';
import '../../daily_goal/domain/streak.dart';
import '../../steps/presentation/home_controller.dart';
import '../data/account_service.dart';
import '../data/social_repository.dart';
import '../domain/social_models.dart';

/// Builds the profile friends see from the app's own numbers.
Future<PublicProfile> buildMyProfile({
  required Ref ref,
  required AccountUser user,
  required String friendCode,
  required HomeState home,
}) async {
  final history = await ref.read(historyRepositoryProvider).readAll();
  final today = CalendarDate.today();
  final monday = weekStart(today);
  final stepsByDate = {for (final day in history) day.date: day.steps};
  var week = 0;
  for (var i = 0; i <= 6; i++) {
    final date = monday.addDays(i);
    if (date.toDateTime().isAfter(today.toDateTime())) break;
    week += date == today ? home.today.steps : (stepsByDate[date] ?? 0);
  }
  final best = bestStreak(history);
  return buildPublicProfile(
    user: user,
    friendCode: friendCode,
    cats: home.cats,
    inventory: home.inventory,
    rooms: home.rooms.length,
    streak: home.currentStreak,
    bestStreak: best > home.currentStreak ? best : home.currentStreak,
    totalSteps: home.totalSteps,
    weekSteps: week,
    todaySteps: home.today.steps,
    dailyGoal: home.today.stepGoal,
  );
}

/// Keeps the profile friends see up to date while signed in. It is called
/// whenever Home loads, and does nothing when nobody is signed in.
class SocialPublisher {
  SocialPublisher(this._ref);

  final Ref _ref;
  String? _code;
  String? _lastUid;
  Map<String, Object>? _last;
  DateTime? _lastAt;

  /// How long to wait before sending an unchanged profile again.
  static const Duration quietFor = Duration(minutes: 10);

  /// Publishes [home] when it changed, or when it has been a while.
  Future<void> publish(HomeState home) async {
    final user = _ref.read(accountServiceProvider).current;
    if (user == null) return;
    try {
      final repo = _ref.read(socialRepositoryProvider);
      if (_lastUid != user.uid) {
        _code = null;
        _last = null;
        _lastUid = user.uid;
      }
      _code ??= await repo.claimFriendCode(user);
      final profile = await buildMyProfile(
        ref: _ref,
        user: user,
        friendCode: _code!,
        home: home,
      );
      final json = profile.toJson();
      final fresh =
          _last == null ||
          '$_last' != '$json' ||
          _lastAt == null ||
          DateTime.now().difference(_lastAt!) > quietFor;
      if (!fresh) return;
      await repo.publish(profile);
      _last = json;
      _lastAt = DateTime.now();
    } catch (_) {
      // Offline: the next load tries again.
    }
  }
}

/// The shared publisher.
final socialPublisherProvider = Provider<SocialPublisher>(
  (ref) => SocialPublisher(ref),
);

/// Everything the Friends screen shows.
class SocialState {
  const SocialState({
    this.user,
    this.me,
    this.friends = const [],
    this.requests = const [],
    this.nudges = const [],
    this.offline = false,
    this.nudgedToday = const {},
  });

  /// Who is signed in, or null.
  final AccountUser? user;

  /// Your own profile as friends see it.
  final PublicProfile? me;

  /// Your friends' profiles.
  final List<PublicProfile> friends;

  /// Requests waiting for your answer.
  final List<FriendRequest> requests;

  /// Waves from friends.
  final List<Nudge> nudges;

  /// True when the last refresh could not reach the server.
  final bool offline;

  /// Friends already waved at today.
  final Set<String> nudgedToday;

  /// This week's leaderboard, or empty without a profile.
  List<LeaderboardRow> get leaderboard =>
      me == null ? const [] : rankWeek(me: me!, friends: friends);

  /// A copy with the given changes.
  SocialState copyWith({
    PublicProfile? me,
    List<PublicProfile>? friends,
    List<FriendRequest>? requests,
    List<Nudge>? nudges,
    bool? offline,
    Set<String>? nudgedToday,
  }) => SocialState(
    user: user,
    me: me ?? this.me,
    friends: friends ?? this.friends,
    requests: requests ?? this.requests,
    nudges: nudges ?? this.nudges,
    offline: offline ?? this.offline,
    nudgedToday: nudgedToday ?? this.nudgedToday,
  );
}

/// The Friends screen's brain: sign in, friends, requests, waves.
class SocialController extends AsyncNotifier<SocialState> {
  AccountUser? get _user => ref.read(accountServiceProvider).current;

  @override
  Future<SocialState> build() async {
    final user = _user;
    if (user == null) return const SocialState();
    return _load(user);
  }

  Future<SocialState> _load(AccountUser user) async {
    try {
      final repo = ref.read(socialRepositoryProvider);
      final home = await ref.read(homeControllerProvider.future);
      final code = await repo.claimFriendCode(user);
      final me = await buildMyProfile(
        ref: ref,
        user: user,
        friendCode: code,
        home: home,
      );
      await repo.publish(me);
      return SocialState(
        user: user,
        me: me,
        friends: await repo.friends(user.uid),
        requests: await repo.incoming(user.uid),
        nudges: await repo.nudges(user.uid),
      );
    } catch (_) {
      return SocialState(user: user, offline: true);
    }
  }

  /// Signs in with Google. True when it worked.
  Future<bool> signIn() async {
    final user = await ref.read(accountServiceProvider).signInWithGoogle();
    if (user == null) return false;
    state = AsyncData(await _load(user));
    return true;
  }

  /// Signs out. Friends stay friends; signing back in brings them back.
  Future<void> signOut() async {
    await ref.read(accountServiceProvider).signOut();
    state = const AsyncData(SocialState());
  }

  /// Reloads friends, requests and waves.
  Future<void> refresh() async {
    final user = _user;
    if (user == null) return;
    final previous = state.value;
    final next = await _load(user);
    state = AsyncData(
      next.offline && previous != null
          ? previous.copyWith(offline: true)
          : next.copyWith(nudgedToday: previous?.nudgedToday),
    );
  }

  /// Asks the owner of [typed] to be friends.
  Future<RequestResult> addByCode(String typed) async {
    final user = _user;
    if (user == null) return RequestResult.failed;
    final code = normaliseFriendCode(typed);
    if (!looksLikeFriendCode(code)) return RequestResult.unknownCode;
    return ref.read(socialRepositoryProvider).sendRequest(me: user, code: code);
  }

  /// Accepts [request].
  Future<void> accept(FriendRequest request) async {
    final user = _user;
    if (user == null) return;
    await ref.read(socialRepositoryProvider).accept(me: user, request: request);
    await refresh();
  }

  /// Declines [request].
  Future<void> decline(FriendRequest request) async {
    final user = _user;
    if (user == null) return;
    await ref
        .read(socialRepositoryProvider)
        .decline(me: user, request: request);
    await refresh();
  }

  /// Ends a friendship.
  Future<void> remove(PublicProfile friend) async {
    final user = _user;
    if (user == null) return;
    await ref
        .read(socialRepositoryProvider)
        .removeFriend(uid: user.uid, friendUid: friend.uid);
    await refresh();
  }

  /// Waves at [friend]. False when a wave went out already today.
  Future<bool> nudge(PublicProfile friend) async {
    final user = _user;
    if (user == null) return false;
    final sent = await ref
        .read(socialRepositoryProvider)
        .sendNudge(me: user, toUid: friend.uid, today: CalendarDate.today());
    final current = state.value;
    if (current != null) {
      state = AsyncData(
        current.copyWith(nudgedToday: {...current.nudgedToday, friend.uid}),
      );
    }
    return sent;
  }

  /// Clears the waves you have seen.
  Future<void> clearNudges() async {
    final user = _user;
    if (user == null) return;
    await ref.read(socialRepositoryProvider).clearNudges(user.uid);
    await refresh();
  }

  /// Deletes everything online about you, then signs out.
  Future<void> deleteOnline() async {
    final user = _user;
    if (user == null) return;
    await ref.read(socialRepositoryProvider).deleteMine(user.uid);
    await signOut();
  }
}

/// The shared social controller.
final socialControllerProvider =
    AsyncNotifierProvider<SocialController, SocialState>(SocialController.new);
