import 'dart:async';

import 'package:audioplayers/audioplayers.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../screens/call/call_screen.dart';
import '../services/call_service.dart';

class IncomingCallListener extends StatefulWidget {
  const IncomingCallListener({
    super.key,
    required this.navigatorKey,
    required this.child,
  });

  final GlobalKey<NavigatorState> navigatorKey;
  final Widget child;

  @override
  State<IncomingCallListener> createState() => _IncomingCallListenerState();
}

class _IncomingCallListenerState extends State<IncomingCallListener> {
  final AudioPlayer _ringPlayer = AudioPlayer();
  StreamSubscription<User?>? _authSubscription;
  StreamSubscription<AppCall?>? _callSubscription;
  final Set<String> _openedCalls = <String>{};
  bool _openingCall = false;
  AppCall? _incomingCall;

  @override
  void initState() {
    super.initState();
    _authSubscription = FirebaseAuth.instance.authStateChanges().listen(
      _listenForUserCalls,
    );
  }

  void _listenForUserCalls(User? user) {
    _callSubscription?.cancel();
    if (user == null) return;
    _callSubscription = CallService.watchIncomingCall(user.uid).listen((
      call,
    ) {
      if (call == null) {
        if (_incomingCall != null && mounted) {
          setState(() => _incomingCall = null);
          _stopRingSound();
        }
        return;
      }
      if (_openingCall || _openedCalls.contains(call.id)) {
        return;
      }
      if (mounted) {
        setState(() => _incomingCall = call);
        _startRingSound();
      }
    });
  }

  Future<void> _acceptFromBanner() async {
    final call = _incomingCall;
    if (call == null || _openingCall) return;
    await _stopRingSound();
    setState(() => _incomingCall = null);
    _openingCall = true;
    _openedCalls.add(call.id);
    CallOverlayController.instance.startIncoming(call);
    _openingCall = false;
  }

  Future<void> _declineFromBanner() async {
    final call = _incomingCall;
    if (call == null) return;
    await _stopRingSound();
    setState(() => _incomingCall = null);
    _openedCalls.add(call.id);
    await CallService.setStatus(call.id, 'declined');
  }

  @override
  void dispose() {
    _ringPlayer.dispose();
    _authSubscription?.cancel();
    _callSubscription?.cancel();
    super.dispose();
  }

  Future<void> _startRingSound() async {
    if (_ringPlayer.state == PlayerState.playing) return;
    await _ringPlayer.setReleaseMode(ReleaseMode.loop);
    await _ringPlayer.setVolume(0.7);
    await _ringPlayer.play(AssetSource('sounds/call_ring.wav'));
  }

  Future<void> _stopRingSound() async {
    await _ringPlayer.stop();
  }

  @override
  Widget build(BuildContext context) {
    final call = _incomingCall;
    return AnimatedBuilder(
      animation: CallOverlayController.instance,
      builder: (context, _) {
        final activeCall = CallOverlayController.instance.activeCall;
        return Stack(
          children: <Widget>[
            widget.child,
            if (call != null && activeCall == null)
              Positioned(
                left: 12,
                right: 12,
                top: MediaQuery.paddingOf(context).top + 10,
                child: Material(
                  color: Colors.transparent,
                  child: _IncomingCallBanner(
                    call: call,
                    onAccept: _acceptFromBanner,
                    onDecline: _declineFromBanner,
                  ),
                ),
              ),
            if (activeCall != null)
              Positioned.fill(child: activeCall),
          ],
        );
      },
    );
  }
}

class _IncomingCallBanner extends StatelessWidget {
  const _IncomingCallBanner({
    required this.call,
    required this.onAccept,
    required this.onDecline,
  });

  final AppCall call;
  final VoidCallback onAccept;
  final VoidCallback onDecline;

  @override
  Widget build(BuildContext context) {
    final photo = call.callerPhotoUrl.trim();
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 12, 12),
      decoration: BoxDecoration(
        color: const Color(0xff171923),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white12),
        boxShadow: const <BoxShadow>[
          BoxShadow(
            color: Color(0x66000000),
            blurRadius: 26,
            offset: Offset(0, 10),
          ),
        ],
      ),
      child: Row(
        children: <Widget>[
          CircleAvatar(
            radius: 25,
            backgroundColor: const Color(0xff2A2D38),
            backgroundImage: photo.isEmpty ? null : NetworkImage(photo),
            child: photo.isEmpty
                ? const Icon(Icons.person_rounded, color: Colors.white)
                : null,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Text(
                  call.callerName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  call.isVideo
                      ? 'Входящий видеозвонок'
                      : 'Входящий звонок',
                  style: const TextStyle(
                    color: Colors.white60,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          _BannerButton(
            color: const Color(0xffFF4F5E),
            icon: Icons.call_end_rounded,
            label: 'Отклонить',
            onTap: onDecline,
          ),
          const SizedBox(width: 12),
          _BannerButton(
            color: const Color(0xff38C96B),
            icon: call.isVideo
                ? Icons.videocam_rounded
                : Icons.call_rounded,
            label: 'Принять',
            onTap: onAccept,
          ),
        ],
      ),
    );
  }
}

class _BannerButton extends StatelessWidget {
  const _BannerButton({
    required this.color,
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final Color color;
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(30),
          child: Ink(
            width: 45,
            height: 45,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
            child: Icon(icon, color: Colors.white, size: 23),
          ),
        ),
        const SizedBox(height: 3),
        Text(
          label,
          style: const TextStyle(
            color: Colors.white70,
            fontSize: 9,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}
