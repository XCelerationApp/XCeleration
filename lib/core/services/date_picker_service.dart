import 'package:flutter/material.dart';

abstract interface class IDatePickerService {
  Future<DateTime?> pickDate(BuildContext context);
}

class DatePickerService implements IDatePickerService {
  @override
  Future<DateTime?> pickDate(BuildContext context) {
    return showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime(2101),
    );
  }
}
