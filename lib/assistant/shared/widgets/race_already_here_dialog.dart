import 'package:flutter/material.dart';
import 'package:xceleration/assistant/shared/services/received_race_resolver.dart';
import 'package:xceleration/core/components/dialog_utils.dart';

/// Asks the volunteer what to do with a race the coach sent that matches one
/// already on the phone. [what] names what is recorded: "bibs" or "times".
///
/// It cannot be dismissed by tapping outside: either choice keeps what was
/// recorded, but a stray tap should not pick one.
Future<ReceivedRaceChoice> askAboutRace(
  BuildContext context,
  RaceAlreadyHere here, {
  required String what,
}) async {
  final (:title, :content, :update, :keep) = raceAlreadyHereText(here, what);
  final choice = await showDialog<ReceivedRaceChoice>(
    context: context,
    barrierDismissible: false,
    builder: (context) => BasicAlertDialog(
      title: title,
      content: content,
      actions: [
        DialogButton(
          key: const ValueKey('race_keep_separate'),
          text: keep,
          onPressed: () =>
              Navigator.of(context).pop(ReceivedRaceChoice.keepSeparate),
        ),
        DialogButton(
          key: const ValueKey('race_update'),
          text: update,
          primary: true,
          onPressed: () => Navigator.of(context).pop(ReceivedRaceChoice.update),
        ),
      ],
    ),
  );
  return choice ?? ReceivedRaceChoice.update;
}

/// The dialog's words, apart so they can be checked without a screen.
({String title, String content, String update, String keep})
    raceAlreadyHereText(RaceAlreadyHere here, String what) {
  final old = here.existing, sent = here.sent;
  final recorded = here.recorded == 0
      ? ''
      : ', with ${here.recorded} ${here.recorded == 1 ? what.substring(0, what.length - 1) : what} recorded';
  final roster = here.rosterChanges?.describe();
  if (here.renamed) {
    return (
      title: 'Is this the same race?',
      content: 'The coach sent "${sent.name}" (${sent.formattedDate}). This '
          'phone already has "${old.name}" (${old.formattedDate}) under the '
          'same race number$recorded.\n\n'
          'If the coach renamed it, update it and keep your $what. If it is '
          'a different race, keep both.',
      update: 'Same race',
      keep: 'Keep both',
    );
  }
  return (
    title: 'Race already on this phone',
    content: '"${old.name}" is already here$recorded.\n\n'
        'Update it to keep your $what'
        '${roster == null ? '' : ' and use the coach\'s new roster ($roster)'}'
        ', or make a separate copy.',
    update: 'Update race',
    keep: 'Make a copy',
  );
}
