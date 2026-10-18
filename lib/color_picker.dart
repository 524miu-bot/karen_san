import 'package:flutter/material.dart';

import 'l10n.dart';
import 'models.dart';

/// 予定の帯に白い文字を載せても読めるよう、明るさの上限を決めておく。
const _maxLightness = 0.55;

/// 用意した 8 色に加えて、9 つ目で好きな色を選べる並び。
class ColorChoices extends StatelessWidget {
  const ColorChoices({
    super.key,
    required this.selected,
    required this.onSelected,
  });

  final Color selected;
  final ValueChanged<Color> onSelected;

  bool _same(Color a, Color b) => a.toARGB32() == b.toARGB32();

  Future<void> _pickCustom(BuildContext context) async {
    final color = await showDialog<Color>(
      context: context,
      builder: (_) => _CustomColorDialog(initial: selected),
    );
    if (color != null) onSelected(color);
  }

  @override
  Widget build(BuildContext context) {
    final isCustom = !memberPalette.any((c) => _same(c, selected));
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final c in memberPalette)
          _Swatch(
            color: c,
            selected: _same(c, selected),
            onTap: () => onSelected(c),
          ),
        // 9 つ目：自由な色。選んでいる色がカスタムならその色で表示する
        Tooltip(
          message: context.l10n.customColor,
          child: InkWell(
            customBorder: const CircleBorder(),
            onTap: () => _pickCustom(context),
            child: Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isCustom ? selected : null,
                gradient: isCustom
                    ? null
                    : const SweepGradient(
                        colors: [
                          Colors.red,
                          Colors.yellow,
                          Colors.green,
                          Colors.cyan,
                          Colors.blue,
                          Colors.purple,
                          Colors.red,
                        ],
                      ),
              ),
              child: Icon(
                isCustom ? Icons.check : Icons.add,
                color: Colors.white,
                size: 18,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _Swatch extends StatelessWidget {
  const _Swatch({
    required this.color,
    required this.selected,
    required this.onTap,
  });

  final Color color;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      customBorder: const CircleBorder(),
      onTap: onTap,
      child: CircleAvatar(
        radius: 16,
        backgroundColor: color,
        child: selected
            ? const Icon(Icons.check, color: Colors.white, size: 18)
            : null,
      ),
    );
  }
}

/// 色合いと明るさのスライダーで色を作るダイアログ。
class _CustomColorDialog extends StatefulWidget {
  const _CustomColorDialog({required this.initial});
  final Color initial;

  @override
  State<_CustomColorDialog> createState() => _CustomColorDialogState();
}

class _CustomColorDialogState extends State<_CustomColorDialog> {
  late double _hue;
  late double _lightness;

  @override
  void initState() {
    super.initState();
    final hsl = HSLColor.fromColor(widget.initial);
    _hue = hsl.hue;
    _lightness = hsl.lightness.clamp(0.2, _maxLightness);
  }

  Color get _color => HSLColor.fromAHSL(1, _hue, 0.7, _lightness).toColor();

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return AlertDialog(
      title: Text(l10n.customColor),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // 実際の予定の帯と同じ見た目で確認できるようにする
          Container(
            height: 40,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: _color,
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              l10n.colorPreview,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          const SizedBox(height: 16),
          Text(l10n.hue),
          Slider(
            value: _hue,
            max: 359,
            activeColor: _color,
            onChanged: (v) => setState(() => _hue = v),
          ),
          Text(l10n.brightness),
          Slider(
            value: _lightness,
            min: 0.2,
            max: _maxLightness,
            activeColor: _color,
            onChanged: (v) => setState(() => _lightness = v),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(l10n.cancel),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context, _color),
          child: Text(l10n.select),
        ),
      ],
    );
  }
}
