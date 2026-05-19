import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:high_school/domain/entities/user_entity.dart';
import 'package:high_school/presentation/providers/auth_provider.dart';
import 'package:high_school/presentation/providers/language_provider.dart';

class OtpVerifyScreen extends StatefulWidget {
  const OtpVerifyScreen({super.key, required this.phone});

  final String phone;

  @override
  State<OtpVerifyScreen> createState() => _OtpVerifyScreenState();
}

class _OtpVerifyScreenState extends State<OtpVerifyScreen> {
  final _otpController = TextEditingController();
  bool _loading = false;
  String? _error;

  @override
  void dispose() {
    _otpController.dispose();
    super.dispose();
  }

  Future<void> _verify() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    final auth = context.read<AuthProvider>();
    final otp = _otpController.text.trim();
    if (otp.length != 4) {
      setState(() {
        _loading = false;
        _error = 'OTP must be exactly 4 digits';
      });
      return;
    }
    final ok = await auth.verifyOtp(widget.phone, otp);
    if (!mounted) return;
    setState(() {
      _loading = false;
      _error = ok ? null : (auth.lastAuthError ?? 'Invalid OTP');
    });
    if (!ok) return;

    final user = auth.user;
    if (user == null) {
      context.go('/login');
      return;
    }
    if (user.role == UserRole.teacher) {
      context.go('/teacher/dashboard');
    } else {
      context.go('/student/dashboard');
    }
  }

  @override
  Widget build(BuildContext context) {
    final lang = context.watch<LanguageProvider>();

    return Scaffold(
      appBar: AppBar(title: Text(lang.t('auth.enterOtpTitle'))),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                lang.t('auth.enterOtpIntro'),
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: 8),
              Text(
                widget.phone,
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 24),
              TextField(
                controller: _otpController,
                maxLength: 4,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText: lang.t('auth.otpFieldLabel'),
                  border: const OutlineInputBorder(),
                ),
              ),
              if (_error != null) ...[
                const SizedBox(height: 8),
                Text(
                  lang.localizeAuthMessage(_error!),
                  style: const TextStyle(color: Colors.red),
                ),
              ],
              const Spacer(),
              ElevatedButton(
                onPressed: _loading ? null : _verify,
                child: _loading
                    ? const SizedBox(
                        height: 24,
                        width: 24,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Text(lang.t('auth.verifyOtpButton')),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

