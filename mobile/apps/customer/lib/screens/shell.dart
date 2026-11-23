import 'package:flutter/material.dart';
import 'package:near_me_core/near_me_core.dart';
import '../ads.dart';
import '../app_state.dart';
import 'chats_screen.dart';
import 'home_screen.dart';
import 'near_me_screen.dart';
import 'profile_screen.dart';

/// Bottom navigation: Chats, Home, Near Me (center, prominent), Profile.
class Shell extends StatefulWidget {
  const Shell({super.key, required this.state});
  final AppState state;
  @override
  State<Shell> createState() => _ShellState();
}

class _ShellState extends State<Shell> {
  int _i = 2;
  @override
  void initState() { super.initState(); widget.state.startPresence(); }
  @override
  void dispose() { widget.state.stopPresence(); super.dispose(); }
  @override
  Widget build(BuildContext context) {
    final pages = [ChatsScreen(state: widget.state), HomeScreen(state: widget.state), NearMeScreen(state: widget.state), ProfileScreen(state: widget.state)];
    return Scaffold(
      body: SafeArea(child: IndexedStack(index: _i, children: pages)),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _i,
        onDestinationSelected: (v) { if (v != _i) AdService.instance.maybeShowInterstitial(fromScreen: const ['chat_list', 'home', 'near_me', 'profile'][_i]); setState(() => _i = v); },
        destinations: [
          for (final (i, e) in [('chat', widget.state.builder.tab('chats')), ('home', widget.state.builder.tab('home')), ('near', widget.state.builder.tab('near')), ('user', widget.state.builder.tab('profile'))].indexed)
            NavigationDestination(icon: NmIcon(e.$1, size: 34, active: false), selectedIcon: NmIcon(e.$1, size: i == 2 ? 46 : 40), label: e.$2),
        ],
      ),
    );
  }
}
