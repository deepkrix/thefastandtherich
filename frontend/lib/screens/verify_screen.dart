import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:thefastandtherich/providers/auth_provider.dart';
import 'package:thefastandtherich/services/api_service.dart';

class VerifyScreen extends ConsumerStatefulWidget {
  final String userId;
  final String email;

  const VerifyScreen({
    super.key,
    required this.userId,
    required this.email,
  });

  @override
  ConsumerState<VerifyScreen> createState() => _VerifyScreenState();
}

class _VerifyScreenState extends ConsumerState<VerifyScreen> {
  final _codeCtrl = TextEditingController();
  bool _loading = false;
  String? _error;
  String? _success;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('E-Mail verifizieren')),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Icon(Icons.mark_email_read, size: 64, color: Colors.amber),
              const SizedBox(height: 16),
              Text(
                'Wir haben einen 6-stelligen Code an\n${widget.email}\ngesendet.',
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 16),
              ),
              const SizedBox(height: 8),
              const Text(
                '(Im MVP-Modus steht der Code in den Server-Logs.)',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 12, color: Colors.grey),
              ),
              const SizedBox(height: 32),
              TextField(
                controller: _codeCtrl,
                decoration: const InputDecoration(
                  labelText: 'Verifizierungscode',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.pin),
                ),
                keyboardType: TextInputType.number,
                maxLength: 6,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 24, letterSpacing: 8),
              ),
              if (_error != null) ...[
                const SizedBox(height: 12),
                Text(
                  _error!,
                  style: const TextStyle(color: Colors.redAccent),
                  textAlign: TextAlign.center,
                ),
              ],
              if (_success != null) ...[
                const SizedBox(height: 12),
                Text(
                  _success!,
                  style: const TextStyle(color: Colors.greenAccent),
                  textAlign: TextAlign.center,
                ),
              ],
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: _loading ? null : _verify,
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  backgroundColor: Colors.amber,
                  foregroundColor: Colors.black,
                ),
                child: _loading
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black),
                      )
                    : const Text('Verifizieren', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              ),
              const SizedBox(height: 16),
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Zurück zum Login'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _verify() async {
    setState(() {
      _loading = true;
      _error = null;
      _success = null;
    });

    try {
      final api = ref.read(apiServiceProvider);
      await api.verify(widget.userId, _codeCtrl.text.trim());
      if (mounted) {
        setState(() => _success = 'E-Mail verifiziert! Du kannst dich jetzt einloggen.');
        Future.delayed(const Duration(seconds: 2), () {
          if (mounted) {
            Navigator.popUntil(context, (route) => route.isFirst);
          }
        });
      }
    } on DioException catch (e) {
      if (mounted) {
        final msg = e.response?.data?['error']?['message'] ?? 'Ungültiger Code';
        setState(() => _error = msg);
      }
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }
}
