import 'package:flutter/material.dart';

import '../state.dart';
import '../theme.dart';
import '../widgets/common.dart';

/// Экран «Список изменений к сборке».
///
/// По просьбе пользователя — как в заметках: никакой шапки-контейнера,
/// всё безгранично и прозрачно, курсор сразу в тексте. Единственный
/// UI-элемент поверх текста — плавающая кнопка «назад» в левом
/// верхнем углу (полупрозрачный кружок, не сплошная плашка).
///
/// При переходе на новую строку (Enter) перед курсором автоматически
/// подставляется маркер «• », как в списке. Текст хранится в
/// [AppState.changelog] и никуда, кроме этого локального стейта,
/// не отправляется — на GitHub не пушится.
class ChangelogScreen extends StatefulWidget {
  const ChangelogScreen({super.key});
  @override
  State<ChangelogScreen> createState() => _ChangelogScreenState();
}

class _ChangelogScreenState extends State<ChangelogScreen> {
  static const _bullet = '• ';

  late final TextEditingController _ctrl;
  final _focus = FocusNode();
  String _prevText = '';
  bool _guard = false;

  @override
  void initState() {
    super.initState();
    final existing = AppState.I.changelog;
    // Если список ещё пуст — сразу подставляем первый маркер, чтобы
    // экран выглядел как начатый список, а не пустая страница.
    final initial = existing.isEmpty ? _bullet : existing;
    _ctrl = TextEditingController(text: initial);
    _ctrl.selection = TextSelection.collapsed(offset: initial.length);
    _prevText = initial;
    _ctrl.addListener(_onChanged);
  }

  @override
  void dispose() {
    AppState.I.changelog = _ctrl.text == _bullet ? '' : _ctrl.text;
    _ctrl.removeListener(_onChanged);
    _ctrl.dispose();
    _focus.dispose();
    super.dispose();
  }

  void _onChanged() {
    if (_guard) return;
    final text = _ctrl.text;
    final sel = _ctrl.selection;
    final grew = text.length > _prevText.length;
    if (grew &&
        sel.isCollapsed &&
        sel.baseOffset > 0 &&
        sel.baseOffset <= text.length &&
        text[sel.baseOffset - 1] == '\n') {
      _guard = true;
      final newText =
          '${text.substring(0, sel.baseOffset)}$_bullet${text.substring(sel.baseOffset)}';
      _ctrl.value = TextEditingValue(
        text: newText,
        selection:
            TextSelection.collapsed(offset: sel.baseOffset + _bullet.length),
      );
      _prevText = newText;
      _guard = false;
      return;
    }
    _prevText = text;
  }

  @override
  Widget build(BuildContext context) {
    final pal = context.pal;
    final top = MediaQuery.of(context).padding.top;
    return Scaffold(
      backgroundColor: pal.bg,
      // Никакой AppBar/шапки — текст начинается прямо под системной
      // статус-баром, экран прозрачный и «безграничный».
      body: Stack(
        children: [
          Positioned.fill(
            child: Padding(
              padding: EdgeInsets.fromLTRB(20, top + 64, 20, 24),
              child: TextField(
                controller: _ctrl,
                focusNode: _focus,
                autofocus: true,
                maxLines: null,
                expands: true,
                textAlignVertical: TextAlignVertical.top,
                keyboardType: TextInputType.multiline,
                cursorColor: AppColors.accent,
                style: TextStyle(
                  fontSize: 16,
                  height: 1.5,
                  color: pal.text,
                ),
                decoration: InputDecoration(
                  border: InputBorder.none,
                  enabledBorder: InputBorder.none,
                  focusedBorder: InputBorder.none,
                  filled: false,
                  hintText: 'Что изменилось в этой сборке…',
                  hintStyle: TextStyle(
                    fontSize: 16,
                    height: 1.5,
                    color: pal.sub,
                  ),
                  contentPadding: EdgeInsets.zero,
                  isCollapsed: true,
                ),
              ),
            ),
          ),
          Positioned(
            top: top + 10,
            left: 12,
            child: IconBtn(
              icon: 'solar:alt-arrow-left-linear',
              onTap: () => Navigator.of(context).maybePop(),
            ),
          ),
          Positioned(
            top: top + 10,
            right: 12,
            child: IconBtn(
              icon: 'solar:check-circle-bold',
              color: AppColors.accent,
              onTap: () => Navigator.of(context).maybePop(),
            ),
          ),
        ],
      ),
    );
  }
}
