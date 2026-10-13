import 'package:flutter/material.dart';

import '../app_controller.dart';
import '../data/repository.dart';
import '../theme.dart';
import '../widgets/common.dart';

class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  final _form = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _signUp = false;
  bool _busy = false;
  bool _showPassword = false;
  String? _error;

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_form.currentState!.validate()) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    final auth = AppScope.read(context).auth;
    try {
      if (_signUp) {
        await auth.signUp(_name.text, _email.text, _password.text);
      } else {
        await auth.signIn(_email.text, _password.text);
      }
    } on AuthFailure catch (e) {
      if (mounted) setState(() => _error = e.message);
    } catch (e) {
      if (mounted) setState(() => _error = 'Something went wrong. Please try again.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _google() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await AppScope.read(context).auth.signInWithGoogle();
    } on AuthFailure catch (e) {
      // Closing the Google window isn't an error worth shouting about.
      if (mounted && !e.message.contains('cancelled')) {
        setState(() => _error = e.message);
      }
    } catch (_) {
      if (mounted) setState(() => _error = 'Google sign-in failed. Please try again.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _forgotPassword() async {
    final controller = TextEditingController(text: _email.text);
    final email = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Reset your password'),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          const Text("We'll email you a link to set a new password."),
          const SizedBox(height: 16),
          TextField(
            controller: controller,
            autofocus: true,
            keyboardType: TextInputType.emailAddress,
            decoration: const InputDecoration(labelText: 'Email'),
            onSubmitted: (v) => Navigator.pop(context, v),
          ),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          FilledButton(
              onPressed: () => Navigator.pop(context, controller.text),
              child: const Text('Send link')),
        ],
      ),
    );
    if (email == null || email.trim().isEmpty || !mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    try {
      await AppScope.read(context).auth.sendPasswordReset(email);
      messenger.showSnackBar(
          SnackBar(content: Text('Reset link sent to ${email.trim()}')));
    } on AuthFailure catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(e.message)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final wide = MediaQuery.sizeOf(context).width >= 900;
    final form = _buildForm(context);
    return Scaffold(
      body: SafeArea(
        child: wide
            ? Row(children: [
                const Expanded(child: _HeroPanel()),
                Expanded(child: Center(child: form)),
              ])
            : Center(child: form),
      ),
    );
  }

  Widget _buildForm(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 400),
        child: Form(
          key: _form,
          child: AutofillGroup(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Align(alignment: Alignment.centerLeft, child: AppLogo(size: 48)),
                const SizedBox(height: 28),
                Text(_signUp ? 'Create your account' : 'Welcome back',
                    style: theme.textTheme.headlineMedium),
                const SizedBox(height: 6),
                Text(
                  _signUp
                      ? 'Plan tasks step by step and see where everything stands.'
                      : 'Sign in to pick up where you left off.',
                  style: theme.textTheme.bodyLarge?.copyWith(color: scheme.muted),
                ),
                const SizedBox(height: 28),
                OutlinedButton(
                  onPressed: _busy ? null : _google,
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size(0, 52),
                    backgroundColor: theme.inputDecorationTheme.fillColor,
                    foregroundColor: scheme.onSurface,
                  ),
                  child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                    const GoogleLogo(size: 20),
                    const SizedBox(width: 12),
                    Text('Continue with Google', style: theme.textTheme.labelLarge),
                  ]),
                ),
                const SizedBox(height: 20),
                Row(children: [
                  const Expanded(child: Divider()),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: Text(_signUp ? 'or sign up with email' : 'or use email',
                        style: theme.textTheme.labelMedium?.copyWith(color: scheme.muted)),
                  ),
                  const Expanded(child: Divider()),
                ]),
                const SizedBox(height: 20),
                AnimatedSize(
                  duration: const Duration(milliseconds: 200),
                  child: _signUp
                      ? Padding(
                          padding: const EdgeInsets.only(bottom: 14),
                          child: TextFormField(
                            controller: _name,
                            textInputAction: TextInputAction.next,
                            textCapitalization: TextCapitalization.words,
                            autofillHints: const [AutofillHints.name],
                            decoration: const InputDecoration(
                              labelText: 'Your name',
                              prefixIcon: Icon(Icons.person_outline_rounded),
                            ),
                            validator: (v) => _signUp && (v == null || v.trim().isEmpty)
                                ? 'Tell us what to call you'
                                : null,
                          ),
                        )
                      : const SizedBox(width: double.infinity),
                ),
                TextFormField(
                  controller: _email,
                  keyboardType: TextInputType.emailAddress,
                  textInputAction: TextInputAction.next,
                  autofillHints: const [AutofillHints.email],
                  decoration: const InputDecoration(
                    labelText: 'Email',
                    prefixIcon: Icon(Icons.alternate_email_rounded),
                  ),
                  validator: (v) {
                    final s = v?.trim() ?? '';
                    if (s.isEmpty) return 'Enter your email';
                    if (!RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(s)) {
                      return "That email doesn't look right";
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 14),
                TextFormField(
                  controller: _password,
                  obscureText: !_showPassword,
                  textInputAction: TextInputAction.done,
                  autofillHints: [
                    _signUp ? AutofillHints.newPassword : AutofillHints.password
                  ],
                  onFieldSubmitted: (_) => _submit(),
                  decoration: InputDecoration(
                    labelText: 'Password',
                    prefixIcon: const Icon(Icons.lock_outline_rounded),
                    suffixIcon: IconButton(
                      tooltip: _showPassword ? 'Hide password' : 'Show password',
                      icon: Icon(_showPassword
                          ? Icons.visibility_off_outlined
                          : Icons.visibility_outlined),
                      onPressed: () => setState(() => _showPassword = !_showPassword),
                    ),
                  ),
                  validator: (v) {
                    if (v == null || v.isEmpty) return 'Enter your password';
                    if (_signUp && v.length < 6) return 'Use at least 6 characters';
                    return null;
                  },
                ),
                if (!_signUp)
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton(
                      onPressed: _busy ? null : _forgotPassword,
                      child: const Text('Forgot password?'),
                    ),
                  )
                else
                  const SizedBox(height: 16),
                if (_error != null) ...[
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: scheme.danger.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(children: [
                      Icon(Icons.error_outline_rounded, color: scheme.danger, size: 20),
                      const SizedBox(width: 10),
                      Expanded(
                          child: Text(_error!,
                              style: TextStyle(color: scheme.danger))),
                    ]),
                  ),
                  const SizedBox(height: 14),
                ],
                FilledButton(
                  onPressed: _busy ? null : _submit,
                  child: _busy
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2.4))
                      : Text(_signUp ? 'Create account' : 'Sign in'),
                ),
                const SizedBox(height: 20),
                Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                  Text(_signUp ? 'Already have an account?' : 'New here?',
                      style: TextStyle(color: scheme.muted)),
                  TextButton(
                    onPressed: _busy
                        ? null
                        : () => setState(() {
                              _signUp = !_signUp;
                              _error = null;
                            }),
                    child: Text(_signUp ? 'Sign in' : 'Create an account'),
                  ),
                ]),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _HeroPanel extends StatelessWidget {
  const _HeroPanel();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    const on = Colors.white;
    Widget point(IconData icon, String title, String body) => Padding(
          padding: const EdgeInsets.only(bottom: 22),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: on.withValues(alpha: 0.14),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: on, size: 20),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(title,
                    style: theme.textTheme.titleSmall
                        ?.copyWith(color: on, fontWeight: FontWeight.w700)),
                const SizedBox(height: 2),
                Text(body,
                    style: theme.textTheme.bodyMedium
                        ?.copyWith(color: on.withValues(alpha: 0.8))),
              ]),
            ),
          ]),
        );

    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(48),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF0563C9), Color(0xFF019BF0)],
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
              ),
              child: const AppLogo(size: 30),
            ),
            const SizedBox(width: 10),
            Text('Task Tracker',
                style: theme.textTheme.titleLarge?.copyWith(color: on)),
          ]),
          const Spacer(),
          Text('Break big work into steps.\nKnow exactly where it stands.',
              style: theme.textTheme.headlineMedium
                  ?.copyWith(color: on, height: 1.2)),
          const SizedBox(height: 36),
          point(Icons.linear_scale_rounded, 'Step-by-step tasks',
              'Track the current step, add notes, and watch progress fill up.'),
          point(Icons.sync_rounded, 'Live sync, works offline',
              'Changes show up on every device instantly and queue up when you are offline.'),
          point(Icons.event_available_rounded, 'Due dates & priorities',
              'Overdue work floats to the top so nothing slips.'),
          const Spacer(),
        ],
      ),
    );
  }
}


/// Google's four-colour "G", drawn so no image asset is needed.
class GoogleLogo extends StatelessWidget {
  const GoogleLogo({super.key, this.size = 20});
  final double size;

  @override
  Widget build(BuildContext context) =>
      CustomPaint(size: Size.square(size), painter: _GooglePainter());
}

class _GooglePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final s = size.width;
    final stroke = s * 0.2;
    final rect = Rect.fromCircle(
        center: Offset(s / 2, s / 2), radius: (s - stroke) / 2);
    Paint arc(Color c) => Paint()
      ..color = c
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke;
    const deg = 3.14159265 / 180;
    // Angles are clockwise from 3 o'clock.
    canvas.drawArc(rect, -40 * deg, -100 * deg, false, arc(const Color(0xFFEA4335))); // red, top
    canvas.drawArc(rect, -140 * deg, -90 * deg, false, arc(const Color(0xFFFBBC05))); // yellow, left
    canvas.drawArc(rect, 130 * deg, -90 * deg, false, arc(const Color(0xFF34A853))); // green, bottom
    canvas.drawArc(rect, 40 * deg, -40 * deg, false, arc(const Color(0xFF4285F4))); // blue, right
    // The bar of the G.
    canvas.drawRect(
      Rect.fromLTWH(s / 2, s / 2 - stroke / 2, s / 2 - stroke * 0.05, stroke),
      Paint()..color = const Color(0xFF4285F4),
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
