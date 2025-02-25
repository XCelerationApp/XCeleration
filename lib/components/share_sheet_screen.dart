import 'package:flutter/material.dart';
import '../utils/app_colors.dart';
import '../utils/typography.dart';
import '../utils/flow_components.dart';

class ShareSheetScreen extends StatelessWidget {
  final List<Map<String, dynamic>> teamResults;
  final List<Map<String, dynamic>> individualResults;

  const ShareSheetScreen({
    Key? key,
    required this.teamResults,
    required this.individualResults,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        children: [
          SearchableButton(
            label: 'Share via QR Code',
            icon: Icons.qr_code,
            onTap: () {
              // TODO: Implement QR code sharing
            },
          ),
          const SizedBox(height: 16),
          const Center(child: Text('or')),
          const SizedBox(height: 16),
          SearchableButton(
            label: 'Share via Bluetooth',
            icon: Icons.bluetooth,
            onTap: () {
              // TODO: Implement Bluetooth sharing
            },
          ),
          const Spacer(),
          FlowActionButton(
            label: 'Done',
            onPressed: () {
              Navigator.of(context).pop();
            },
          ),
        ],
      ),
    );
  }
}
