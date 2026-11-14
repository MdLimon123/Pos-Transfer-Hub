import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/config.dart';
import '../../features/auth/auth_cubit.dart';
import '../theme.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _form = GlobalKey<FormState>();
  final _user = TextEditingController();
  final _pass = TextEditingController();
  bool _obscure = true;

  @override
  void dispose() {
    _user.dispose();
    _pass.dispose();
    super.dispose();
  }

  Future<void> _openRegister() async {
    final messenger = ScaffoldMessenger.of(context);
    var ok = false;
    try {
      ok = await launchUrl(Uri.parse(AppConfig.baseUrl),
          mode: LaunchMode.externalApplication);
    } catch (_) {}
    if (!ok) {
      messenger.showSnackBar(
          const SnackBar(content: Text('Could not open the registration page.')));
    }
  }

  void _submit() {
    if (_form.currentState!.validate()) {
      context.read<AuthCubit>().login(_user.text, _pass.text);
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AuthCubit>().state;
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      body: SingleChildScrollView(
        child: Column(
          children: [
            Container(
              width: double.infinity,
              padding: EdgeInsets.fromLTRB(
                  24, MediaQuery.of(context).padding.top + 44, 24, 56),
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [AppTheme.brandDark, AppTheme.seed, AppTheme.brandLight],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.vertical(bottom: Radius.circular(36)),
              ),
              child: Column(
                children: [
                  Container(
                    width: 72,
                    height: 72,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.18),
                      borderRadius: BorderRadius.circular(22),
                    ),
                    child: const Icon(Icons.swap_vert_rounded, size: 40, color: Colors.white),
                  ),
                  const SizedBox(height: 16),
                  const Text('Transfer Hub',
                      style: TextStyle(
                          color: Colors.white,
                          fontSize: 28,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.6)),
                  const SizedBox(height: 6),
                  const Text('Fast, reliable background uploads & downloads',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.white70, fontSize: 14)),
                ],
              ),
            ),
            Transform.translate(
              offset: const Offset(0, -28),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 440),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Card(
                      child: Padding(
                        padding: const EdgeInsets.all(22),
                        child: Form(
                          key: _form,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Text('Welcome back',
                                  style: Theme.of(context).textTheme.titleLarge),
                              const SizedBox(height: 4),
                              Text('Sign in to continue',
                                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                      color: scheme.onSurfaceVariant)),
                              const SizedBox(height: 22),
                              TextFormField(
                                controller: _user,
                                textInputAction: TextInputAction.next,
                                autofillHints: const [AutofillHints.username],
                                decoration: const InputDecoration(
                                    labelText: 'Username',
                                    prefixIcon: Icon(Icons.person_outline_rounded)),
                                validator: (v) => (v == null || v.trim().isEmpty)
                                    ? 'Enter your username'
                                    : null,
                              ),
                              const SizedBox(height: 14),
                              TextFormField(
                                controller: _pass,
                                obscureText: _obscure,
                                onFieldSubmitted: (_) => _submit(),
                                autofillHints: const [AutofillHints.password],
                                decoration: InputDecoration(
                                  labelText: 'Password',
                                  prefixIcon: const Icon(Icons.lock_outline_rounded),
                                  suffixIcon: IconButton(
                                    icon: Icon(_obscure
                                        ? Icons.visibility_outlined
                                        : Icons.visibility_off_outlined),
                                    onPressed: () => setState(() => _obscure = !_obscure),
                                  ),
                                ),
                                validator: (v) =>
                                    (v == null || v.isEmpty) ? 'Enter your password' : null,
                              ),
                              if (state.error != null) ...[
                                const SizedBox(height: 14),
                                Container(
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: scheme.error.withValues(alpha: 0.1),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Row(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Icon(Icons.error_outline_rounded,
                                          size: 18, color: scheme.error),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: Text(state.error!,
                                            style: TextStyle(
                                                color: scheme.error, fontSize: 13.5)),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                              const SizedBox(height: 22),
                              FilledButton(
                                onPressed: state.busy ? null : _submit,
                                child: state.busy
                                    ? const SizedBox(
                                        height: 20,
                                        width: 20,
                                        child: CircularProgressIndicator(strokeWidth: 2))
                                    : const Text('Sign in'),
                              ),
                              const SizedBox(height: 14),
                              Wrap(
                                alignment: WrapAlignment.center,
                                crossAxisAlignment: WrapCrossAlignment.center,
                                children: [
                                  Text('No account yet?',
                                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                          color: scheme.onSurfaceVariant)),
                                  TextButton(
                                    onPressed: _openRegister,
                                    style: TextButton.styleFrom(
                                      padding: const EdgeInsets.symmetric(horizontal: 6),
                                      minimumSize: const Size(0, 36),
                                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                    ),
                                    child: const Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Text('Register',
                                            style: TextStyle(fontWeight: FontWeight.w700)),
                                        SizedBox(width: 3),
                                        Icon(Icons.open_in_new_rounded, size: 15),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
