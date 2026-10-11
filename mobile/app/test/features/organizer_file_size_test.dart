import 'package:eho/features/organizer/organizer_screens.dart';
import 'package:eho/l10n/app_localizations_en.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final l10n = AppLocalizationsEn();
  String size(int bytes) => fileSizeLabel(l10n, bytes);

  test('small files show one decimal, never 0 KB', () {
    expect(size(410), '0.4 KB');
    expect(size(1126), '1.1 KB');
    expect(size(10138), '9.9 KB');
    expect(size(1), '0.1 KB');
  });

  test('10 KB and more show whole KB, a megabyte and more shows MB', () {
    expect(size(10240), '10 KB');
    expect(size(10235), '10 KB'); // 9.995 KB does not show as "10.0 KB"
    expect(size(12 * 1024), '12 KB');
    expect(size(412 * 1024), '412 KB');
    expect(size(1024 * 1024 - 1), '1.0 MB');
    expect(size((2.3 * 1024 * 1024).round()), '2.3 MB');
  });
}
