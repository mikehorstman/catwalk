import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/utils/calendar_date.dart';
import '../domain/social_models.dart';

/// The shared social repository. Tests replace it with [FakeSocialRepository].
final socialRepositoryProvider = Provider<SocialRepository>(
  (ref) => FirestoreSocialRepository(),
);

/// What came of asking someone to be friends.
enum RequestResult {
  /// The request was sent.
  sent,

  /// The two are friends already.
  alreadyFriends,

  /// A request is already waiting, from you or from them.
  alreadyRequested,

  /// It was your own code.
  yourself,

  /// Nobody has that code.
  unknownCode,

  /// The network or the server said no.
  failed,
}

/// A code's owner, as found by the code.
class CodeOwner {
  const CodeOwner({required this.uid, required this.name});

  /// The owner's account id.
  final String uid;

  /// The owner's name.
  final String name;
}

/// Everything social, behind one seam: profiles, codes, friends, nudges.
///
/// Nothing here is needed to walk. Every call may fail on a bad network, so
/// callers treat a failure as "try again later".
abstract class SocialRepository {
  /// The friend code of [user], claimed on first use and the same ever after.
  Future<String> claimFriendCode(AccountUser user);

  /// Saves the profile friends see.
  Future<void> publish(PublicProfile profile);

  /// Finds the owner of a friend code, or null.
  Future<CodeOwner?> lookupCode(String code);

  /// Asks the owner of [code] to be friends.
  Future<RequestResult> sendRequest({
    required AccountUser me,
    required String code,
  });

  /// Requests waiting for [uid] to answer.
  Future<List<FriendRequest>> incoming(String uid);

  /// Accepts [request], which makes the two friends.
  Future<void> accept({
    required AccountUser me,
    required FriendRequest request,
  });

  /// Declines [request].
  Future<void> decline({
    required AccountUser me,
    required FriendRequest request,
  });

  /// The profiles of [uid]'s friends.
  Future<List<PublicProfile>> friends(String uid);

  /// Ends the friendship of [uid] and [friendUid].
  Future<void> removeFriend({required String uid, required String friendUid});

  /// Waves at [toUid]. False when a wave was already sent today.
  Future<bool> sendNudge({
    required AccountUser me,
    required String toUid,
    required CalendarDate today,
  });

  /// Waves sent to [uid].
  Future<List<Nudge>> nudges(String uid);

  /// Clears the waves sent to [uid].
  Future<void> clearNudges(String uid);

  /// Deletes everything online about [uid]: the profile, the code, the
  /// friendships and the requests.
  Future<void> deleteMine(String uid);
}

String _pair(String a, String b) => a.compareTo(b) < 0 ? '${a}_$b' : '${b}_$a';

/// An in-memory social backend for tests. It follows the same rules as the
/// real one, so a test with two players behaves like two phones.
class FakeSocialRepository implements SocialRepository {
  final Map<String, PublicProfile> _profiles = {};
  final Map<String, String> _codes = {}; // code -> uid
  final Map<String, String> _names = {}; // uid -> name
  final Set<String> _friendships = {};
  final Map<String, FriendRequest> _requests = {};
  final Map<String, Nudge> _nudges = {};

  /// Makes every call throw, to test a bad network.
  bool offline = false;

  void _check() {
    if (offline) throw StateError('offline');
  }

  @override
  Future<String> claimFriendCode(AccountUser user) async {
    _check();
    _names[user.uid] = user.name;
    for (final entry in _codes.entries) {
      if (entry.value == user.uid) return entry.key;
    }
    for (var attempt = 0; attempt < 10; attempt++) {
      final code = friendCodeFor(user.uid, attempt: attempt);
      if (!_codes.containsKey(code)) {
        _codes[code] = user.uid;
        return code;
      }
    }
    throw StateError('no free code');
  }

  @override
  Future<void> publish(PublicProfile profile) async {
    _check();
    _profiles[profile.uid] = profile;
    _names[profile.uid] = profile.displayName;
  }

  @override
  Future<CodeOwner?> lookupCode(String code) async {
    _check();
    final uid = _codes[code];
    return uid == null ? null : CodeOwner(uid: uid, name: _names[uid] ?? '');
  }

  @override
  Future<RequestResult> sendRequest({
    required AccountUser me,
    required String code,
  }) async {
    _check();
    final owner = await lookupCode(code);
    if (owner == null) return RequestResult.unknownCode;
    if (owner.uid == me.uid) return RequestResult.yourself;
    if (_friendships.contains(_pair(me.uid, owner.uid))) {
      return RequestResult.alreadyFriends;
    }
    if (_requests.containsKey('${me.uid}_${owner.uid}') ||
        _requests.containsKey('${owner.uid}_${me.uid}')) {
      return RequestResult.alreadyRequested;
    }
    _requests['${me.uid}_${owner.uid}'] = FriendRequest(
      from: me.uid,
      fromName: me.name,
      to: owner.uid,
    );
    return RequestResult.sent;
  }

  @override
  Future<List<FriendRequest>> incoming(String uid) async {
    _check();
    return [
      for (final request in _requests.values)
        if (request.to == uid) request,
    ];
  }

  @override
  Future<void> accept({
    required AccountUser me,
    required FriendRequest request,
  }) async {
    _check();
    if (request.to != me.uid) return;
    _friendships.add(_pair(request.from, request.to));
    _requests.remove('${request.from}_${request.to}');
  }

  @override
  Future<void> decline({
    required AccountUser me,
    required FriendRequest request,
  }) async {
    _check();
    if (request.to != me.uid) return;
    _requests.remove('${request.from}_${request.to}');
  }

  @override
  Future<List<PublicProfile>> friends(String uid) async {
    _check();
    final result = <PublicProfile>[];
    for (final key in _friendships) {
      final members = key.split('_');
      if (!members.contains(uid)) continue;
      final profile = _profiles[members.firstWhere((id) => id != uid)];
      if (profile != null) result.add(profile);
    }
    return result;
  }

  @override
  Future<void> removeFriend({
    required String uid,
    required String friendUid,
  }) async {
    _check();
    _friendships.remove(_pair(uid, friendUid));
  }

  @override
  Future<bool> sendNudge({
    required AccountUser me,
    required String toUid,
    required CalendarDate today,
  }) async {
    _check();
    if (!_friendships.contains(_pair(me.uid, toUid))) return false;
    final id = '${me.uid}_${toUid}_${today.toIsoDate()}';
    if (_nudges.containsKey(id)) return false;
    _nudges[id] = Nudge(
      id: id,
      from: me.uid,
      fromName: me.name,
      to: toUid,
      on: today,
    );
    return true;
  }

  @override
  Future<List<Nudge>> nudges(String uid) async {
    _check();
    return [
      for (final nudge in _nudges.values)
        if (nudge.to == uid) nudge,
    ];
  }

  @override
  Future<void> clearNudges(String uid) async {
    _check();
    _nudges.removeWhere((_, nudge) => nudge.to == uid);
  }

  @override
  Future<void> deleteMine(String uid) async {
    _check();
    _profiles.remove(uid);
    _codes.removeWhere((_, owner) => owner == uid);
    _friendships.removeWhere((key) => key.split('_').contains(uid));
    _requests.removeWhere((_, r) => r.from == uid || r.to == uid);
    _nudges.removeWhere((_, n) => n.from == uid || n.to == uid);
  }
}

/// The real thing, on Cloud Firestore. The rules are in `firestore.rules`.
class FirestoreSocialRepository implements SocialRepository {
  FirebaseFirestore get _db => FirebaseFirestore.instance;

  @override
  Future<String> claimFriendCode(AccountUser user) async {
    final mine = await _db.collection('users').doc(user.uid).get();
    final saved = mine.data()?['friendCode'];
    if (saved is String && saved.isNotEmpty) return saved;
    for (var attempt = 0; attempt < 10; attempt++) {
      final code = friendCodeFor(user.uid, attempt: attempt);
      final ref = _db.collection('friendCodes').doc(code);
      final taken = await ref.get();
      if (taken.exists && taken.data()?['uid'] != user.uid) continue;
      await ref.set({'uid': user.uid, 'displayName': user.name});
      return code;
    }
    throw StateError('no free friend code');
  }

  @override
  Future<void> publish(PublicProfile profile) async {
    await _db.collection('users').doc(profile.uid).set({
      ...profile.toJson(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  @override
  Future<CodeOwner?> lookupCode(String code) async {
    final doc = await _db.collection('friendCodes').doc(code).get();
    final data = doc.data();
    if (data == null || data['uid'] is! String) return null;
    return CodeOwner(
      uid: data['uid'] as String,
      name: (data['displayName'] as String?) ?? '',
    );
  }

  @override
  Future<RequestResult> sendRequest({
    required AccountUser me,
    required String code,
  }) async {
    try {
      final owner = await lookupCode(code);
      if (owner == null) return RequestResult.unknownCode;
      if (owner.uid == me.uid) return RequestResult.yourself;
      final friendship = await _db
          .collection('friendships')
          .doc(_pair(me.uid, owner.uid))
          .get();
      if (friendship.exists) return RequestResult.alreadyFriends;
      final theirs = await _db
          .collection('friendRequests')
          .doc('${owner.uid}_${me.uid}')
          .get();
      if (theirs.exists) return RequestResult.alreadyRequested;
      final mine = _db
          .collection('friendRequests')
          .doc('${me.uid}_${owner.uid}');
      if ((await mine.get()).exists) return RequestResult.alreadyRequested;
      await mine.set({
        'from': me.uid,
        'fromName': me.name,
        'to': owner.uid,
        'createdAt': FieldValue.serverTimestamp(),
      });
      return RequestResult.sent;
    } catch (e) {
      debugPrint('Friend request failed: $e');
      return RequestResult.failed;
    }
  }

  @override
  Future<List<FriendRequest>> incoming(String uid) async {
    final snap = await _db
        .collection('friendRequests')
        .where('to', isEqualTo: uid)
        .get();
    return [
      for (final doc in snap.docs)
        FriendRequest(
          from: doc.data()['from'] as String,
          fromName: (doc.data()['fromName'] as String?) ?? 'Someone',
          to: uid,
        ),
    ];
  }

  @override
  Future<void> accept({
    required AccountUser me,
    required FriendRequest request,
  }) async {
    await _db.collection('friendships').doc(_pair(request.from, me.uid)).set({
      'members': [request.from, me.uid],
      'createdAt': FieldValue.serverTimestamp(),
    });
    await _db
        .collection('friendRequests')
        .doc('${request.from}_${me.uid}')
        .delete();
  }

  @override
  Future<void> decline({
    required AccountUser me,
    required FriendRequest request,
  }) => _db
      .collection('friendRequests')
      .doc('${request.from}_${me.uid}')
      .delete();

  @override
  Future<List<PublicProfile>> friends(String uid) async {
    final snap = await _db
        .collection('friendships')
        .where('members', arrayContains: uid)
        .get();
    final profiles = <PublicProfile>[];
    for (final doc in snap.docs) {
      final members = List<String>.from(doc.data()['members'] as List);
      final other = members.firstWhere((id) => id != uid, orElse: () => '');
      if (other.isEmpty) continue;
      try {
        final profile = await _db.collection('users').doc(other).get();
        final data = profile.data();
        if (data != null) profiles.add(PublicProfile.fromJson(other, data));
      } catch (e) {
        debugPrint('Could not read a friend: $e');
      }
    }
    return profiles;
  }

  @override
  Future<void> removeFriend({required String uid, required String friendUid}) =>
      _db.collection('friendships').doc(_pair(uid, friendUid)).delete();

  @override
  Future<bool> sendNudge({
    required AccountUser me,
    required String toUid,
    required CalendarDate today,
  }) async {
    try {
      // The same id for the same day: a second wave is refused by the rules.
      await _db
          .collection('nudges')
          .doc('${me.uid}_${toUid}_${today.toIsoDate()}')
          .set({
            'from': me.uid,
            'fromName': me.name,
            'to': toUid,
            'on': today.toIsoDate(),
            'createdAt': FieldValue.serverTimestamp(),
          });
      return true;
    } catch (e) {
      debugPrint('Wave not sent: $e');
      return false;
    }
  }

  @override
  Future<List<Nudge>> nudges(String uid) async {
    final snap = await _db
        .collection('nudges')
        .where('to', isEqualTo: uid)
        .get();
    return [
      for (final doc in snap.docs)
        Nudge(
          id: doc.id,
          from: doc.data()['from'] as String,
          fromName: (doc.data()['fromName'] as String?) ?? 'A friend',
          to: uid,
          on: CalendarDate.parse(doc.data()['on'] as String),
        ),
    ];
  }

  @override
  Future<void> clearNudges(String uid) async {
    final snap = await _db
        .collection('nudges')
        .where('to', isEqualTo: uid)
        .get();
    for (final doc in snap.docs) {
      await doc.reference.delete();
    }
  }

  @override
  Future<void> deleteMine(String uid) async {
    final friendships = await _db
        .collection('friendships')
        .where('members', arrayContains: uid)
        .get();
    for (final doc in friendships.docs) {
      await doc.reference.delete();
    }
    for (final field in ['from', 'to']) {
      final requests = await _db
          .collection('friendRequests')
          .where(field, isEqualTo: uid)
          .get();
      for (final doc in requests.docs) {
        await doc.reference.delete();
      }
    }
    await clearNudges(uid);
    final mine = await _db.collection('users').doc(uid).get();
    final code = mine.data()?['friendCode'];
    if (code is String && code.isNotEmpty) {
      await _db.collection('friendCodes').doc(code).delete();
    }
    await _db.collection('users').doc(uid).delete();
  }
}
