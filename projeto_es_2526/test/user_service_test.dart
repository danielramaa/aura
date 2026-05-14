import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:projeto_es_2526/models/user_role.dart';
import 'package:projeto_es_2526/services/user_service.dart';

void main() {
  group('UserService.getRole', () {
    test('returns user when document does not exist', () async {
      final firestore = FakeFirebaseFirestore();
      final service = UserService(firestore: firestore);

      expect(await service.getRole('uid1'), UserRole.user);
    });

    test('returns user when role field is absent', () async {
      final firestore = FakeFirebaseFirestore();
      await firestore.collection('users').doc('uid1').set({'displayName': 'Alice'});
      final service = UserService(firestore: firestore);

      expect(await service.getRole('uid1'), UserRole.user);
    });

    test('returns medic when role is "medic"', () async {
      final firestore = FakeFirebaseFirestore();
      await firestore.collection('users').doc('uid1').set({'role': 'medic'});
      final service = UserService(firestore: firestore);

      expect(await service.getRole('uid1'), UserRole.medic);
    });

    test('returns admin when role is "admin"', () async {
      final firestore = FakeFirebaseFirestore();
      await firestore.collection('users').doc('uid1').set({'role': 'admin'});
      final service = UserService(firestore: firestore);

      expect(await service.getRole('uid1'), UserRole.admin);
    });

    test('falls back to user for unknown role string', () async {
      final firestore = FakeFirebaseFirestore();
      await firestore.collection('users').doc('uid1').set({'role': 'superpower'});
      final service = UserService(firestore: firestore);

      expect(await service.getRole('uid1'), UserRole.user);
    });
  });

  group('UserService.streamRole', () {
    test('emits user when document does not exist', () async {
      final firestore = FakeFirebaseFirestore();
      final service = UserService(firestore: firestore);

      expect(await service.streamRole('uid1').first, UserRole.user);
    });

    test('emits updated role when Firestore document changes', () async {
      final firestore = FakeFirebaseFirestore();
      final service = UserService(firestore: firestore);

      final roles = <UserRole>[];
      final sub = service.streamRole('uid1').listen(roles.add);

      await firestore.collection('users').doc('uid1').set({'role': 'medic'});
      await Future.delayed(Duration.zero);
      await firestore.collection('users').doc('uid1').update({'role': 'admin'});
      await Future.delayed(Duration.zero);

      await sub.cancel();

      expect(roles, contains(UserRole.medic));
      expect(roles, contains(UserRole.admin));
    });
  });
}
