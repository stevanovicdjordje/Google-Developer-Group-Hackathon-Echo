// The file picker's platform interface is a transitive dependency; it is the
// only seam to simulate "the user picked files".
// ignore_for_file: depend_on_referenced_packages
import 'dart:typed_data';

import 'package:cross_file/cross_file.dart';
import 'package:eho/data/app_state.dart';
import 'package:eho/data/demo_data.dart' as demo;
import 'package:eho/data/repositories.dart';
import 'package:eho/features/organizer/organizer_screens.dart';
import 'package:file_picker/file_picker.dart';
import 'package:file_picker_platform_interface/file_picker_platform_interface.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:qr_flutter/qr_flutter.dart';

import 'flow_helpers.dart';

/// A picked file with [size] bytes of content.
base class _PickedFile extends PlatformFile {
  _PickedFile(this.name, int size) : _bytes = Uint8List(size);

  @override
  final String name;
  final Uint8List _bytes;

  @override
  Uri get uri => Uri.parse('memory:///$name');
  @override
  XFile get xFile => XFile.fromData(_bytes, name: name);
  @override
  int? lengthSync() => _bytes.length;
  @override
  Future<int?> length() async => _bytes.length;
  @override
  Future<Uint8List> readAsBytes() async => _bytes;
  @override
  Stream<Uint8List> readAsByteStream() => Stream.value(_bytes);
}

/// Answers every "pick files" with an agenda PDF and a speakers sheet.
class _FakePicker extends FilePickerPlatform {
  @override
  Future<List<PlatformFile>> pickFiles({
    String? dialogTitle,
    String? initialDirectory,
    FileType type = FileType.any,
    List<String>? allowedExtensions,
    Function(FilePickerStatus)? onFileLoading,
    int compressionQuality = 0,
    AndroidOptions androidOptions = const AndroidOptions(),
    DarwinOptions darwinOptions = const DarwinOptions(),
    WindowsOptions windowsOptions = const WindowsOptions(),
    LinuxOptions linuxOptions = const LinuxOptions(),
    WebOptions webOptions = const WebOptions(),
  }) async => [
    _PickedFile('agenda.pdf', 2048),
    _PickedFile('speakers.csv', 900),
  ];
}

/// Flow 5: Profile → For organizers → Create event → upload → extraction →
/// review (flagged row, fix the stage) → publish → link + QR.
void main() {
  testWidgets('organizer: create event → upload → review → fix → publish', (
    tester,
  ) async {
    final original = FilePickerPlatform.instance;
    FilePickerPlatform.instance = _FakePicker();
    addTearDown(() => FilePickerPlatform.instance = original);

    final container = await startApp(tester);
    await openLink(tester, '/e/devfest');
    await joinAndOnboard(tester);
    await tapTab(tester, 'Profile');
    expect(locationOf(tester), '/e/devfest/profile');

    // Profile → For organizers → Create event.
    await tester.scrollUntilVisible(
      find.text('For organizers'),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.text('For organizers'));
    await tester.pumpAndSettle();
    expect(find.text('Create event'), findsOneWidget);
    expect(find.text('Edit venue map'), findsOneWidget);
    await tester.tap(find.text('Create event'));
    await tester.pumpAndSettle();
    expect(locationOf(tester), '/organizer');
    expect(find.text('Drop in whatever you have'), findsOneWidget);

    // Upload: nothing picked, the build button is disabled; then pick files.
    ButtonStyleButton buildButton() => tester.widget<ButtonStyleButton>(
      find.ancestor(
        of: find.text('Build my event with AI'),
        matching: find.bySubtype<ButtonStyleButton>(),
      ),
    );
    expect(buildButton().onPressed, isNull);
    await tester.tap(find.text('Choose files'));
    await tester.pumpAndSettle();
    expect(find.text('agenda.pdf'), findsOneWidget);
    expect(find.text('speakers.csv'), findsOneWidget);
    expect(buildButton().onPressed, isNotNull);

    // Extraction progress: reading, then what was found.
    await tester.tap(find.text('Build my event with AI'));
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.byType(LinearProgressIndicator), findsOneWidget);
    expect(
      find.text(
        'Reading your files and extracting stages, sessions and speakers…',
      ),
      findsOneWidget,
    );
    await tester.pump(const Duration(milliseconds: 2700));
    expect(
      find.textContaining('Found 3 stages, 5 sessions, 6 speakers'),
      findsOneWidget,
    );
    await tester.pump(const Duration(milliseconds: 800));
    await tester.pumpAndSettle();

    // Review: the extracted event, with one flagged row.
    expect(locationOf(tester), '/organizer/review');
    expect(find.text('Review your event'), findsOneWidget);
    expect(find.text('Extracted from 2 files'), findsOneWidget);
    expect(find.text(demo.demoEventName), findsOneWidget);
    expect(find.text('Designing for crowded rooms'), findsOneWidget);
    expect(
      find.textContaining('Check: room missing in the PDF'),
      findsOneWidget,
    );

    // Fix the stage in the edit sheet.
    await tester.tap(
      find.descendant(
        // The row is the nearest Row around the title.
        of: find
            .ancestor(
              of: find.text('Designing for crowded rooms'),
              matching: find.byType(Row),
            )
            .first,
        matching: find.byIcon(Icons.edit_outlined),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Edit session'), findsOneWidget);
    await tester.tap(find.byType(DropdownButtonFormField<String>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Sala B').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    expect(find.text('Edit session'), findsNothing);
    expect(find.textContaining('Check: room missing in the PDF'), findsNothing);
    expect(
      container
          .read(organizerDraftProvider)!
          .sessions
          .firstWhere((s) => s.id == demo.organizerFlaggedSessionId)
          .stage,
      'Sala B',
    );

    // Publish → link + QR + Copy.
    await tester.scrollUntilVisible(
      find.text('Publish & get join link'),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.text('Publish & get join link'));
    await tester.pump();
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    await tester.pump(const Duration(seconds: 2));
    await tester.pumpAndSettle();

    final link = '${linkBase()}/e/$demoEventId';
    expect(find.text('${demo.demoEventName} is live'), findsOneWidget);
    expect(find.text(displayJoinLink(link)), findsOneWidget);
    expect(find.byType(QrImageView), findsOneWidget);
    expect(find.text('Copy'), findsOneWidget);
    await tester.tap(find.text('Copy'));
    await tester.pumpAndSettle();
    expect(find.text('Link copied'), findsOneWidget);
  });
}
