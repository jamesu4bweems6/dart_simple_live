import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';
import 'package:simple_live_app/widgets/native_ios/native_control.dart';

Future<TimeOfDay?> showNativeTimePicker(
    {required BuildContext context,
    required TimeOfDay initialTime,
    TimePickerEntryMode initialEntryMode = TimePickerEntryMode.dial,
    TransitionBuilder? builder}) async {
  if (!usesNativeIOS)
    return showTimePicker(
        context: context, initialTime: initialTime, initialEntryMode: initialEntryMode, builder: builder);
  final result =
      await const MethodChannel('simple_live/native_presentations').invokeMapMethod<String, dynamic>('pickTime', {
    'id': 0,
    'hour': initialTime.hour,
    'minute': initialTime.minute,
    'dark': Theme.of(context).brightness == Brightness.dark,
  });
  if (result == null) return null;
  return TimeOfDay(hour: result['hour'] as int, minute: result['minute'] as int);
}
