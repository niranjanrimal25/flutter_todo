import 'dart:async';

import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:speech_to_text/speech_recognition_result.dart';
import 'package:speech_to_text/speech_to_text.dart';

import '../utils/constants.dart';
import '../services/voice_command_parser.dart';
import 'voice_review_screen.dart';

class VoiceInputScreen extends StatefulWidget {
  final bool autoStart;

  const VoiceInputScreen({super.key, this.autoStart = true});

  @override
  State<VoiceInputScreen> createState() => _VoiceInputScreenState();
}

class _VoiceInputScreenState extends State<VoiceInputScreen>
    with SingleTickerProviderStateMixin {
  final SpeechToText _speech = SpeechToText();
  late final AnimationController _waveController = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  )..repeat();

  bool _available = false;
  bool _isListening = false;
  bool _usingOnDeviceFallback = false;
  bool _fallbackAttempted = false;
  String? _localeId;
  final List<LocaleName> _locales = <LocaleName>[];
  String _transcript = '';
  String? _error;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _initializeAndStart());
  }

  Future<void> _initializeAndStart() async {
    final permission = await Permission.microphone.request();
    if (!permission.isGranted) {
      if (mounted) {
        setState(() {
          _error = 'Microphone permission is required for voice input.';
        });
      }
      return;
    }

    final available = await _speech.initialize(
      onStatus: (status) {
        if (!mounted) return;
        setState(() => _isListening = status == 'listening');
      },
      onError: (error) {
        if (!mounted) return;
        setState(() {
          _isListening = false;
          _error = error.errorMsg;
        });
        // speech_to_text does not expose a vocabulary bias list. Prefer the
        // online recognizer for accuracy, then retry on-device if the service
        // reports a network/recognition failure.
        if (!_usingOnDeviceFallback && !_fallbackAttempted) {
          _fallbackAttempted = true;
          unawaited(_retryOnDevice());
        }
      },
    );
    if (!mounted) return;
    setState(() {
      _available = available;
      _error = available ? null : 'Speech recognition is not available.';
    });
    if (available) {
      await _loadRecognitionLocales();
      if (widget.autoStart) await _startListening();
    }
  }

  Future<void> _loadRecognitionLocales() async {
    try {
      final available = await _speech.locales();
      final system = await _speech.systemLocale();
      LocaleName? selected;
      for (final locale in available) {
        if (locale.localeId == system?.localeId) {
          selected = locale;
          break;
        }
      }
      selected ??= available.cast<LocaleName?>().firstWhere(
            (locale) => locale?.localeId == 'en-IN',
            orElse: () => null,
          );
      selected ??= available.cast<LocaleName?>().firstWhere(
            (locale) => locale?.localeId == 'en-US',
            orElse: () => null,
          );
      selected ??= system;
      if (!mounted) return;
      setState(() {
        _locales
          ..clear()
          ..addAll(available);
        _localeId = selected?.localeId;
      });
    } catch (_) {
      // The platform's system locale remains the recognizer fallback.
    }
  }

  Future<void> _startListening({bool onDevice = false}) async {
    if (!_available) return;
    setState(() {
      _error = null;
      _isListening = true;
      _transcript = '';
      _usingOnDeviceFallback = onDevice;
      if (!onDevice) _fallbackAttempted = false;
    });
    await _speech.listen(
      onResult: _onSpeechResult,
      localeId: _localeId,
      onDevice: onDevice,
      listenMode: ListenMode.dictation,
    );
    if (mounted) setState(() => _isListening = _speech.isListening);
  }

  Future<void> _retryOnDevice() async {
    await _speech.cancel();
    if (!mounted) return;
    await _startListening(onDevice: true);
  }

  Future<void> _chooseLocale() async {
    if (_locales.isEmpty) return;
    final selected = await showModalBottomSheet<LocaleName>(
      context: context,
      builder: (context) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          children: _locales
              .map(
                (locale) => ListTile(
                  title: Text(locale.name),
                  subtitle: Text(locale.localeId),
                  trailing: locale.localeId == _localeId
                      ? const Icon(Icons.check_rounded,
                          color: AppColors.primary)
                      : null,
                  onTap: () => Navigator.pop(context, locale),
                ),
              )
              .toList(),
        ),
      ),
    );
    if (selected != null && mounted) {
      await _stopListening();
      setState(() => _localeId = selected.localeId);
      if (widget.autoStart) await _startListening();
    }
  }

  Future<void> _stopListening() async {
    await _speech.stop();
    if (mounted) setState(() => _isListening = false);
  }

  void _onSpeechResult(SpeechRecognitionResult result) {
    if (!mounted) return;
    setState(() => _transcript = result.recognizedWords);
  }

  Future<void> _reviewTranscript() async {
    await _stopListening();
    final transcript = _transcript.trim();
    if (transcript.isEmpty) {
      setState(() => _error = 'I did not hear a command. Try again.');
      return;
    }

    final draft = VoiceCommandParser.parse(transcript);
    if (!mounted) return;
    await Navigator.push<void>(
      context,
      MaterialPageRoute<void>(
        builder: (_) => VoiceReviewScreen(draft: draft),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Voice command'),
        actions: [
          IconButton(
            tooltip: 'Close',
            onPressed: () => Navigator.pop(context),
            icon: const Icon(Icons.close_rounded),
          ),
        ],
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 20, 24, 28),
          child: Column(
            children: [
              Text(
                _isListening ? 'Listening…' : 'Speak a task or habit',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  color: isDark
                      ? AppColors.darkTextPrimary
                      : AppColors.textDark,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Try: “Add task buy milk tomorrow at 5 PM, high priority”',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: isDark
                      ? AppColors.darkTextSecondary
                      : AppColors.textGrey,
                  fontSize: 13,
                ),
              ),
              const SizedBox(height: 8),
              TextButton.icon(
                onPressed: _chooseLocale,
                icon: const Icon(Icons.language_rounded, size: 16),
                label: Text(
                  '${_localeId ?? 'system locale'} • '
                  '${_usingOnDeviceFallback ? 'on-device fallback' : 'online first'}',
                ),
              ),
              const SizedBox(height: 18),
              _buildWaveform(isDark),
              const SizedBox(height: 32),
              Expanded(
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: isDark ? AppColors.darkCard : AppColors.cardWhite,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: _isListening
                          ? AppColors.primary.withValues(alpha: 0.6)
                          : AppColors.primary.withValues(alpha: 0.16),
                    ),
                  ),
                  child: SingleChildScrollView(
                    child: Text(
                      _transcript.isEmpty
                          ? 'Your live transcript will appear here…'
                          : _transcript,
                      style: TextStyle(
                        color: _transcript.isEmpty
                            ? (isDark
                                ? AppColors.darkTextSecondary
                                : AppColors.textGrey)
                            : (isDark
                                ? AppColors.darkTextPrimary
                                : AppColors.textDark),
                        fontSize: 19,
                        height: 1.45,
                      ),
                    ),
                  ),
                ),
              ),
              if (_error != null) ...[
                const SizedBox(height: 12),
                Text(
                  _error!,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: AppColors.danger,
                    fontSize: 12,
                  ),
                ),
              ],
              const SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  FloatingActionButton(
                    heroTag: 'voice-listen',
                    onPressed:
                        _isListening ? _stopListening : _startListening,
                    backgroundColor: _isListening
                        ? AppColors.danger
                        : AppColors.primary,
                    child: Icon(
                      _isListening
                          ? Icons.stop_rounded
                          : Icons.mic_rounded,
                    ),
                  ),
                  const SizedBox(width: 18),
                  FilledButton.icon(
                    onPressed: _transcript.trim().isEmpty
                        ? null
                        : _reviewTranscript,
                    icon: const Icon(Icons.fact_check_rounded),
                    label: const Text('Review command'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildWaveform(bool isDark) {
    return AnimatedBuilder(
      animation: _waveController,
      builder: (context, _) {
        return SizedBox(
          height: 74,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: List.generate( nineBars, (index) {
              final phase = (_waveController.value + index / nineBars) % 1;
              final height = _isListening
                  ? 16 + (phase < 0.5 ? phase : 1 - phase) * 64
                  : 8.0;
              return AnimatedContainer(
                duration: const Duration(milliseconds: 120),
                width: 5,
                height: height,
                margin: const EdgeInsets.symmetric(horizontal: 3),
                decoration: BoxDecoration(
                  color: _isListening
                      ? AppColors.primary
                      : (isDark
                          ? AppColors.darkTextSecondary
                          : AppColors.textLight),
                  borderRadius: BorderRadius.circular(8),
                ),
              );
            }),
          ),
        );
      },
    );
  }

  static const int nineBars = 9;

  @override
  void dispose() {
    unawaited(_speech.cancel());
    _waveController.dispose();
    super.dispose();
  }
}
