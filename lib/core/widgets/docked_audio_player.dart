import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:just_audio/just_audio.dart';
import '../theme/app_colors.dart';
import '../theme/app_radii.dart';
import '../theme/app_shadows.dart';
import '../theme/app_typography.dart';
import 'app_bounceable.dart';

class DockedAudioPlayer extends StatefulWidget {
  final int totalDurationSeconds;
  final String? audioPath;
  final ValueChanged<int>? onSeek;

  const DockedAudioPlayer({
    super.key,
    required this.totalDurationSeconds,
    this.audioPath,
    this.onSeek,
  });

  @override
  State<DockedAudioPlayer> createState() => DockedAudioPlayerState();
}

class DockedAudioPlayerState extends State<DockedAudioPlayer> {
  AudioPlayer? _player;
  StreamSubscription? _posSub;
  StreamSubscription? _stateSub;
  Timer? _mockTimer;

  bool _isPlaying = false;
  int _currentSeconds = 0;
  double _playbackSpeed = 1.0;
  bool _hasRealAudio = false;

  @override
  void initState() {
    super.initState();
    _initAudio();
  }

  Future<void> _initAudio() async {
    final path = widget.audioPath;
    if (path != null && path.isNotEmpty && await File(path).exists()) {
      try {
        _player = AudioPlayer();
        await _player!.setFilePath(path);
        _hasRealAudio = true;

        _posSub = _player!.positionStream.listen((pos) {
          if (mounted) {
            setState(() {
              _currentSeconds = pos.inSeconds.clamp(0, widget.totalDurationSeconds);
            });
            widget.onSeek?.call(_currentSeconds);
          }
        });

        _stateSub = _player!.playerStateStream.listen((state) {
          if (mounted) {
            final isPlaying = state.playing &&
                state.processingState != ProcessingState.completed;
            if (isPlaying != _isPlaying) {
              setState(() => _isPlaying = isPlaying);
            }
            if (state.processingState == ProcessingState.completed) {
              _player!.seek(Duration.zero);
              _player!.pause();
              setState(() {
                _isPlaying = false;
                _currentSeconds = 0;
              });
            }
          }
        });
        return;
      } catch (_) {
        _hasRealAudio = false;
      }
    }
  }

  void seekTo(int seconds) {
    final clamped = seconds.clamp(0, widget.totalDurationSeconds);
    setState(() => _currentSeconds = clamped);
    widget.onSeek?.call(_currentSeconds);

    if (_hasRealAudio && _player != null) {
      _player!.seek(Duration(seconds: clamped));
    }
  }

  void _togglePlayPause() {
    HapticFeedback.lightImpact();
    if (_hasRealAudio && _player != null) {
      if (_isPlaying) {
        _player!.pause();
      } else {
        _player!.play();
      }
    } else {
      // Graceful fallback for mock notes without audio files
      setState(() => _isPlaying = !_isPlaying);
      _mockTimer?.cancel();
      if (_isPlaying) {
        _mockTimer = Timer.periodic(
          Duration(milliseconds: (1000 / _playbackSpeed).round()),
          (timer) {
            if (_currentSeconds < widget.totalDurationSeconds) {
              setState(() => _currentSeconds++);
              widget.onSeek?.call(_currentSeconds);
            } else {
              setState(() {
                _isPlaying = false;
                _currentSeconds = 0;
              });
              timer.cancel();
            }
          },
        );
      }
    }
  }

  void _cycleSpeed() {
    HapticFeedback.selectionClick();
    double nextSpeed = 1.0;
    if (_playbackSpeed == 1.0) {
      nextSpeed = 1.5;
    } else if (_playbackSpeed == 1.5) {
      nextSpeed = 2.0;
    } else {
      nextSpeed = 1.0;
    }

    setState(() => _playbackSpeed = nextSpeed);
    if (_hasRealAudio && _player != null) {
      _player!.setSpeed(nextSpeed);
    }
  }

  String _formatTime(int seconds) {
    final m = (seconds ~/ 60).toString().padLeft(2, '0');
    final s = (seconds % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  @override
  void dispose() {
    _posSub?.cancel();
    _stateSub?.cancel();
    _mockTimer?.cancel();
    _player?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final progress = widget.totalDurationSeconds > 0
        ? (_currentSeconds / widget.totalDurationSeconds).clamp(0.0, 1.0)
        : 0.0;

    return Container(
      height: 56,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: AppRadii.roundedFull,
        border: Border.all(color: AppColors.borderSubtle, width: 1),
        boxShadow: AppShadows.elevated,
      ),
      child: Row(
        children: [
          // 1. Play / Pause Circular Terracotta Button
          AppBounceable(
            onTap: _togglePlayPause,
            scaleFactor: 0.90,
            child: Container(
              width: 42,
              height: 42,
              decoration: const BoxDecoration(
                color: AppColors.primary,
                shape: BoxShape.circle,
                boxShadow: AppShadows.card,
              ),
              child: Center(
                child: Icon(
                  _isPlaying ? Icons.pause : Icons.play_arrow,
                  color: Colors.white,
                  size: 24,
                ),
              ),
            ),
          ),

          const SizedBox(width: 10),

          // 2. Current Timestamp
          Text(
            _formatTime(_currentSeconds),
            style: AppTypography.labelSmall.copyWith(
              fontWeight: FontWeight.w700,
              color: AppColors.inkPrimary,
              fontSize: 11,
            ),
          ),

          const SizedBox(width: 8),

          // 3. Mini Interactive Waveform Scrubber
          Expanded(
            child: LayoutBuilder(
              builder: (context, constraints) {
                const barCount = 28;
                return GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onHorizontalDragUpdate: (details) {
                    final dx = details.localPosition.dx.clamp(0.0, constraints.maxWidth);
                    final ratio = dx / constraints.maxWidth;
                    seekTo((ratio * widget.totalDurationSeconds).round());
                  },
                  onTapDown: (details) {
                    final dx = details.localPosition.dx.clamp(0.0, constraints.maxWidth);
                    final ratio = dx / constraints.maxWidth;
                    seekTo((ratio * widget.totalDurationSeconds).round());
                  },
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: List.generate(barCount, (i) {
                      final barProgress = i / barCount;
                      final isPassed = barProgress <= progress;
                      final heights = [
                        8.0, 14.0, 22.0, 16.0, 28.0, 12.0, 20.0, 32.0,
                        18.0, 24.0, 14.0, 30.0, 20.0, 16.0, 26.0, 18.0,
                        32.0, 14.0, 22.0, 28.0, 16.0, 20.0, 12.0, 24.0,
                        18.0, 30.0, 14.0, 22.0
                      ];
                      final barHeight = heights[i % heights.length];

                      return Container(
                        width: 2.5,
                        height: barHeight,
                        decoration: BoxDecoration(
                          color: isPassed
                              ? AppColors.primary
                              : AppColors.borderSubtle,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      );
                    }),
                  ),
                );
              },
            ),
          ),

          const SizedBox(width: 8),

          // 4. Total Duration
          Text(
            _formatTime(widget.totalDurationSeconds),
            style: AppTypography.labelSmall.copyWith(
              color: AppColors.inkSubtle,
              fontSize: 11,
            ),
          ),

          const SizedBox(width: 8),

          // 5. Tactile Playback Speed Chip
          AppBounceable(
            onTap: _cycleSpeed,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3.5),
              decoration: BoxDecoration(
                color: AppColors.surfaceContainer,
                borderRadius: AppRadii.roundedFull,
              ),
              child: Text(
                '${_playbackSpeed == 1.0 ? "1.0" : _playbackSpeed.toString()}x',
                style: AppTypography.labelSmall.copyWith(
                  fontWeight: FontWeight.w700,
                  color: AppColors.inkPrimary,
                  fontSize: 10.5,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
