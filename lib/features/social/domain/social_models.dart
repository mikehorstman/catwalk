import '../../../core/utils/calendar_date.dart';
import '../../cat/domain/cat.dart';
import '../../map/domain/inventory.dart';

/// Who is signed in.
class AccountUser {
  const AccountUser({required this.uid, required this.name, this.photoUrl});

  /// The account id.
  final String uid;

  /// The name shown to friends.
  final String name;

  /// The profile picture, if any.
  final String? photoUrl;
}

/// One cat as friends see it: a name, a coat and a mood. Never an id.
class PublicCat {
  const PublicCat({
    required this.name,
    required this.appearance,
    required this.mood,
    required this.away,
  });

  /// Rebuilds a cat from JSON; odd values fall back to safe ones.
  factory PublicCat.fromJson(Map<String, dynamic> json) => PublicCat(
    name: (json['name'] as String?) ?? 'Cat',
    appearance: (json['appearance'] as String?) ?? 'cream',
    mood: (json['mood'] as String?) ?? 'neutral',
    away: json['away'] == true,
  );

  /// A friend-safe view of [cat].
  factory PublicCat.of(Cat cat) => PublicCat(
    name: cat.name,
    appearance: cat.appearance.name,
    mood: cat.mood.name,
    away: cat.status.name == 'runaway',
  );

  /// The cat's name.
  final String name;

  /// The coat, as the enum name.
  final String appearance;

  /// The mood, as the enum name.
  final String mood;

  /// True while the cat has run away.
  final bool away;

  /// Plain-JSON form.
  Map<String, Object> toJson() => {
    'name': name,
    'appearance': appearance,
    'mood': mood,
    'away': away,
  };
}

/// What a friend sees of you: a summary, never your places or your history.
class PublicProfile {
  const PublicProfile({
    required this.uid,
    required this.displayName,
    required this.friendCode,
    required this.streak,
    required this.bestStreak,
    required this.totalSteps,
    required this.weekSteps,
    required this.todaySteps,
    required this.todayGoalMet,
    required this.dailyGoal,
    required this.cats,
    required this.toys,
    required this.rooms,
    this.placed = const {},
    this.photoUrl,
  });

  /// Rebuilds a profile from a Firestore document and its [uid].
  factory PublicProfile.fromJson(String uid, Map<String, dynamic> json) {
    int number(String key) => (json[key] as num?)?.toInt() ?? 0;
    return PublicProfile(
      uid: uid,
      displayName: (json['displayName'] as String?) ?? 'Walker',
      photoUrl: json['photoUrl'] as String?,
      friendCode: (json['friendCode'] as String?) ?? '',
      streak: number('streak'),
      bestStreak: number('bestStreak'),
      totalSteps: number('totalSteps'),
      weekSteps: number('weekSteps'),
      todaySteps: number('todaySteps'),
      todayGoalMet: json['todayGoalMet'] == true,
      dailyGoal: number('dailyGoal'),
      cats: [
        for (final item in (json['cats'] as List<dynamic>?) ?? const [])
          PublicCat.fromJson(Map<String, dynamic>.from(item as Map)),
      ],
      toys: [
        for (final item in (json['toys'] as List<dynamic>?) ?? const [])
          item.toString(),
      ],
      rooms: number('rooms') == 0 ? 1 : number('rooms').clamp(1, 4),
      placed: {
        if (json['placed'] is Map)
          for (final e in (json['placed'] as Map).entries)
            if (e.key is String && e.value is String)
              e.key as String: e.value as String,
      },
    );
  }

  /// The account id.
  final String uid;

  /// The name friends see.
  final String displayName;

  /// The profile picture, if any.
  final String? photoUrl;

  /// The code friends type to find this player.
  final String friendCode;

  /// Days in a row the goal was reached.
  final int streak;

  /// The longest streak so far.
  final int bestStreak;

  /// Steps over every saved day.
  final int totalSteps;

  /// Steps since Monday.
  final int weekSteps;

  /// Steps so far today.
  final int todaySteps;

  /// Whether today's goal is reached.
  final bool todayGoalMet;

  /// Today's goal.
  final int dailyGoal;

  /// The cats in the room.
  final List<PublicCat> cats;

  /// The toys owned, as ids.
  final List<String> toys;

  /// The rooms owned, from 1 to 4.
  final int rooms;

  /// What stands where: `room:slot` to item id, at most 20 entries.
  final Map<String, String> placed;

  /// Plain-JSON form for Firestore. The uid is the document id, so it is not
  /// stored again.
  Map<String, Object> toJson() => {
    'displayName': displayName,
    'photoUrl': ?photoUrl,
    'friendCode': friendCode,
    'streak': streak,
    'bestStreak': bestStreak,
    'totalSteps': totalSteps,
    'weekSteps': weekSteps,
    'todaySteps': todaySteps,
    'todayGoalMet': todayGoalMet,
    'dailyGoal': dailyGoal,
    'cats': [for (final cat in cats) cat.toJson()],
    'toys': toys,
    'rooms': rooms,
    'placed': placed,
  };
}

/// Builds the profile friends see from what the app knows.
PublicProfile buildPublicProfile({
  required AccountUser user,
  required String friendCode,
  required List<Cat> cats,
  required Inventory inventory,
  required int rooms,
  Map<String, String> placed = const {},
  required int streak,
  required int bestStreak,
  required int totalSteps,
  required int weekSteps,
  required int todaySteps,
  required int dailyGoal,
}) {
  final name = user.name.trim();
  return PublicProfile(
    uid: user.uid,
    displayName: name.isEmpty
        ? 'Walker'
        : (name.length > 40 ? name.substring(0, 40) : name),
    photoUrl: user.photoUrl,
    friendCode: friendCode,
    streak: streak,
    bestStreak: bestStreak,
    totalSteps: totalSteps,
    weekSteps: weekSteps,
    todaySteps: todaySteps,
    todayGoalMet: dailyGoal > 0 && todaySteps >= dailyGoal,
    dailyGoal: dailyGoal,
    cats: [for (final cat in cats) PublicCat.of(cat)],
    toys: inventory.toys,
    rooms: rooms,
    placed: placed,
  );
}

/// The Monday of [date]'s week.
CalendarDate weekStart(CalendarDate date) {
  final weekday = date.toDateTime().weekday; // Monday = 1
  return date.addDays(-(weekday - 1));
}

/// Characters a friend code uses: no 0, O, 1, I or L, so it is easy to read out.
const String friendCodeAlphabet = 'ABCDEFGHJKMNPQRSTUVWXYZ23456789';

/// Length of a friend code.
const int friendCodeLength = 6;

/// A friend code for [uid]. The same uid and [attempt] always give the same
/// code, and a higher attempt gives a different one, for the rare clash.
String friendCodeFor(String uid, {int attempt = 0}) {
  // FNV-1a, 64 bit folded, so the code needs no network and no randomness.
  var hash = 0xcbf29ce484222325;
  for (final unit in '$uid#$attempt'.codeUnits) {
    hash ^= unit;
    hash = (hash * 0x100000001b3) & 0x7fffffffffffffff;
  }
  final buffer = StringBuffer();
  var rest = hash;
  for (var i = 0; i < friendCodeLength; i++) {
    buffer.write(friendCodeAlphabet[rest % friendCodeAlphabet.length]);
    rest ~/= friendCodeAlphabet.length;
  }
  return buffer.toString();
}

/// Cleans what a player typed: upper case, spaces and dashes removed.
String normaliseFriendCode(String typed) =>
    typed.toUpperCase().replaceAll(RegExp(r'[\s\-]'), '');

/// Whether [code] could be a friend code at all.
bool looksLikeFriendCode(String code) =>
    code.length == friendCodeLength &&
    code.split('').every(friendCodeAlphabet.contains);

/// A request to be friends.
class FriendRequest {
  const FriendRequest({
    required this.from,
    required this.fromName,
    required this.to,
  });

  /// Who asked.
  final String from;

  /// The name of who asked.
  final String fromName;

  /// Who was asked.
  final String to;
}

/// A wave from a friend.
class Nudge {
  const Nudge({
    required this.id,
    required this.from,
    required this.fromName,
    required this.to,
    required this.on,
  });

  /// The document id.
  final String id;

  /// Who sent it.
  final String from;

  /// The sender's name.
  final String fromName;

  /// Who it is for.
  final String to;

  /// The day it was sent.
  final CalendarDate on;
}

/// One row of the weekly leaderboard.
class LeaderboardRow {
  const LeaderboardRow({
    required this.rank,
    required this.profile,
    required this.isMe,
  });

  /// 1 for the most steps. Equal steps share a rank.
  final int rank;

  /// The player.
  final PublicProfile profile;

  /// True for the signed-in player.
  final bool isMe;
}

/// The friends and you, most steps this week first. Equal steps share a rank
/// and are then ordered by name. A friend whose profile is from before this
/// week still shows its own week number, so [monday] filters stale ones out as
/// zero.
List<LeaderboardRow> rankWeek({
  required PublicProfile me,
  required List<PublicProfile> friends,
}) {
  final all = [me, ...friends];
  all.sort((a, b) {
    final bySteps = b.weekSteps.compareTo(a.weekSteps);
    return bySteps != 0
        ? bySteps
        : a.displayName.toLowerCase().compareTo(b.displayName.toLowerCase());
  });
  final rows = <LeaderboardRow>[];
  var rank = 0;
  int? previous;
  for (var i = 0; i < all.length; i++) {
    if (all[i].weekSteps != previous) rank = i + 1;
    previous = all[i].weekSteps;
    rows.add(
      LeaderboardRow(rank: rank, profile: all[i], isMe: all[i].uid == me.uid),
    );
  }
  return rows;
}
