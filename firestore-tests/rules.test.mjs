// Run with: firebase emulators:exec --only firestore --project demo-catwalk "npm test --prefix firestore-tests"
import { initializeTestEnvironment, assertFails, assertSucceeds } from '@firebase/rules-unit-testing';
import { doc, getDoc, setDoc, deleteDoc, getDocs, collection, query, where } from 'firebase/firestore';
import { readFileSync } from 'node:fs';
import { test, before, after, beforeEach } from 'node:test';

let env;
before(async () => {
  env = await initializeTestEnvironment({
    projectId: 'demo-catwalk',
    firestore: { rules: readFileSync('../firestore.rules', 'utf8'), host: '127.0.0.1', port: 8080 },
  });
});
after(() => env.cleanup());
beforeEach(() => env.clearFirestore());

const google = (uid) => env.authenticatedContext(uid, { firebase: { sign_in_provider: 'google.com' } }).firestore();
const anon = (uid) => env.authenticatedContext(uid, { firebase: { sign_in_provider: 'anonymous' } }).firestore();
const profile = (extra = {}) => ({
  displayName: 'Mara', friendCode: 'ABCDEF', streak: 1, bestStreak: 2, totalSteps: 3, weekSteps: 4,
  todaySteps: 5, todayGoalMet: false, dailyGoal: 6000, cats: [], toys: [], rooms: 1, ...extra,
});
const befriend = (a, b) => env.withSecurityRulesDisabled((ctx) =>
  setDoc(doc(ctx.firestore(), 'friendships', a < b ? `${a}_${b}` : `${b}_${a}`), { members: [a, b] }));

test('you can write your own profile, not someone else\'s', async () => {
  await assertSucceeds(setDoc(doc(google('a'), 'users', 'a'), profile()));
  await assertFails(setDoc(doc(google('a'), 'users', 'b'), profile()));
});

test('anonymous accounts cannot write a profile', async () => {
  await assertFails(setDoc(doc(anon('a'), 'users', 'a'), profile()));
});

test('a profile with extra fields, a long name or a bad code is refused', async () => {
  const db = google('a');
  await assertFails(setDoc(doc(db, 'users', 'a'), profile({ lat: 52.1 })));
  await assertFails(setDoc(doc(db, 'users', 'a'), profile({ displayName: 'x'.repeat(41) })));
  await assertFails(setDoc(doc(db, 'users', 'a'), profile({ friendCode: 'AB' })));
  await assertFails(setDoc(doc(db, 'users', 'a'), profile({ cats: new Array(13).fill({}) })));
});

test('rooms must be a whole number from 1 to 4, and the old beds key is gone', async () => {
  const db = google('a');
  for (const rooms of [1, 2, 3, 4]) {
    await assertSucceeds(setDoc(doc(db, 'users', 'a'), profile({ rooms })));
  }
  for (const rooms of [0, 5, -1, 2.5, '2']) {
    await assertFails(setDoc(doc(db, 'users', 'a'), profile({ rooms })));
  }
  await assertFails(setDoc(doc(db, 'users', 'a'), profile({ beds: 2 })));
});

test('only the owner and friends can read a profile', async () => {
  await env.withSecurityRulesDisabled((ctx) => setDoc(doc(ctx.firestore(), 'users', 'a'), profile()));
  await assertSucceeds(getDoc(doc(google('a'), 'users', 'a')));
  await assertFails(getDoc(doc(google('b'), 'users', 'a')));
  await befriend('a', 'b');
  await assertSucceeds(getDoc(doc(google('b'), 'users', 'a')));
  await assertFails(getDoc(doc(google('c'), 'users', 'a')));
});

test('a friend code can be looked up by a real user, claimed only by its owner', async () => {
  await assertSucceeds(setDoc(doc(google('a'), 'friendCodes', 'ABCDEF'), { uid: 'a', displayName: 'Mara' }));
  await assertFails(setDoc(doc(google('b'), 'friendCodes', 'ABCDEF'), { uid: 'b', displayName: 'Noor' }));
  await assertFails(setDoc(doc(google('b'), 'friendCodes', 'GHJKMN'), { uid: 'a', displayName: 'Noor' }));
  await assertSucceeds(getDoc(doc(google('b'), 'friendCodes', 'ABCDEF')));
  await assertFails(getDoc(doc(anon('c'), 'friendCodes', 'ABCDEF')));
  await assertFails(deleteDoc(doc(google('b'), 'friendCodes', 'ABCDEF')));
  await assertSucceeds(deleteDoc(doc(google('a'), 'friendCodes', 'ABCDEF')));
});

test('a friend request can be sent as yourself, to someone else, and be read by both', async () => {
  const req = { from: 'a', fromName: 'Mara', to: 'b', createdAt: new Date() };
  await assertSucceeds(setDoc(doc(google('a'), 'friendRequests', 'a_b'), req));
  await assertFails(setDoc(doc(google('c'), 'friendRequests', 'a_c'), req));
  await assertFails(setDoc(doc(google('a'), 'friendRequests', 'a_a'), { ...req, to: 'a' }));
  await assertSucceeds(getDoc(doc(google('b'), 'friendRequests', 'a_b')));
  await assertFails(getDoc(doc(google('c'), 'friendRequests', 'a_b')));
  await assertSucceeds(getDocs(query(collection(google('b'), 'friendRequests'), where('to', '==', 'b'))));
  await assertFails(getDocs(query(collection(google('c'), 'friendRequests'), where('to', '==', 'b'))));
});

test('reading a request that does not exist is allowed for its two people only', async () => {
  await assertSucceeds(getDoc(doc(google('a'), 'friendRequests', 'b_a')));
  await assertFails(getDoc(doc(google('c'), 'friendRequests', 'b_a')));
});

test('a friendship can only be created by the person who was asked', async () => {
  await env.withSecurityRulesDisabled((ctx) => setDoc(doc(ctx.firestore(), 'friendRequests', 'a_b'),
    { from: 'a', fromName: 'Mara', to: 'b' }));
  await assertFails(setDoc(doc(google('a'), 'friendships', 'a_b'), { members: ['a', 'b'] }));
  await assertSucceeds(setDoc(doc(google('b'), 'friendships', 'a_b'), { members: ['a', 'b'], createdAt: new Date() }));
});

test('nobody can add themselves to a friendship without a request', async () => {
  await assertFails(setDoc(doc(google('b'), 'friendships', 'a_b'), { members: ['a', 'b'] }));
});

test('a friendship id must be the sorted pair', async () => {
  await env.withSecurityRulesDisabled((ctx) => setDoc(doc(ctx.firestore(), 'friendRequests', 'a_b'),
    { from: 'a', fromName: 'Mara', to: 'b' }));
  await assertFails(setDoc(doc(google('b'), 'friendships', 'x_y'), { members: ['a', 'b'] }));
});

test('friendships can be listed and ended by members only', async () => {
  await befriend('a', 'b');
  await assertSucceeds(getDocs(query(collection(google('a'), 'friendships'), where('members', 'array-contains', 'a'))));
  await assertFails(getDocs(query(collection(google('c'), 'friendships'), where('members', 'array-contains', 'a'))));
  await assertSucceeds(getDoc(doc(google('a'), 'friendships', 'a_b')));
  await assertFails(deleteDoc(doc(google('c'), 'friendships', 'a_b')));
  await assertSucceeds(deleteDoc(doc(google('b'), 'friendships', 'a_b')));
});

test('a wave goes to a friend only, once a day, and is read by the receiver only', async () => {
  const wave = { from: 'a', fromName: 'Mara', to: 'b', on: '2026-10-26', createdAt: new Date() };
  await assertFails(setDoc(doc(google('a'), 'nudges', 'a_b_2026-10-26'), wave));
  await befriend('a', 'b');
  await assertSucceeds(setDoc(doc(google('a'), 'nudges', 'a_b_2026-10-26'), wave));
  await assertFails(setDoc(doc(google('a'), 'nudges', 'a_b_2026-10-26'), wave));
  await assertFails(setDoc(doc(google('c'), 'nudges', 'a_b_x'), wave));
  await assertSucceeds(getDocs(query(collection(google('b'), 'nudges'), where('to', '==', 'b'))));
  await assertFails(getDocs(query(collection(google('c'), 'nudges'), where('to', '==', 'b'))));
  await assertSucceeds(deleteDoc(doc(google('b'), 'nudges', 'a_b_2026-10-26')));
});

test('everything else is closed', async () => {
  await assertFails(setDoc(doc(google('a'), 'anything', 'x'), { a: 1 }));
  await assertFails(getDoc(doc(google('a'), 'anything', 'x')));
});
