import 'package:flutter_test/flutter_test.dart';
import 'package:hamsafar/models/location.dart';

void main() {
  test('towns and border settlements are valid route endpoints', () {
    final besharyk = LocationDirectory.cityNamed('Бешарык');
    expect(besharyk.country.name, 'Узбекистан');
    expect(besharyk.city.name, 'Бешарык');

    final oybek = LocationDirectory.cityNamed('Ойбек');
    expect(oybek.country.name, 'Узбекистан');
    expect(oybek.city.name, 'Ойбек');

    final shahritus = LocationDirectory.cityNamed('Шахритус');
    expect(shahritus.country.name, 'Таджикистан');
    expect(shahritus.city.name, 'Шахритус');
  });
}
