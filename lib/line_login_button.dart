import 'package:flutter/material.dart';

import 'l10n.dart';

/// LINE ログインボタン。
///
/// LINE ログインボタン デザインガイドラインに沿っている：
/// https://developers.line.biz/ja/docs/line-login/login-button/
/// - LINE アイコンは公式画像（assets/line/）をそのまま使う
/// - 基本色 #06C755、マウスオーバーは黒 10%、押下中は黒 30% を重ねる
/// - アイコンとテキストの間に縦線（黒 8%）
/// - 無効時は白地・枠線 #E5E5E5（60%）・文字 #1E1E1E（20%）
class LineLoginButton extends StatefulWidget {
  const LineLoginButton({super.key, required this.onPressed});

  /// null なら無効表示。
  final VoidCallback? onPressed;

  static const height = 44.0;
  static const _green = Color(0xFF06C755);

  @override
  State<LineLoginButton> createState() => _LineLoginButtonState();
}

class _LineLoginButtonState extends State<LineLoginButton> {
  bool _hovered = false;
  bool _pressed = false;

  bool get _enabled => widget.onPressed != null;

  @override
  Widget build(BuildContext context) {
    final String icon;
    final Color background;
    final Color? overlay;
    if (!_enabled) {
      icon = 'assets/line/btn_disable.png';
      background = Colors.white;
      overlay = null;
    } else if (_pressed) {
      icon = 'assets/line/btn_press.png';
      background = LineLoginButton._green;
      overlay = Colors.black.withValues(alpha: 0.3);
    } else if (_hovered) {
      icon = 'assets/line/btn_hover.png';
      background = LineLoginButton._green;
      overlay = Colors.black.withValues(alpha: 0.1);
    } else {
      icon = 'assets/line/btn_base.png';
      background = LineLoginButton._green;
      overlay = null;
    }
    final foreground = _enabled
        ? Colors.white
        : const Color(0xFF1E1E1E).withValues(alpha: 0.2);
    final divider = _enabled
        ? Colors.black.withValues(alpha: 0.08)
        : const Color(0xFFE5E5E5).withValues(alpha: 0.6);

    return Semantics(
      button: true,
      enabled: _enabled,
      label: context.l10n.loginLine,
      child: MouseRegion(
        cursor: _enabled ? SystemMouseCursors.click : SystemMouseCursors.basic,
        onEnter: (_) => setState(() => _hovered = true),
        onExit: (_) => setState(() {
          _hovered = false;
          _pressed = false;
        }),
        child: GestureDetector(
          onTapDown: _enabled ? (_) => setState(() => _pressed = true) : null,
          onTapCancel: () => setState(() => _pressed = false),
          onTapUp: _enabled ? (_) => setState(() => _pressed = false) : null,
          onTap: widget.onPressed,
          child: Container(
            height: LineLoginButton.height,
            clipBehavior: Clip.antiAlias,
            decoration: BoxDecoration(
              color: background,
              borderRadius: BorderRadius.circular(6),
              border: _enabled
                  ? null
                  : Border.all(
                      color: const Color(0xFFE5E5E5).withValues(alpha: 0.6),
                    ),
            ),
            // 重ね順：基本色 → マウスオーバー/押下の黒 → 縦線・アイコン・文字
            child: Stack(
              fit: StackFit.expand,
              children: [
                if (overlay != null) ColoredBox(color: overlay),
                Row(
                  children: [
                    Image.asset(
                      icon,
                      width: LineLoginButton.height,
                      height: LineLoginButton.height,
                      excludeFromSemantics: true,
                    ),
                    Container(width: 1, color: divider),
                    Expanded(
                      child: Padding(
                        // 文字の左右の余白はアイコンの吹き出しの幅以上
                        padding: const EdgeInsets.symmetric(horizontal: 32),
                        child: Center(
                          child: Text(
                            context.l10n.loginLine,
                            maxLines: 1,
                            softWrap: false,
                            overflow: TextOverflow.fade,
                            style: TextStyle(
                              color: foreground,
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
