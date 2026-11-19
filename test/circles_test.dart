import 'package:flutter_test/flutter_test.dart';
import 'package:zero_trust_core/zero_trust_core.dart';
import 'package:zerotrust_family/data/family_data.dart';
import 'package:zerotrust_family/model/circle.dart';

import 'support/phone.dart';

void main() {
  late InMemorySpaceServer server;
  late Phone a, b, c;

  setUp(() async {
    server = InMemorySpaceServer();
    a = await Phone(server, mum, 1).start();
    b = await Phone(server, dad, 2).start();
    c = await Phone(server, teen, 3).start();
  });

  /// Mum invites [who]; both see the same code before she lets them in.
  Future<void> invite(String spaceId, Phone who, {required String name}) async {
    final link = await a.spaces.invite(spaceId);
    expect(link.toString(), startsWith('https://zerotrust.bz/join/family#'));
    final started = await who.spaces.answer(
      SpaceInviteLink.parse(link.toString()),
      myName: name,
    );
    expect(started.spaceId, spaceId);
    final pending = await a.spaces.pendingJoins(spaceId);
    expect(pending.single.verificationCode, started.verificationCode);
    expect(pending.single.name, name);
    await a.spaces.confirm(pending.single);
  }

  test('a new circle has its name and its creator as the only owner', () async {
    final id = await a.createCircle('Sagron family', myName: 'Mum');
    final circle = await a.circle(id);
    expect(circle.name, 'Sagron family');
    expect(circle.isAdmin, isTrue);
    expect(circle.members.single.userId, mum);
    expect(circle.members.single.name, 'Mum');
    expect(circle.members.single.role, SpaceRole.admin);
  });

  test('someone who joins sees the name and everyone in the circle', () async {
    final id = await a.createCircle('Home', myName: 'Mum');
    // Not a member yet: the circle isn't in Dad's list.
    expect(await b.spaces.list(), isEmpty);
    await invite(id, b, name: 'Dad');
    await invite(id, c, name: 'Noa');

    final seen = await c.circle(id);
    expect(seen.name, 'Home');
    expect(seen.isAdmin, isFalse);
    // The owner first, then by name.
    expect(seen.members.map((m) => m.name), ['Mum', 'Dad', 'Noa']);
    expect(seen.members.first.role, SpaceRole.admin);

    // The owner's phone lists them too.
    expect((await a.circle(id)).members, hasLength(3));
  });

  test('only an owner can rename the circle', () async {
    final id = await a.createCircle('Home', myName: 'Mum');
    await invite(id, b, name: 'Dad');

    // Dad's rename is refused and never reaches the others.
    final dads = await b.spaces.open(id);
    await b.spaces.sync(dads);
    await dads.save(Circle.itemId, const Circle(name: 'Dad rules').toJson());
    try {
      await b.spaces.sync(dads);
    } on Object {
      // Refused by the server, or dropped by the engine: either is fine.
    }
    expect((await a.circle(id)).name, 'Home');
    expect((await c.spaces.list()), isEmpty);

    final mums = await a.spaces.open(id);
    await mums.save(Circle.itemId, const Circle(name: 'Our home').toJson());
    await a.spaces.sync(mums);
    expect((await a.circle(id)).name, 'Our home');
  });

  test(
    'someone who leaves is gone from the circle, and it from them',
    () async {
      final id = await a.createCircle('Home', myName: 'Mum');
      await invite(id, b, name: 'Dad');
      await invite(id, c, name: 'Noa');
      await c.circle(id);

      await c.spaces.leave(id);
      expect(await c.spaces.list(), isEmpty);
      expect(c.stores.containsKey(id), isFalse);

      final after = await a.circle(id);
      expect(after.members.map((m) => m.name), ['Mum', 'Dad']);
    },
  );

  test('a removed member can no longer open the circle', () async {
    final id = await a.createCircle('Home', myName: 'Mum');
    await invite(id, b, name: 'Dad');
    await b.circle(id);

    await a.spaces.remove(id, dad);
    expect(await b.spaces.list(), isEmpty);
    expect((await a.circle(id)).members.single.name, 'Mum');
  });

  test('a member cannot write in another member\'s name', () async {
    final id = await a.createCircle('Home', myName: 'Mum');
    await invite(id, b, name: 'Dad');
    final dads = await b.spaces.open(id);
    await b.spaces.sync(dads);
    expect(
      () => dads.save('family.me/$mum', {'kind': 'family.me'}),
      throwsArgumentError,
    );
    // Their own is fine.
    await dads.save('family.me/$dad', {'kind': 'family.me'});
  });

  test('circle names are trimmed, single-spaced and capped', () {
    expect(Circle.cleanName('  The   Sagrons  '), 'The Sagrons');
    expect(Circle.cleanName('   '), isNull);
    expect(Circle.cleanName('x' * 80), hasLength(Circle.maxNameLength));
  });

  test('members sort owners first, then by name, whatever the case', () async {
    final id = await a.createCircle('Home', myName: 'zoe');
    await invite(id, b, name: 'adam');
    await invite(id, c, name: 'Ben');
    final names = sortMembers(
      (await a.circle(id)).members.reversed,
    ).map((m) => m.name);
    expect(names, ['zoe', 'adam', 'Ben']);
  });

  test('waiting joins read back only what was saved as such', () {
    expect(PendingJoins.read(null), isEmpty);
    expect(
      PendingJoins.read({
        'kind': 'other',
        'spaces': ['a'],
      }),
      isEmpty,
    );
    expect(PendingJoins.read(PendingJoins.toJson(['a', 'b'])), ['a', 'b']);
    expect(
      PendingJoins.read({
        'kind': PendingJoins.kind,
        'spaces': ['a', 3, null],
      }),
      ['a'],
    );
  });
}
