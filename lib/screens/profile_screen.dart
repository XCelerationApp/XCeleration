import 'package:flutter/material.dart';
import '../utils/app_colors.dart';
import '../utils/dialog_utils.dart';
// import '../database_helper.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  _ProfileScreenState createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  List<String> profiles = ['Coach', 'Assistant'];
  String selectedProfile = 'Coach';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Profile'),
        backgroundColor: AppColors.primaryColor,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Select Profile:',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 16),
            DropdownButton<String>(
              value: selectedProfile,
              isExpanded: true,
              onChanged: (String? newValue) {
                if (newValue != null) {
                  setState(() {
                    selectedProfile = newValue;
                  });
                  _saveProfile(newValue);
                }
              },
              items: profiles.map<DropdownMenuItem<String>>((String value) {
                return DropdownMenuItem<String>(
                  value: value,
                  child: Text(value),
                );
              }).toList(),
            ),
          ],
        ),
      ),
    );
  }

  void _saveProfile(String profile) async {
    try {
      // await DatabaseHelper.instance.saveUserProfile(profile);
      DialogUtils.showSuccessDialog(
        context,
        message: 'Your profile has been updated to $profile.',
        title: 'Profile Updated',
      );
    } catch (e) {
      DialogUtils.showErrorDialog(context, message: 'Failed to update profile: $e');
    }
  }
}
