import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'LSA Onboarding Gate',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xff5b4bdb)),
        useMaterial3: true,
        scaffoldBackgroundColor: const Color(0xfff5f3ff),
      ),
      home: LsaVerificationScreen(),
    );
  }
}

class LineageException implements Exception {
  const LineageException(this.message);

  final String message;

  @override
  String toString() => 'LineageException: $message';
}

enum VerificationStatus { idle, processing, quarantined, success }

class LsaVerificationScreen extends StatelessWidget {
  LsaVerificationScreen({
    super.key,
    http.Client? client,
    this.endpoint = 'https://api.habotconnect.com/v1/compliance/verify',
  }) : client = client ?? _DefaultHttpClient();

  final http.Client client;
  final String endpoint;

  @override
  Widget build(BuildContext context) {
    return _LsaVerificationForm(client: client, endpoint: endpoint);
  }
}

class _DefaultHttpClient extends http.BaseClient {
  _DefaultHttpClient();

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) {
    return http.Client().send(request);
  }
}

class _LsaVerificationForm extends StatefulWidget {
  const _LsaVerificationForm({required this.client, required this.endpoint});

  final http.Client client;
  final String endpoint;

  @override
  State<_LsaVerificationForm> createState() => _LsaVerificationFormState();
}

class _LsaVerificationFormState extends State<_LsaVerificationForm> {
  final _formKey = GlobalKey<FormState>();
  final _predecessorController = TextEditingController(text: 'PRED-9982-XYZ');
  final _lsaController = TextEditingController(text: 'LSA-7049');
  final _consentController = TextEditingController(text: 'PCC-2026-9901');
  Timer? _frictionTimer;
  VerificationStatus _status = VerificationStatus.idle;
  bool _submissionLocked = false;
  bool _consentEditedOrSubmitted = false;

  static const _traceId = '8f3d1b2a-4c9e-4a11-b8d2-9901ef23a011';
  static const _logicHash =
      'e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855';

  @override
  void dispose() {
    _frictionTimer?.cancel();
    _predecessorController.dispose();
    _lsaController.dispose();
    _consentController.dispose();
    super.dispose();
  }

  void _startConsentFrictionTimer() {
    _frictionTimer?.cancel();
    _consentEditedOrSubmitted = false;
    _frictionTimer = Timer(const Duration(seconds: 5), () {
      if (!_consentEditedOrSubmitted && mounted) {
        final timestamp = DateTime.now().toUtc().toIso8601String();
        debugPrint(
          '[UI_FRICTION_LOG] Timestamp: $timestamp | Field: '
          'parent_consent_code | Hesitation Duration: 5.0s',
        );
      }
    });
  }

  void _markConsentActivity(String _) {
    _consentEditedOrSubmitted = true;
    _frictionTimer?.cancel();
  }

  Future<void> _verifyAndSubmit() async {
    _consentEditedOrSubmitted = true;
    _frictionTimer?.cancel();
    if (_submissionLocked || _status == VerificationStatus.processing) return;

    if (_predecessorController.text.trim().isEmpty) {
      _quarantine();
      return;
    }
    if (!_formKey.currentState!.validate()) return;

    setState(() => _status = VerificationStatus.processing);
    final payload = <String, String>{
      'predecessor_id': _predecessorController.text.trim(),
      'lsa_id': _lsaController.text.trim(),
      'parent_consent_code': _consentController.text.trim(),
      'timestamp_utc': DateTime.now().toUtc().toIso8601String(),
    };

    try {
      final response = await widget.client
          .post(
            Uri.parse(widget.endpoint),
            headers: {
              'Content-Type': 'application/json',
              'x-trace-id': _traceId,
              'x-logic-hash': _logicHash,
            },
            body: jsonEncode(payload),
          )
          .timeout(const Duration(seconds: 10));
      final decoded = jsonDecode(response.body);
      if (response.statusCode < 200 ||
          response.statusCode >= 300 ||
          decoded is! Map ||
          decoded['status'] == null) {
        throw StateError('Compliance verification failed.');
      }
      if (mounted) setState(() => _status = VerificationStatus.success);
    } on LineageException {
      _quarantine();
    } on Object {
      _quarantine();
    }
  }

  void _quarantine() {
    _predecessorController.clear();
    _lsaController.clear();
    _consentController.clear();
    if (mounted) {
      setState(() {
        _status = VerificationStatus.quarantined;
        _submissionLocked = true;
      });
    }
  }

  String get _statusText {
    switch (_status) {
      case VerificationStatus.idle:
        return 'Idle';
      case VerificationStatus.processing:
        return 'Processing';
      case VerificationStatus.quarantined:
        return 'Data Quarantined – Compliance Failure';
      case VerificationStatus.success:
        return 'Success';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xff6d5ce7), Color(0xffa18cf0)],
          ),
        ),
        child: SafeArea(
          child: Stack(
            children: [
              Positioned(
                top: -70,
                right: -40,
                child: _glowCircle(180, Colors.white.withValues(alpha: .12)),
              ),
              Positioned(
                bottom: -90,
                left: -70,
                child: _glowCircle(210, Colors.white.withValues(alpha: .10)),
              ),
              Form(
                key: _formKey,
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(22, 28, 22, 24),
                  children: [
                    const Icon(
                      Icons.verified_user_rounded,
                      size: 54,
                      color: Colors.white,
                    ),
                    const SizedBox(height: 10),
                    const Text(
                      'LSA Onboarding Gate',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 27,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      'HabotConnect Data Compliance',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: .82),
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 26),
                    Container(
                      padding: const EdgeInsets.fromLTRB(22, 24, 22, 22),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(28),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(
                              0xff34277f,
                            ).withValues(alpha: .2),
                            blurRadius: 25,
                            offset: const Offset(0, 12),
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Verify your lineage',
                            style: TextStyle(
                              fontSize: 21,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 5),
                          Text(
                            'Confirm the records below before submitting.',
                            style: TextStyle(color: Colors.grey.shade600),
                          ),
                          const SizedBox(height: 20),
                          _statusBanner(),
                          const SizedBox(height: 20),
                          _field(
                            _predecessorController,
                            'Predecessor ID',
                            key: const Key('predecessor_id'),
                            icon: Icons.account_tree_rounded,
                            validator: (value) => value!.trim().isEmpty
                                ? 'Predecessor ID is required'
                                : null,
                          ),
                          _field(
                            _lsaController,
                            'LSA ID',
                            key: const Key('lsa_id'),
                            icon: Icons.badge_outlined,
                          ),
                          _field(
                            _consentController,
                            'Parent consent code',
                            key: const Key('parent_consent_code'),
                            icon: Icons.lock_outline_rounded,
                            onFocus: _startConsentFrictionTimer,
                            onChanged: _markConsentActivity,
                          ),
                          const SizedBox(height: 4),
                          SizedBox(
                            width: double.infinity,
                            height: 52,
                            child: FilledButton(
                              onPressed: _submissionLocked
                                  ? null
                                  : _verifyAndSubmit,
                              style: FilledButton.styleFrom(
                                backgroundColor: const Color(0xff5b4bdb),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16),
                                ),
                              ),
                              child: const Text(
                                'Verify & Submit',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _glowCircle(double size, Color color) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(shape: BoxShape.circle, color: color),
    );
  }

  Widget _statusBanner() {
    final (background, foreground, icon) = switch (_status) {
      VerificationStatus.quarantined => (
        const Color(0xffffecec),
        const Color(0xffc62828),
        Icons.gpp_bad_outlined,
      ),
      VerificationStatus.success => (
        const Color(0xffeaf8ef),
        const Color(0xff19733d),
        Icons.check_circle_outline,
      ),
      VerificationStatus.processing => (
        const Color(0xffedf2ff),
        const Color(0xff315dcc),
        Icons.sync_rounded,
      ),
      VerificationStatus.idle => (
        const Color(0xfff3f2f7),
        const Color(0xff625f6b),
        Icons.info_outline_rounded,
      ),
    };
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          Icon(icon, color: foreground, size: 20),
          const SizedBox(width: 9),
          Expanded(
            child: Text(
              _statusText,
              key: const Key('status_banner'),
              style: TextStyle(color: foreground, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }

  Widget _field(
    TextEditingController controller,
    String label, {
    Key? key,
    IconData? icon,
    String? Function(String?)? validator,
    void Function()? onFocus,
    void Function(String)? onChanged,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: TextFormField(
        key: key,
        controller: controller,
        decoration: InputDecoration(
          filled: true,
          fillColor: const Color(0xfff7f7fb),
          prefixIcon: Icon(icon, color: const Color(0xff777386)),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide.none,
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide.none,
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: Color(0xff5b4bdb), width: 1.5),
          ),
          labelText: label,
        ),
        validator: validator,
        onTap: onFocus,
        onChanged: onChanged,
      ),
    );
  }
}
