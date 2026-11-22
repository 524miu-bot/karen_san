import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'l10n.dart';

/// 使い方の説明（チュートリアル）。初めてログインしたときと、設定の「使い方を見る」から開く。
class TutorialPage extends StatefulWidget {
  const TutorialPage({super.key});

  static const _seenKey = 'tutorial_seen_v1';

  static Future<void> show(BuildContext context) => Navigator.of(context).push(
    MaterialPageRoute<void>(
      fullscreenDialog: true,
      builder: (_) => const TutorialPage(),
    ),
  );

  /// まだ見ていなければ開く（開いた時点で「見た」にする）。
  static Future<void> showOnce(BuildContext context) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (prefs.getBool(_seenKey) ?? false) return;
      await prefs.setBool(_seenKey, true);
    } catch (_) {
      return; // 覚えておけない環境では毎回出さない
    }
    if (context.mounted) await show(context);
  }

  @override
  State<TutorialPage> createState() => _TutorialPageState();
}

class _Step {
  const _Step(this.icon, this.title, this.body);
  final IconData? icon; // null ならカレンさんの絵
  final String title;
  final String body;
}

class _TutorialPageState extends State<TutorialPage> {
  final _pager = PageController();
  int _page = 0;

  @override
  void dispose() {
    _pager.dispose();
    super.dispose();
  }

  List<_Step> _steps(BuildContext context) {
    final l10n = context.l10n;
    return [
      _Step(null, l10n.tutorialWelcomeTitle, l10n.tutorialWelcomeBody),
      _Step(Icons.add, l10n.tutorialAddTitle, l10n.tutorialAddBody),
      _Step(
        Icons.photo_camera_outlined,
        l10n.tutorialPhotoTitle,
        l10n.tutorialPhotoBody,
      ),
      _Step(
        Icons.lock_outline,
        l10n.tutorialCalendarsTitle,
        l10n.tutorialCalendarsBody,
      ),
      _Step(Icons.repeat, l10n.tutorialRoutineTitle, l10n.tutorialRoutineBody),
      _Step(
        Icons.group_add_outlined,
        l10n.tutorialInviteTitle,
        l10n.tutorialInviteBody,
      ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final steps = _steps(context);
    final last = _page == steps.length - 1;
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: Column(
              children: [
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: Text(last ? l10n.close : l10n.tutorialSkip),
                  ),
                ),
                Expanded(
                  child: PageView(
                    controller: _pager,
                    onPageChanged: (i) => setState(() => _page = i),
                    children: [
                      for (final s in steps)
                        SingleChildScrollView(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 24,
                            vertical: 24,
                          ),
                          child: Column(
                            children: [
                              if (s.icon == null)
                                const CircleAvatar(
                                  radius: 88,
                                  backgroundImage: AssetImage(
                                    'assets/branding/karen.png',
                                  ),
                                )
                              else
                                CircleAvatar(
                                  radius: 72,
                                  backgroundColor: scheme.primaryContainer,
                                  foregroundColor: scheme.onPrimaryContainer,
                                  child: Icon(s.icon, size: 72),
                                ),
                              const SizedBox(height: 32),
                              Text(
                                s.title,
                                textAlign: TextAlign.center,
                                style: Theme.of(context)
                                    .textTheme
                                    .headlineSmall,
                              ),
                              const SizedBox(height: 16),
                              Text(
                                s.body,
                                textAlign: TextAlign.center,
                                style: Theme.of(context).textTheme.bodyLarge
                                    ?.copyWith(height: 1.6),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    for (var i = 0; i < steps.length; i++)
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        margin: const EdgeInsets.all(4),
                        width: i == _page ? 20 : 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color: i == _page
                              ? scheme.primary
                              : scheme.outlineVariant,
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                  ],
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
                  child: Row(
                    children: [
                      if (_page > 0)
                        TextButton(
                          onPressed: () => _pager.previousPage(
                            duration: const Duration(milliseconds: 250),
                            curve: Curves.easeOut,
                          ),
                          child: Text(l10n.tutorialBack),
                        ),
                      const Spacer(),
                      FilledButton(
                        onPressed: last
                            ? () => Navigator.of(context).pop()
                            : () => _pager.nextPage(
                                duration: const Duration(milliseconds: 250),
                                curve: Curves.easeOut,
                              ),
                        child: Text(
                          last ? l10n.tutorialStart : l10n.tutorialNext,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
