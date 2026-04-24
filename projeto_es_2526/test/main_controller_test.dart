import 'package:flutter_test/flutter_test.dart';
import 'package:projeto_es_2526/controllers/main_controller.dart';

void main() {
  group('MainController', () {
    test('starts on index 0', () {
      final controller = MainController();
      addTearDown(controller.dispose);
      expect(controller.currentIndex, 0);
    });

    test('navigateTo updates the current index', () {
      final controller = MainController();
      addTearDown(controller.dispose);
      controller.navigateTo(2);
      expect(controller.currentIndex, 2);
    });

    test('navigateTo notifies listeners on change', () {
      final controller = MainController();
      addTearDown(controller.dispose);
      var notifyCount = 0;
      controller.addListener(() => notifyCount++);

      controller.navigateTo(1);
      controller.navigateTo(3);

      expect(notifyCount, 2);
    });

    test('navigateTo is a no-op when the index is unchanged', () {
      final controller = MainController();
      addTearDown(controller.dispose);
      controller.navigateTo(2);
      var notifyCount = 0;
      controller.addListener(() => notifyCount++);

      controller.navigateTo(2);
      expect(notifyCount, 0);
      expect(controller.currentIndex, 2);
    });
  });
}
