import 'dart:async';

import 'package:audioplayers/audioplayers.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../services/call_service.dart';

class CallOverlayController extends ChangeNotifier {
  CallOverlayController._();

  static final CallOverlayController instance = CallOverlayController._();

  Widget? _activeCall;
  Widget? get activeCall => _activeCall;
  bool get hasActiveCall => _activeCall != null;

  void startOutgoing({
    required String otherUid,
    required String otherName,
    required String otherPhotoUrl,
    required AppCallType type,
  }) {
    if (_activeCall != null) return;
    _activeCall = CallScreen.outgoing(
      otherUid: otherUid,
      otherName: otherName,
      otherPhotoUrl: otherPhotoUrl,
      type: type,
      onClosed: clear,
    );
    notifyListeners();
  }

  void startIncoming(AppCall call) {
    if (_activeCall != null) return;
    _activeCall = CallScreen.incoming(
      call: call,
      autoAccept: true,
      onClosed: clear,
    );
    notifyListeners();
  }

  void clear() {
    if (_activeCall == null) return;
    _activeCall = null;
    notifyListeners();
  }
}

class CallScreen extends StatefulWidget {
  const CallScreen.outgoing({
    super.key,
    required this.otherUid,
    required this.otherName,
    required this.otherPhotoUrl,
    required this.type,
    this.autoAccept = false,
    this.onClosed,
  }) : incomingCall = null;

  CallScreen.incoming({
    super.key,
    required AppCall call,
    this.autoAccept = false,
    this.onClosed,
  })  : incomingCall = call,
        otherUid = call.callerUid,
        otherName = call.callerName,
        otherPhotoUrl = call.callerPhotoUrl,
        type = call.type;

  final bool autoAccept;
  final VoidCallback? onClosed;

  final AppCall? incomingCall;
  final String otherUid;
  final String otherName;
  final String otherPhotoUrl;
  final AppCallType type;

  @override
  State<CallScreen> createState() => _CallScreenState();
}

class _CallScreenState extends State<CallScreen> {
  final AudioPlayer _ringPlayer = AudioPlayer();
  final RTCVideoRenderer _localRenderer = RTCVideoRenderer();
  final RTCVideoRenderer _remoteRenderer = RTCVideoRenderer();

  RTCPeerConnection? _peerConnection;
  MediaStream? _localStream;
  MediaStream? _cameraStream;
  MediaStream? _remoteFallbackStream;
  StreamSubscription<RTCIceCandidate>? _candidateSubscription;
  StreamSubscription<RTCSessionDescription?>? _answerSubscription;
  StreamSubscription<AppCall?>? _callSubscription;
  StreamSubscription<String?>? _statusSubscription;
  Timer? _durationTimer;

  String? _callId;
  String _status = 'Подготовка…';
  int _durationSeconds = 0;
  bool _microphoneEnabled = true;
  bool _cameraEnabled = false;
  bool _speakerEnabled = true;
  bool _usingFrontCamera = true;
  bool _cameraOperationInProgress = false;
  bool _speakerOperationInProgress = false;
  bool _remoteCameraEnabled = false;
  bool _accepted = false;
  bool _ending = false;
  bool _minimized = false;
  bool _remoteDescriptionSet = false;
  final List<RTCIceCandidate> _pendingLocalCandidates =
      <RTCIceCandidate>[];
  final List<RTCIceCandidate> _pendingRemoteCandidates =
      <RTCIceCandidate>[];

  bool get _isIncoming => widget.incomingCall != null;
  bool get _isVideoVisible =>
      _cameraEnabled || _remoteCameraEnabled;

  @override
  void initState() {
    super.initState();
    _initializeRenderers();
  }

  Future<void> _initializeRenderers() async {
    await _localRenderer.initialize();
    await _remoteRenderer.initialize();
    if (!mounted) return;

    if (_isIncoming) {
      _callId = widget.incomingCall!.id;
      setState(() {
        _status = widget.type == AppCallType.video
            ? 'Входящий видеозвонок'
            : 'Входящий звонок';
      });
      _watchCallState();
      if (widget.autoAccept) {
        await _acceptIncomingCall();
      }
    } else {
      await _startOutgoingCall();
    }
  }

  Future<MediaStream> _openMedia({required bool cameraEnabled}) async {
    final stream = await navigator.mediaDevices.getUserMedia(
      <String, dynamic>{
        'audio': <String, dynamic>{
          'echoCancellation': true,
          'noiseSuppression': true,
          'autoGainControl': true,
        },
        // Для аудиозвонка камеру не запрашиваем. Это важно для Web/PWA:
        // отсутствие камеры больше не ломает обычный звонок.
        'video': cameraEnabled
            ? <String, dynamic>{
                'facingMode': 'user',
                'width': <String, dynamic>{'ideal': 720},
                'height': <String, dynamic>{'ideal': 1280},
                'frameRate': <String, dynamic>{'ideal': 24, 'max': 30},
              }
            : false,
      },
    );

    for (final track in stream.getVideoTracks()) {
      track.enabled = cameraEnabled;
    }
    _cameraEnabled = cameraEnabled;
    _localRenderer.srcObject = stream;
    return stream;
  }

  Future<RTCPeerConnection> _createPeerConnection({
    required bool localIsCaller,
  }) async {
    final peer = await createPeerConnection(CallService.peerConfiguration);

    // В аудиозвонке заранее создаём video m-line. Позже камера включается
    // через replaceTrack без повторного offer/answer и без чёрного экрана.
    if (localIsCaller &&
        (_localStream?.getVideoTracks().isEmpty ?? true)) {
      await peer.addTransceiver(
        kind: RTCRtpMediaType.RTCRtpMediaTypeVideo,
        init: RTCRtpTransceiverInit(
          direction: TransceiverDirection.SendRecv,
          streams: _localStream == null
              ? <MediaStream>[]
              : <MediaStream>[_localStream!],
        ),
      );
    }

    peer.onIceCandidate = (candidate) {
      final callId = _callId;
      if (candidate.candidate == null) return;
      if (callId == null) {
        _pendingLocalCandidates.add(candidate);
        return;
      }
      CallService.addCandidate(
        callId: callId,
        fromCaller: localIsCaller,
        candidate: candidate,
      );
    };

    peer.onTrack = (event) async {
      MediaStream remoteStream;
      if (event.streams.isNotEmpty) {
        remoteStream = event.streams.first;
      } else {
        // На Flutter Web видеотрек нередко приходит без event.streams.
        // Создаём поток вручную и привязываем полученный трек к renderer.
        _remoteFallbackStream ??= await createLocalMediaStream(
          'remote_${_callId ?? DateTime.now().millisecondsSinceEpoch}',
        );
        remoteStream = _remoteFallbackStream!;
        final alreadyAdded = remoteStream
            .getTracks()
            .any((track) => track.id == event.track.id);
        if (!alreadyAdded) {
          await remoteStream.addTrack(event.track);
        }
      }
      if (!mounted) return;
      setState(() => _remoteRenderer.srcObject = remoteStream);
    };

    peer.onConnectionState = (state) {
      if (!mounted) return;
      if (state == RTCPeerConnectionState.RTCPeerConnectionStateConnected) {
        _onConnected();
      } else if (state ==
          RTCPeerConnectionState.RTCPeerConnectionStateFailed) {
        setState(() => _status = 'Соединение потеряно');
      }
    };

    return peer;
  }

  Future<void> _startOutgoingCall() async {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) {
      _showErrorAndClose('Войдите в аккаунт для звонка');
      return;
    }

    try {
      setState(() => _status = 'Подключаем камеру и микрофон…');
      _localStream = await _openMedia(
        cameraEnabled: widget.type == AppCallType.video,
      );
      _peerConnection = await _createPeerConnection(localIsCaller: true);

      for (final track in _localStream!.getTracks()) {
        await _peerConnection!.addTrack(track, _localStream!);
      }

      final offer = await _peerConnection!.createOffer();
      await _peerConnection!.setLocalDescription(offer);

      final identity = await CallService.readUserIdentity(currentUser.uid);
      final callerName = identity['name']?.isNotEmpty == true
          ? identity['name']!
          : (currentUser.displayName ?? 'Пользователь');
      final callerPhotoUrl = identity['photoUrl']?.isNotEmpty == true
          ? identity['photoUrl']!
          : (currentUser.photoURL ?? '');

      _callId = await CallService.createCall(
        callerUid: currentUser.uid,
        callerName: callerName,
        callerPhotoUrl: callerPhotoUrl,
        receiverUid: widget.otherUid,
        receiverName: widget.otherName,
        receiverPhotoUrl: widget.otherPhotoUrl,
        type: widget.type,
        offer: offer,
      );
      await _flushLocalCandidates(localIsCaller: true);

      setState(() => _status = 'Вызов…');
      await _startRingSound();
      _listenForCandidates(localIsCaller: true);
      _answerSubscription = CallService.watchAnswer(_callId!).listen((
        answer,
      ) async {
        if (answer == null || _remoteDescriptionSet) return;
        _remoteDescriptionSet = true;
        await _peerConnection?.setRemoteDescription(answer);
        await _flushRemoteCandidates();
      });
      _watchCallState();
    } catch (error) {
      _showErrorAndClose('Не удалось начать звонок: $error');
    }
  }

  Future<void> _acceptIncomingCall() async {
    if (_accepted) return;
    final callId = _callId;
    if (callId == null) return;

    setState(() {
      _accepted = true;
      _status = 'Соединение…';
    });

    try {
      _localStream = await _openMedia(
        cameraEnabled: widget.type == AppCallType.video,
      );
      _peerConnection = await _createPeerConnection(localIsCaller: false);

      for (final track in _localStream!.getTracks()) {
        await _peerConnection!.addTrack(track, _localStream!);
      }

      final offer = await CallService.readOffer(callId);
      if (offer == null) throw StateError('Предложение звонка не найдено');

      await _peerConnection!.setRemoteDescription(offer);
      _remoteDescriptionSet = true;
      await _flushRemoteCandidates();
      final answer = await _peerConnection!.createAnswer();
      await _peerConnection!.setLocalDescription(answer);
      await CallService.answerCall(callId: callId, answer: answer);
      _listenForCandidates(localIsCaller: false);
    } catch (error) {
      _showErrorAndClose('Не удалось принять звонок: $error');
    }
  }

  void _listenForCandidates({required bool localIsCaller}) {
    final callId = _callId;
    if (callId == null) return;
    _candidateSubscription = CallService.watchRemoteCandidates(
      callId: callId,
      localIsCaller: localIsCaller,
    ).listen((candidate) {
      if (!_remoteDescriptionSet) {
        _pendingRemoteCandidates.add(candidate);
        return;
      }
      _peerConnection?.addCandidate(candidate);
    });
  }

  Future<void> _flushLocalCandidates({
    required bool localIsCaller,
  }) async {
    final callId = _callId;
    if (callId == null) return;
    final candidates = List<RTCIceCandidate>.of(_pendingLocalCandidates);
    _pendingLocalCandidates.clear();
    for (final candidate in candidates) {
      await CallService.addCandidate(
        callId: callId,
        fromCaller: localIsCaller,
        candidate: candidate,
      );
    }
  }

  Future<void> _flushRemoteCandidates() async {
    final candidates = List<RTCIceCandidate>.of(_pendingRemoteCandidates);
    _pendingRemoteCandidates.clear();
    for (final candidate in candidates) {
      await _peerConnection?.addCandidate(candidate);
    }
  }

  void _watchCallState() {
    final callId = _callId;
    if (callId == null) return;
    _statusSubscription =
        CallService.watchCallStatus(callId).listen((status) {
      if (!mounted) return;
      if (status == 'active') {
        _onConnected();
      } else if (<String>{
        'ended',
        'declined',
        'cancelled',
      }.contains(status)) {
        _closeWithoutUpdating();
      }
    });

    _callSubscription = CallService.watchCall(callId).listen((call) {
      if (call == null || !mounted) return;
      final currentUid = FirebaseAuth.instance.currentUser?.uid;
      if (currentUid != null) {
        final otherUid = currentUid == call.callerUid
            ? call.receiverUid
            : call.callerUid;
        final remoteCameraEnabled =
            call.videoEnabledBy[otherUid] == true;
        if (_remoteCameraEnabled != remoteCameraEnabled) {
          setState(() {
            _remoteCameraEnabled = remoteCameraEnabled;
          });
        }
      }
    });
  }

  void _onConnected() {
    if (!mounted || _durationTimer != null) return;
    _stopRingSound();
    setState(() => _status = 'На связи');
    _durationTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      setState(() => _durationSeconds++);
    });
  }

  void _toggleMicrophone() {
    _microphoneEnabled = !_microphoneEnabled;
    for (final track in _localStream?.getAudioTracks() ?? <MediaStreamTrack>[]) {
      track.enabled = _microphoneEnabled;
    }
    setState(() {});
  }

  Future<void> _toggleCamera() async {
    if (_cameraOperationInProgress) return;
    final shouldEnable = !_cameraEnabled;
    if (mounted) {
      setState(() => _cameraOperationInProgress = true);
    }

    try {
      if (shouldEnable &&
          (_localStream?.getVideoTracks().isEmpty ?? true)) {
        try {
          final cameraStream = await _captureCameraStream(frontCamera: true);
          _cameraStream = cameraStream;
          _usingFrontCamera = true;
          for (final track in cameraStream.getVideoTracks()) {
            await _localStream?.addTrack(track);
            final transceivers =
                await _peerConnection?.getTransceivers() ??
                <RTCRtpTransceiver>[];
            RTCRtpTransceiver? videoTransceiver;
            for (final transceiver in transceivers) {
              if (transceiver.receiver.track?.kind == 'video') {
                videoTransceiver = transceiver;
                break;
              }
            }

            if (videoTransceiver != null) {
              await videoTransceiver.sender.replaceTrack(track);
              await videoTransceiver.setDirection(
                TransceiverDirection.SendRecv,
              );
            } else {
              // Запасной вариант для старых видеозвонков, созданных до фикса.
              await _peerConnection?.addTrack(track, _localStream!);
            }
          }
          _localRenderer.srcObject = _localStream;
        } catch (error) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Камера недоступна: $error')),
            );
          }
          return;
        }
      }

      _cameraEnabled = shouldEnable;
      for (final track
          in _localStream?.getVideoTracks() ?? <MediaStreamTrack>[]) {
        track.enabled = _cameraEnabled;
      }
      if (mounted) setState(() {});
      final callId = _callId;
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (callId != null && uid != null) {
        await CallService.setVideoEnabled(
          callId: callId,
          uid: uid,
          enabled: _cameraEnabled,
        );
      }
    } finally {
      if (mounted) {
        setState(() => _cameraOperationInProgress = false);
      }
    }
  }

  Future<void> _switchCamera() async {
    if (_cameraOperationInProgress || !_cameraEnabled) return;
    final tracks = _localStream?.getVideoTracks() ?? <MediaStreamTrack>[];
    if (tracks.isEmpty) return;

    setState(() => _cameraOperationInProgress = true);
    try {
      if (!kIsWeb) {
        await Helper.switchCamera(tracks.first);
        _usingFrontCamera = !_usingFrontCamera;
        if (mounted) setState(() {});
        return;
      }

      await _replaceWebCameraTrack(
        frontCamera: !_usingFrontCamera,
      );
    } catch (error) {
      _showTransientMessage('Не удалось повернуть камеру: $error');
    } finally {
      if (mounted) {
        setState(() => _cameraOperationInProgress = false);
      }
    }
  }

  Future<void> _toggleSpeaker() async {
    if (_speakerOperationInProgress) return;

    if (kIsWeb) {
      _showTransientMessage(
        'В веб-версии вывод звука выбирается в браузере или настройках телефона',
      );
      return;
    }

    final nextValue = !_speakerEnabled;
    setState(() {
      _speakerEnabled = nextValue;
      _speakerOperationInProgress = true;
    });

    try {
      await Helper.setSpeakerphoneOn(nextValue);
    } catch (error) {
      if (mounted) {
        setState(() => _speakerEnabled = !nextValue);
      }
      _showTransientMessage('Не удалось переключить динамик: $error');
    } finally {
      if (mounted) {
        setState(() => _speakerOperationInProgress = false);
      }
    }
  }

  Future<MediaStream> _captureCameraStream({
    required bool frontCamera,
  }) async {
    final facingMode = frontCamera ? 'user' : 'environment';
    final baseVideoConstraints = <String, dynamic>{
      'width': <String, dynamic>{'ideal': 720},
      'height': <String, dynamic>{'ideal': 1280},
      'frameRate': <String, dynamic>{'ideal': 24, 'max': 30},
    };

    if (kIsWeb) {
      try {
        return await navigator.mediaDevices.getUserMedia(
          <String, dynamic>{
            'audio': false,
            'video': <String, dynamic>{
              ...baseVideoConstraints,
              'facingMode': <String, dynamic>{'exact': facingMode},
            },
          },
        );
      } catch (_) {
        // Не все браузеры поддерживают exact. Повторяем с мягким условием.
      }
    }

    return navigator.mediaDevices.getUserMedia(
      <String, dynamic>{
        'audio': false,
        'video': <String, dynamic>{
          ...baseVideoConstraints,
          'facingMode': <String, dynamic>{'ideal': facingMode},
        },
      },
    );
  }

  Future<void> _replaceWebCameraTrack({
    required bool frontCamera,
  }) async {
    final localStream = _localStream;
    final peerConnection = _peerConnection;
    if (localStream == null || peerConnection == null) return;

    final replacementStream = await _captureCameraStream(
      frontCamera: frontCamera,
    );
    final replacementTracks = replacementStream.getVideoTracks();
    if (replacementTracks.isEmpty) {
      await replacementStream.dispose();
      throw StateError('Браузер не вернул видеопоток');
    }

    final replacementTrack = replacementTracks.first;
    var replacedSenderTrack = false;
    final senders = await peerConnection.getSenders();
    for (final sender in senders) {
      if (sender.track?.kind == 'video') {
        await sender.replaceTrack(replacementTrack);
        replacedSenderTrack = true;
        break;
      }
    }

    if (!replacedSenderTrack) {
      final transceivers = await peerConnection.getTransceivers();
      for (final transceiver in transceivers) {
        if (transceiver.receiver.track?.kind == 'video') {
          await transceiver.sender.replaceTrack(replacementTrack);
          await transceiver.setDirection(TransceiverDirection.SendRecv);
          replacedSenderTrack = true;
          break;
        }
      }
    }

    if (!replacedSenderTrack) {
      await peerConnection.addTrack(replacementTrack, localStream);
    }

    final oldTracks = List<MediaStreamTrack>.of(
      localStream.getVideoTracks(),
    );
    for (final oldTrack in oldTracks) {
      oldTrack.stop();
      await localStream.removeTrack(oldTrack);
    }
    await localStream.addTrack(replacementTrack);

    final previousCameraStream = _cameraStream;
    _cameraStream = replacementStream;
    _usingFrontCamera = frontCamera;
    _localRenderer.srcObject = localStream;
    await previousCameraStream?.dispose();

    if (mounted) setState(() {});
  }

  void _showTransientMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message),
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 2),
        ),
      );
  }

  Future<void> _decline() async {
    await _stopRingSound();
    final callId = _callId;
    if (callId != null) {
      await CallService.setStatus(callId, 'declined');
    }
    await _disposeCall();
    _closeUi();
  }

  Future<void> _endCall() async {
    if (_ending) return;
    _ending = true;
    try {
      await _stopRingSound();
      final callId = _callId;
      if (callId != null) {
        await CallService.setStatus(
          callId,
          _isIncoming && !_accepted ? 'declined' : 'ended',
        );
        try {
          await _saveCallInChat(callId);
        } catch (_) {
          // История звонка не должна мешать закрытию самого звонка.
        }
      }
    } finally {
      await _disposeCall();
      _closeUi();
    }
  }

  Future<void> _saveCallInChat(String callId) async {
    final currentUser = FirebaseAuth.instance.currentUser;
    final call = widget.incomingCall;
    final callerUid = call?.callerUid ?? currentUser?.uid;
    if (currentUser == null || callerUid != currentUser.uid) return;

    await CallService.saveCallHistory(
      callId: callId,
      callerUid: currentUser.uid,
      receiverUid: widget.otherUid,
      type: widget.type,
      durationSeconds: _durationSeconds,
    );
  }

  Future<void> _closeWithoutUpdating() async {
    if (_ending) return;
    _ending = true;
    try {
      await _stopRingSound();
      final callId = _callId;
      if (callId != null) {
        try {
          await _saveCallInChat(callId);
        } catch (_) {
          // Второе устройство уже завершило звонок. Даже если историю
          // сохранить не удалось, экран звонка обязан закрыться.
        }
      }
    } finally {
      await _disposeCall();
      _closeUi();
    }
  }

  void _closeUi() {
    final onClosed = widget.onClosed;
    if (onClosed != null) {
      onClosed();
    } else if (mounted) {
      Navigator.maybePop(context);
    }
  }

  Future<void> _disposeCall() async {
    await _stopRingSound();
    _durationTimer?.cancel();
    await _candidateSubscription?.cancel();
    await _answerSubscription?.cancel();
    await _callSubscription?.cancel();
    await _statusSubscription?.cancel();
    for (final track in _localStream?.getTracks() ?? <MediaStreamTrack>[]) {
      track.stop();
    }
    await _localStream?.dispose();
    await _cameraStream?.dispose();
    await _remoteFallbackStream?.dispose();
    await _peerConnection?.close();
    _localRenderer.srcObject = null;
    _remoteRenderer.srcObject = null;
  }

  Future<void> _startRingSound() async {
    await _ringPlayer.setReleaseMode(ReleaseMode.loop);
    await _ringPlayer.setVolume(0.55);
    await _ringPlayer.play(AssetSource('sounds/call_ring.wav'));
  }

  Future<void> _stopRingSound() async {
    await _ringPlayer.stop();
  }

  void _showErrorAndClose(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
    _closeUi();
  }

  String get _durationText {
    final minutes = (_durationSeconds ~/ 60).toString().padLeft(2, '0');
    final seconds = (_durationSeconds % 60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }

  @override
  void dispose() {
    _disposeCall();
    _localRenderer.dispose();
    _remoteRenderer.dispose();
    _ringPlayer.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final photoUrl = widget.otherPhotoUrl.trim();
    if (_minimized) {
      return PopScope(
        canPop: false,
        child: Material(
          type: MaterialType.transparency,
          child: Stack(
            children: <Widget>[
              Positioned(
                top: MediaQuery.paddingOf(context).top + 10,
                right: 12,
                child: _MinimizedCallCard(
                  name: widget.otherName,
                  photoUrl: photoUrl,
                  status: _durationTimer == null ? _status : _durationText,
                  videoEnabled: _isVideoVisible,
                  onOpen: () => setState(() => _minimized = false),
                  onEnd: _endCall,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop && mounted) {
          setState(() => _minimized = true);
        }
      },
      child: Scaffold(
        backgroundColor: const Color(0xff06070E),
        body: Stack(
          fit: StackFit.expand,
          children: <Widget>[
            if (_remoteCameraEnabled && _remoteRenderer.srcObject != null)
              RTCVideoView(
                _remoteRenderer,
                objectFit: RTCVideoViewObjectFit.RTCVideoViewObjectFitCover,
              )
            else
              _CallBackground(photoUrl: photoUrl),
            if (_cameraEnabled)
              Positioned(
                right: 18,
                top: MediaQuery.paddingOf(context).top + 18,
                width: 112,
                height: 160,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(22),
                  child: RTCVideoView(
                    _localRenderer,
                    mirror: false,
                    objectFit:
                        RTCVideoViewObjectFit.RTCVideoViewObjectFitCover,
                  ),
                ),
              ),
            SafeArea(
              child: Column(
                children: <Widget>[
                  const Spacer(),
                  if (!_isVideoVisible) ...<Widget>[
                    CircleAvatar(
                      radius: 58,
                      backgroundColor: const Color(0xff272936),
                      backgroundImage:
                          photoUrl.isEmpty ? null : NetworkImage(photoUrl),
                      child: photoUrl.isEmpty
                          ? const Icon(
                              Icons.person_rounded,
                              size: 62,
                              color: Colors.white70,
                            )
                          : null,
                    ),
                    const SizedBox(height: 22),
                  ],
                  Text(
                    widget.otherName,
                    textAlign: TextAlign.center,
                    style: GoogleFonts.poppins(
                      fontSize: 28,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 7),
                  Text(
                    _durationTimer == null ? _status : _durationText,
                    style: GoogleFonts.poppins(
                      fontSize: 14,
                      color: Colors.white70,
                    ),
                  ),
                  const Spacer(),
                  if (_isIncoming && !_accepted)
                    _IncomingControls(
                      onDecline: _decline,
                      onAccept: _acceptIncomingCall,
                    )
                  else
                    _ActiveControls(
                      microphoneEnabled: _microphoneEnabled,
                      cameraEnabled: _cameraEnabled,
                      speakerEnabled: _speakerEnabled,
                      cameraBusy: _cameraOperationInProgress,
                      speakerBusy: _speakerOperationInProgress,
                      onMicrophone: _toggleMicrophone,
                      onCamera: _toggleCamera,
                      onSwitchCamera: _switchCamera,
                      onSpeaker: _toggleSpeaker,
                      onEnd: _endCall,
                    ),
                  const SizedBox(height: 24),
                ],
              ),
            ),
            Positioned(
              left: 10,
              top: MediaQuery.paddingOf(context).top + 6,
              child: IconButton.filledTonal(
                onPressed: () => setState(() => _minimized = true),
                icon: const Icon(Icons.keyboard_arrow_down_rounded, size: 30),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MinimizedCallCard extends StatelessWidget {
  const _MinimizedCallCard({
    required this.name,
    required this.photoUrl,
    required this.status,
    required this.videoEnabled,
    required this.onOpen,
    required this.onEnd,
  });

  final String name;
  final String photoUrl;
  final String status;
  final bool videoEnabled;
  final VoidCallback onOpen;
  final VoidCallback onEnd;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: const Color(0xff1B1D27),
      elevation: 14,
      shadowColor: Colors.black54,
      borderRadius: BorderRadius.circular(22),
      child: InkWell(
        onTap: onOpen,
        borderRadius: BorderRadius.circular(22),
        child: Container(
          width: 238,
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: Colors.white12),
          ),
          child: Row(
            children: <Widget>[
              CircleAvatar(
                radius: 21,
                backgroundColor: const Color(0xff303341),
                backgroundImage:
                    photoUrl.isEmpty ? null : NetworkImage(photoUrl),
                child: photoUrl.isEmpty
                    ? const Icon(Icons.person_rounded, color: Colors.white70)
                    : null,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                        fontSize: 14,
                      ),
                    ),
                    Text(
                      status,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Color(0xff55DE83),
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                videoEnabled
                    ? Icons.videocam_rounded
                    : Icons.call_rounded,
                color: const Color(0xff55DE83),
                size: 20,
              ),
              const SizedBox(width: 7),
              InkWell(
                onTap: onEnd,
                customBorder: const CircleBorder(),
                child: const CircleAvatar(
                  radius: 18,
                  backgroundColor: Color(0xffFF4F5E),
                  child: Icon(
                    Icons.call_end_rounded,
                    color: Colors.white,
                    size: 18,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CallBackground extends StatelessWidget {
  const _CallBackground({required this.photoUrl});

  final String photoUrl;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: <Color>[
            Color(0xff16112A),
            Color(0xff090B16),
            Color(0xff130A19),
          ],
        ),
      ),
      child: Stack(
        fit: StackFit.expand,
        children: <Widget>[
          if (photoUrl.isNotEmpty)
            Opacity(
              opacity: 0.14,
              child: Image.network(photoUrl, fit: BoxFit.cover),
            ),
          const DecoratedBox(
            decoration: BoxDecoration(
              gradient: RadialGradient(
                colors: <Color>[
                  Color(0x334F8CFF),
                  Color(0x224D153D),
                  Colors.transparent,
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _IncomingControls extends StatelessWidget {
  const _IncomingControls({
    required this.onDecline,
    required this.onAccept,
  });

  final VoidCallback onDecline;
  final VoidCallback onAccept;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: <Widget>[
        _RoundCallButton(
          color: const Color(0xffFF4F5E),
          icon: Icons.call_end_rounded,
          label: 'Отклонить',
          onTap: onDecline,
        ),
        _RoundCallButton(
          color: const Color(0xff43D66C),
          icon: Icons.call_rounded,
          label: 'Принять',
          onTap: onAccept,
        ),
      ],
    );
  }
}

class _ActiveControls extends StatelessWidget {
  const _ActiveControls({
    required this.microphoneEnabled,
    required this.cameraEnabled,
    required this.speakerEnabled,
    required this.cameraBusy,
    required this.speakerBusy,
    required this.onMicrophone,
    required this.onCamera,
    required this.onSwitchCamera,
    required this.onSpeaker,
    required this.onEnd,
  });

  final bool microphoneEnabled;
  final bool cameraEnabled;
  final bool speakerEnabled;
  final bool cameraBusy;
  final bool speakerBusy;
  final VoidCallback onMicrophone;
  final VoidCallback onCamera;
  final VoidCallback onSwitchCamera;
  final VoidCallback onSpeaker;
  final VoidCallback onEnd;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Wrap(
        alignment: WrapAlignment.center,
        spacing: 14,
        runSpacing: 14,
        children: <Widget>[
          _RoundCallButton(
            icon: microphoneEnabled
                ? Icons.mic_rounded
                : Icons.mic_off_rounded,
            label: microphoneEnabled ? 'Микрофон' : 'Выключен',
            active: !microphoneEnabled,
            onTap: onMicrophone,
          ),
          _RoundCallButton(
            icon: cameraBusy
                ? Icons.hourglass_top_rounded
                : cameraEnabled
                ? Icons.videocam_rounded
                : Icons.videocam_off_rounded,
            label: 'Камера',
            active: cameraEnabled,
            onTap: onCamera,
          ),
          if (cameraEnabled)
            _RoundCallButton(
              icon: Icons.cameraswitch_rounded,
              label: 'Повернуть',
              onTap: onSwitchCamera,
            ),
          _RoundCallButton(
            icon: speakerBusy
                ? Icons.hourglass_top_rounded
                : speakerEnabled
                ? Icons.volume_up_rounded
                : Icons.volume_down_rounded,
            label: 'Динамик',
            active: speakerEnabled,
            onTap: onSpeaker,
          ),
          _RoundCallButton(
            color: const Color(0xffFF4F5E),
            icon: Icons.call_end_rounded,
            label: 'Завершить',
            onTap: onEnd,
          ),
        ],
      ),
    );
  }
}

class _RoundCallButton extends StatelessWidget {
  const _RoundCallButton({
    required this.icon,
    required this.label,
    required this.onTap,
    this.color,
    this.active = false,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final Color? color;
  final bool active;

  @override
  Widget build(BuildContext context) {
    final background = color ??
        (active ? Colors.white : const Color(0xaa2A2D38));
    final foreground = active && color == null
        ? const Color(0xff171923)
        : Colors.white;

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: SizedBox(
        width: 76,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              width: 60,
              height: 60,
              decoration: BoxDecoration(
                color: background,
                shape: BoxShape.circle,
                boxShadow: const <BoxShadow>[
                  BoxShadow(
                    color: Color(0x33000000),
                    blurRadius: 16,
                    offset: Offset(0, 8),
                  ),
                ],
              ),
              child: Icon(icon, color: foreground, size: 28),
            ),
            const SizedBox(height: 7),
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white70, fontSize: 10),
            ),
          ],
        ),
      ),
    );
  }
}
