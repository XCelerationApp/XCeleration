import 'dart:io';
import 'package:flutter/material.dart';
import 'package:xceleration/core/components/textfield_utils.dart';
import '../../../core/theme/app_colors.dart';
import '../controller/races_controller.dart';

class RaceLocationField extends StatefulWidget {
  final RacesController controller;

  const RaceLocationField({required this.controller, super.key});

  @override
  State<RaceLocationField> createState() => _RaceLocationFieldState();
}

class _RaceLocationFieldState extends State<RaceLocationField> {
  late final Listenable _listenable;

  @override
  void initState() {
    super.initState();
    _listenable = Listenable.merge([
      widget.controller.locationErrorNotifier,
      widget.controller.locationButtonVisibleNotifier,
    ]);
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _listenable,
      builder: (context, _) => buildInputRow(
        label: 'Location',
        inputWidget: Row(
          children: [
            Expanded(
              flex: 2,
              child: buildTextField(
                context: context,
                controller: widget.controller.locationController,
                hint: (Platform.isIOS || Platform.isAndroid)
                    ? 'Other location'
                    : 'Enter race location',
                error: widget.controller.locationError,
                onChanged: (_) => widget.controller
                    .validateLocation(widget.controller.locationController.text),
                keyboardType: TextInputType.text,
              ),
            ),
            if (widget.controller.isLocationButtonVisible &&
                (Platform.isIOS || Platform.isAndroid)) ...[
              const SizedBox(width: 12),
              Expanded(
                flex: 1,
                child: IconButton(
                  icon: const Icon(Icons.my_location,
                      color: AppColors.primaryColor),
                  onPressed: () => widget.controller.getCurrentLocation(context),
                ),
              ),
            ]
          ],
        ),
      ),
    );
  }
}
