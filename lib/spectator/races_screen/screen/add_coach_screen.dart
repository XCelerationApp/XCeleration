import 'package:flutter/material.dart';
import 'package:xceleration/core/services/parent_link_service.dart';
import 'package:xceleration/core/theme/app_colors.dart';
import 'package:xceleration/core/theme/typography.dart';

class AddCoachScreen extends StatefulWidget {
  const AddCoachScreen({super.key});

  @override
  State<AddCoachScreen> createState() => _AddCoachScreenState();
}

class _AddCoachScreenState extends State<AddCoachScreen> {
  final _emailController = TextEditingController();
  bool _busy = false;
  String? _message;

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _link() async {
    setState(() {
      _busy = true;
      _message = null;
    });
    final email = _emailController.text.trim();
    if (email.isEmpty) {
      setState(() {
        _busy = false;
        _message = 'Enter coach email';
      });
      return;
    }
    final ok = await ParentLinkService.instance.linkCoachByEmail(email);
    if (!mounted) return;
    setState(() {
      _busy = false;
      _message = ok ? 'Coach linked' : 'Coach not found';
    });
    if (ok) Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: AppColors.primaryColor,
        foregroundColor: Colors.white,
        leading: const BackButton(),
        title: const Text('Add Coach'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Coach email', style: AppTypography.titleSemibold),
            const SizedBox(height: 12),
            TextFormField(
              controller: _emailController,
              autofocus: true,
              decoration: const InputDecoration(
                hintText: 'name@example.com',
                border: OutlineInputBorder(),
                filled: true,
              ),
              keyboardType: TextInputType.emailAddress,
              textInputAction: TextInputAction.done,
              onFieldSubmitted: (_) => _busy ? null : _link(),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: _busy ? null : _link,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primaryColor,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: const StadiumBorder(),
              ),
              child: _busy
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    )
                  : const Text('Link Coach'),
            ),
            if (_message != null) ...[
              const SizedBox(height: 12),
              Text(_message!, textAlign: TextAlign.center),
            ]
          ],
        ),
      ),
    );
  }
}
