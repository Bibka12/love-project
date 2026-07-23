import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../services/friends_service.dart';

class FindPeopleScreen extends StatefulWidget {
  const FindPeopleScreen({super.key});

  @override
  State<FindPeopleScreen> createState() => _FindPeopleScreenState();
}

class _FindPeopleScreenState extends State<FindPeopleScreen> {
  final TextEditingController _searchController = TextEditingController();

  Timer? _debounce;

  bool _isSearching = false;
  String? _errorMessage;

  List<AppUserProfile> _users = <AppUserProfile>[];

  User? get _currentUser => FirebaseAuth.instance.currentUser;

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  void _onSearchChanged(String value) {
    setState(() {});

    _debounce?.cancel();

    _debounce = Timer(const Duration(milliseconds: 450), () {
      _searchUsers(value);
    });
  }

  Future<void> _searchUsers(String value) async {
    final user = _currentUser;
    final query = value.trim();

    if (user == null) {
      return;
    }

    if (query.isEmpty) {
      if (!mounted) return;

      setState(() {
        _users = <AppUserProfile>[];
        _errorMessage = null;
        _isSearching = false;
      });

      return;
    }

    setState(() {
      _isSearching = true;
      _errorMessage = null;
    });

    try {
      final result = await FriendsService.searchUsers(
        query: query,
        currentUid: user.uid,
      );

      if (!mounted) return;

      setState(() {
        _users = result;
      });
    } catch (error) {
      if (!mounted) return;

      setState(() {
        _errorMessage = _friendlyError(error);
        _users = <AppUserProfile>[];
      });
    } finally {
      if (mounted) {
        setState(() {
          _isSearching = false;
        });
      }
    }
  }

  String _friendlyError(Object error) {
    final text = error.toString();

    if (text.contains('permission-denied')) {
      return 'Firestore запретил загрузку данных. Проверь правила Firestore.';
    }

    if (text.contains('failed-precondition')) {
      return 'Для этого поиска нужен индекс Firestore. '
          'Посмотри ссылку в консоли Flutter.';
    }

    if (text.contains('network')) {
      return 'Проверь подключение к интернету.';
    }

    return 'Не удалось выполнить поиск.\n$error';
  }

  void _clearSearch() {
    _debounce?.cancel();
    _searchController.clear();

    setState(() {
      _users = <AppUserProfile>[];
      _errorMessage = null;
      _isSearching = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final currentUser = _currentUser;

    return Scaffold(
      backgroundColor: const Color(0xff070810),
      appBar: AppBar(
        backgroundColor: const Color(0xff070810),
        foregroundColor: Colors.white,
        elevation: 0,
        title: Text(
          'Найти людей',
          style: GoogleFonts.poppins(fontWeight: FontWeight.bold),
        ),
      ),
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: <Color>[
              Color(0xff070810),
              Color(0xff17101F),
              Color(0xff2A1732),
            ],
          ),
        ),
        child: SafeArea(
          top: false,
          child: Column(
            children: <Widget>[
              Padding(
                padding: const EdgeInsets.fromLTRB(18, 16, 18, 14),
                child: TextField(
                  controller: _searchController,
                  autofocus: true,
                  onChanged: _onSearchChanged,
                  onSubmitted: _searchUsers,
                  textInputAction: TextInputAction.search,
                  style: GoogleFonts.poppins(color: Colors.white),
                  decoration: InputDecoration(
                    hintText: 'Введите имя пользователя',
                    hintStyle: GoogleFonts.poppins(color: Colors.white38),
                    prefixIcon: const Icon(
                      Icons.search_rounded,
                      color: Colors.pinkAccent,
                    ),
                    suffixIcon: _searchController.text.isEmpty
                        ? null
                        : IconButton(
                            onPressed: _clearSearch,
                            icon: const Icon(
                              Icons.close_rounded,
                              color: Colors.white54,
                            ),
                          ),
                    filled: true,
                    fillColor: Colors.white.withValues(alpha: 0.06),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(18),
                      borderSide: BorderSide.none,
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(18),
                      borderSide: BorderSide(
                        color: Colors.white.withValues(alpha: 0.08),
                      ),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(18),
                      borderSide: const BorderSide(color: Colors.pinkAccent),
                    ),
                  ),
                ),
              ),
              if (_isSearching)
                const LinearProgressIndicator(
                  color: Colors.pinkAccent,
                  backgroundColor: Colors.transparent,
                ),
              Expanded(child: _buildBody(currentUser)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBody(User? currentUser) {
    if (currentUser == null) {
      return const _CenteredMessage(
        icon: Icons.lock_outline_rounded,
        text: 'Сначала войди в аккаунт.',
      );
    }

    if (_errorMessage != null) {
      return _CenteredMessage(
        icon: Icons.error_outline_rounded,
        text: _errorMessage!,
        iconColor: Colors.redAccent,
      );
    }

    if (_searchController.text.trim().isEmpty) {
      return const _CenteredMessage(
        icon: Icons.person_search_rounded,
        text: 'Начни вводить имя человека.',
      );
    }

    if (!_isSearching && _users.isEmpty) {
      return const _CenteredMessage(
        icon: Icons.search_off_rounded,
        text: 'Никого не нашли.',
      );
    }

    return ListView.separated(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(18, 8, 18, 30),
      itemCount: _users.length,
      separatorBuilder: (_, __) {
        return const SizedBox(height: 12);
      },
      itemBuilder: (context, index) {
        final person = _users[index];

        return _PersonCard(
          key: ValueKey(person.uid),
          currentUser: currentUser,
          person: person,
        );
      },
    );
  }
}

class _PersonCard extends StatefulWidget {
  const _PersonCard({
    super.key,
    required this.currentUser,
    required this.person,
  });

  final User currentUser;
  final AppUserProfile person;

  @override
  State<_PersonCard> createState() => _PersonCardState();
}

class _PersonCardState extends State<_PersonCard> {
  bool _isSending = false;
  int _stateVersion = 0;

  Future<FriendshipState> _loadFriendshipState() async {
    return FriendsService.getFriendshipState(
      currentUid: widget.currentUser.uid,
      otherUid: widget.person.uid,
    ).timeout(
      const Duration(seconds: 15),
      onTimeout: () {
        throw TimeoutException(
          'Проверка статуса заняла слишком много времени.',
        );
      },
    );
  }

  Future<void> _sendFriendRequest() async {
    if (_isSending) {
      return;
    }

    setState(() {
      _isSending = true;
    });

    try {
      await FriendsService.sendFriendRequest(
        currentUser: widget.currentUser,
        receiver: widget.person,
      );

      if (!mounted) return;

      setState(() {
        _stateVersion++;
      });

      _showMessage('Заявка отправлена.');
    } catch (error) {
      if (!mounted) return;

      _showMessage(_cleanError(error), isError: true);

      setState(() {
        _stateVersion++;
      });
    } finally {
      if (mounted) {
        setState(() {
          _isSending = false;
        });
      }
    }
  }

  String _cleanError(Object error) {
    final text = error
        .toString()
        .replaceFirst('Bad state: ', '')
        .replaceFirst('Exception: ', '');

    if (text.contains('permission-denied')) {
      return 'Firestore запретил действие. Проверь правила.';
    }

    if (text.contains('TimeoutException')) {
      return 'Сервер слишком долго отвечает. Попробуй ещё раз.';
    }

    return text;
  }

  void _showMessage(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message),
          behavior: SnackBarBehavior.floating,
          backgroundColor: isError ? Colors.redAccent : const Color(0xff21172A),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
      );
  }

  void _retryState() {
    setState(() {
      _stateVersion++;
    });
  }

  @override
  Widget build(BuildContext context) {
    final person = widget.person;
    final hasPhoto = person.photoUrl.trim().isNotEmpty;

    return Container(
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Row(
        children: <Widget>[
          CircleAvatar(
            radius: 27,
            backgroundColor: const Color(0xff28152F),
            backgroundImage: hasPhoto ? NetworkImage(person.photoUrl) : null,
            child: hasPhoto
                ? null
                : const Icon(
                    Icons.person_rounded,
                    color: Colors.white,
                    size: 30,
                  ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  person.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.poppins(
                    color: Colors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                if (person.status.trim().isNotEmpty) ...<Widget>[
                  const SizedBox(height: 3),
                  Text(
                    person.status,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.poppins(
                      color: Colors.pinkAccent,
                      fontSize: 12,
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 10),
          FutureBuilder<FriendshipState>(
            key: ValueKey('${person.uid}-$_stateVersion'),
            future: _loadFriendshipState(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const SizedBox(
                  width: 40,
                  height: 40,
                  child: Center(
                    child: SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.pinkAccent,
                      ),
                    ),
                  ),
                );
              }

              if (snapshot.hasError) {
                return IconButton(
                  onPressed: _retryState,
                  tooltip: 'Повторить проверку',
                  icon: const Icon(
                    Icons.refresh_rounded,
                    color: Colors.redAccent,
                  ),
                );
              }

              final state = snapshot.data ?? FriendshipState.none;

              switch (state) {
                case FriendshipState.friends:
                  return const _StateChip(
                    icon: Icons.check_rounded,
                    text: 'Друзья',
                    color: Color(0xff65D68A),
                  );

                case FriendshipState.outgoingPending:
                  return const _StateChip(
                    icon: Icons.schedule_rounded,
                    text: 'Отправлено',
                    color: Color(0xffB99AFF),
                  );

                case FriendshipState.incomingPending:
                  return const _StateChip(
                    icon: Icons.mark_email_unread_rounded,
                    text: 'В заявках',
                    color: Colors.pinkAccent,
                  );

                case FriendshipState.none:
                  return SizedBox(
                    width: 46,
                    height: 42,
                    child: ElevatedButton(
                      onPressed: _isSending ? null : _sendFriendRequest,
                      style: ElevatedButton.styleFrom(
                        padding: EdgeInsets.zero,
                        backgroundColor: Colors.pinkAccent,
                        foregroundColor: Colors.white,
                        disabledBackgroundColor: Colors.pinkAccent.withValues(
                          alpha: 0.35,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      child: _isSending
                          ? const SizedBox(
                              width: 19,
                              height: 19,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Icon(
                              Icons.person_add_alt_1_rounded,
                              size: 20,
                            ),
                    ),
                  );
              }
            },
          ),
        ],
      ),
    );
  }
}

class _StateChip extends StatelessWidget {
  const _StateChip({
    required this.icon,
    required this.text,
    required this.color,
  });

  final IconData icon;
  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Icon(icon, color: color, size: 15),
          const SizedBox(width: 5),
          Text(
            text,
            style: GoogleFonts.poppins(
              color: color,
              fontSize: 10,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _CenteredMessage extends StatelessWidget {
  const _CenteredMessage({
    required this.icon,
    required this.text,
    this.iconColor = Colors.white24,
  });

  final IconData icon;
  final String text;
  final Color iconColor;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(30),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Icon(icon, color: iconColor, size: 64),
            const SizedBox(height: 15),
            Text(
              text,
              textAlign: TextAlign.center,
              style: GoogleFonts.poppins(color: Colors.white54, fontSize: 14),
            ),
          ],
        ),
      ),
    );
  }
}
