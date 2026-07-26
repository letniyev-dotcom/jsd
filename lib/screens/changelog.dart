import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../iconify.dart';
import '../state.dart';
import '../theme.dart';

/// Экран «Список изменений к сборке».
///
/// Как в заметках: никакой непрозрачной шапки и нижней плашки —
/// текст уходит под плавающие кнопки и под край клавиатуры, контент
/// всегда виден. При Enter автоматически подставляется «• ».
///
/// Упоминания багов: ввод `#` открывает компактный пикер; выбранный
/// баг вставляется как `#n1234` и подсвечивается акцентом. Текст
/// хранится в [AppState.changelog] и при пуше дописывается в тело
/// commit-message — поэтому виден в открытой сборке (run detail).
class ChangelogScreen extends StatefulWidget {
  const ChangelogScreen({super.key});
  @override
  State<ChangelogScreen> createState() => _ChangelogScreenState();
}

class _ChangelogScreenState extends State<ChangelogScreen> {
  static const _bullet = '• ';

  /// Маркер упоминания в тексте: `#n1234` (полный id бага).
  static final _mentionRe = RegExp(r'#n\d{4}');

  late final _MentionController _ctrl;
  final _focus = FocusNode();
  String _prevText = '';
  bool _guard = false;

  /// Активный запрос после `#` (без самой решётки). null — пикер скрыт.
  String? _mentionQuery;
  /// Смещение курсора, на котором стоит `#` (начало упоминания).
  int _mentionStart = -1;

  @override
  void initState() {
    super.initState();
    final existing = AppState.I.changelog;
    final initial = existing.isEmpty ? _bullet : existing;
    _ctrl = _MentionController(text: initial);
    _ctrl.selection = TextSelection.collapsed(offset: initial.length);
    _prevText = initial;
    _ctrl.addListener(_onChanged);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _focus.requestFocus();
    });
  }

  @override
  void dispose() {
    final t = _ctrl.text;
    AppState.I.changelog = (t == _bullet || t.trim().isEmpty) ? '' : t;
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

    // Авто-буллет при Enter.
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
      _updateMentionState(newText, sel.baseOffset + _bullet.length);
      return;
    }

    _prevText = text;
    if (sel.isCollapsed) {
      _updateMentionState(text, sel.baseOffset);
    } else {
      if (_mentionQuery != null) setState(() => _mentionQuery = null);
    }
  }

  /// Ищем активный `#query` слева от курсора (без пробелов/переносов).
  void _updateMentionState(String text, int cursor) {
    if (cursor < 0 || cursor > text.length) {
      if (_mentionQuery != null) setState(() => _mentionQuery = null);
      return;
    }
    var i = cursor - 1;
    while (i >= 0) {
      final ch = text[i];
      if (ch == '#') break;
      if (ch == ' ' || ch == '\n' || ch == '\t' || ch == '•') {
        i = -1;
        break;
      }
      i--;
    }
    if (i < 0 || text[i] != '#') {
      if (_mentionQuery != null) setState(() => _mentionQuery = null);
      return;
    }
    final token = text.substring(i, cursor);
    // Уже завершённый `#n1234` — пикер не нужен.
    if (_mentionRe.hasMatch(token) && token.length >= 6) {
      if (_mentionQuery != null) setState(() => _mentionQuery = null);
      return;
    }
    final query = token.substring(1);
    setState(() {
      _mentionStart = i;
      _mentionQuery = query;
    });
  }

  List<BugItem> _filteredBugs() {
    final q = (_mentionQuery ?? '').toLowerCase();
    final all = AppState.I.bugs;
    if (q.isEmpty) return all.take(8).toList();
    return all
        .where((b) {
          final id = b.id.toLowerCase();
          final title = b.title.toLowerCase();
          final short = id.length >= 4 ? id.substring(id.length - 4) : id;
          return id.contains(q) ||
              short.contains(q) ||
              title.contains(q) ||
              '#$id'.contains(q) ||
              '#$short'.contains(q);
        })
        .take(8)
        .toList();
  }

  void _insertMention(BugItem bug) {
    final text = _ctrl.text;
    final cursor = _ctrl.selection.baseOffset.clamp(0, text.length);
    if (_mentionStart < 0 || _mentionStart > cursor) return;
    final mention = '#${bug.id}';
    final newText =
        '${text.substring(0, _mentionStart)}$mention ${text.substring(cursor)}';
    final newCursor = _mentionStart + mention.length + 1;
    _guard = true;
    _ctrl.value = TextEditingValue(
      text: newText,
      selection: TextSelection.collapsed(offset: newCursor),
    );
    _prevText = newText;
    _guard = false;
    HapticFeedback.selectionClick();
    setState(() => _mentionQuery = null);
  }


  List<BugItem> _mentionedBugs() {
    final ids = _MentionController._re
        .allMatches(_ctrl.text)
        .map((m) => m.group(0)!.substring(1))
        .toSet();
    if (ids.isEmpty) return const [];
    final byId = {for (final b in AppState.I.bugs) b.id: b};
    return [
      for (final id in ids)
        if (byId.containsKey(id)) byId[id]!,
    ];
  }

  void _removeMention(BugItem bug) {
    final token = '#${bug.id}';
    var text = _ctrl.text;
    // Удаляем все вхождения токена (с возможным пробелом после).
    text = text.replaceAll('$token ', '');
    text = text.replaceAll(token, '');
    _guard = true;
    final cursor = _ctrl.selection.baseOffset.clamp(0, text.length);
    _ctrl.value = TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: cursor.clamp(0, text.length)),
    );
    _prevText = text;
    _guard = false;
    setState(() {});
  }

  void _saveAndClose() {
    final t = _ctrl.text;
    AppState.I.changelog = (t == _bullet || t.trim().isEmpty) ? '' : t;
    Navigator.of(context).maybePop();
  }

  @override
  Widget build(BuildContext context) {
    final pal = context.pal;
    final mq = MediaQuery.of(context);
    final top = mq.padding.top;
    final bottomSafe = mq.padding.bottom;
    final bugs = _mentionQuery != null ? _filteredBugs() : const <BugItem>[];
    final mentioned = _mentionedBugs();
    // Доп. место под ряд плашек упомянутых багов.
    final topPad = top + 56.0 + (mentioned.isNotEmpty && _mentionQuery == null ? 36.0 : 0.0);

    // Текст занимает ВЕСЬ экран. Никаких цветных «плашек» сверху/снизу —
    // только прозрачный Stack. contentPadding даёт отступ под кнопки;
    // при скролле текст уходит под них (шапка визуально прозрачная).
    return Scaffold(
      backgroundColor: pal.bg,
      resizeToAvoidBottomInset: true,
      body: Stack(
        children: [
          Positioned.fill(
            child: TextField(
              controller: _ctrl,
              focusNode: _focus,
              autofocus: true,
              maxLines: null,
              expands: true,
              textAlignVertical: TextAlignVertical.top,
              keyboardType: TextInputType.multiline,
              textInputAction: TextInputAction.newline,
              cursorColor: AppColors.accent,
              style: TextStyle(
                fontSize: 16,
                height: 1.5,
                color: pal.text,
              ),
              scrollPadding: EdgeInsets.fromLTRB(20, topPad, 20, 24),
              decoration: InputDecoration(
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                disabledBorder: InputBorder.none,
                errorBorder: InputBorder.none,
                focusedErrorBorder: InputBorder.none,
                filled: false,
                fillColor: Colors.transparent,
                hoverColor: Colors.transparent,
                focusColor: Colors.transparent,
                hintText: 'Что изменилось в этой сборке…\n# — упомянуть баг',
                hintStyle: TextStyle(
                  fontSize: 16,
                  height: 1.5,
                  color: pal.sub,
                ),
                contentPadding: EdgeInsets.fromLTRB(
                  20,
                  topPad,
                  20,
                  math.max(24.0, bottomSafe + 12),
                ),
                isCollapsed: false,
              ),
            ),
          ),

          // Прозрачная верхняя зона: только кнопки, без фона-плашки.
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: SafeArea(
              bottom: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(8, 4, 8, 0),
                child: Row(
                  children: [
                    _GlassIconBtn(
                      icon: 'solar:alt-arrow-left-linear',
                      onTap: _saveAndClose,
                    ),
                    const Spacer(),
                    _GlassIconBtn(
                      icon: 'solar:check-circle-bold',
                      color: AppColors.accent,
                      onTap: _saveAndClose,
                    ),
                  ],
                ),
              ),
            ),
          ),

          // Плашки упомянутых багов — скруглённые, с названием и ellipsis.
          if (_mentionedBugs().isNotEmpty && _mentionQuery == null)
            Positioned(
              top: top + 52,
              left: 16,
              right: 16,
              child: _MentionedChipsBar(
                bugs: _mentionedBugs(),
                onRemove: _removeMention,
              ),
            ),

          // Пикер упоминаний — над клавиатурой, без «полоски»-разделителя.
          if (_mentionQuery != null)
            Positioned(
              left: 12,
              right: 12,
              bottom: 8,
              child: _MentionPicker(
                bugs: bugs,
                query: _mentionQuery!,
                onSelect: _insertMention,
                onDismiss: () => setState(() => _mentionQuery = null),
              ),
            ),
        ],
      ),
    );
  }
}

/// Контроллер: `#n1234` рисуется акцентным «чипом» (фон + жирный).
/// WidgetSpan в EditableText не поддержан, поэтому длина токена в
/// value.text и в span совпадает — курсор не уезжает.
class _MentionController extends TextEditingController {
  _MentionController({super.text});

  static final _re = RegExp(r'#n\d{4}');

  @override
  TextSpan buildTextSpan({
    required BuildContext context,
    TextStyle? style,
    required bool withComposing,
  }) {
    final text = value.text;
    if (!_re.hasMatch(text)) {
      return TextSpan(style: style, text: text);
    }
    final spans = <InlineSpan>[];
    var last = 0;
    for (final m in _re.allMatches(text)) {
      if (m.start > last) {
        spans.add(TextSpan(style: style, text: text.substring(last, m.start)));
      }
      final token = m.group(0)!;
      spans.add(TextSpan(
        text: token,
        style: (style ?? const TextStyle()).copyWith(
          color: AppColors.accent,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.15,
          background: Paint()
            ..color = AppColors.accent.withValues(alpha: 0.18),
        ),
      ));
      last = m.end;
    }
    if (last < text.length) {
      spans.add(TextSpan(style: style, text: text.substring(last)));
    }
    return TextSpan(style: style, children: spans);
  }
}

/// Полупрозрачная круглая кнопка — текст под ней читается.
class _GlassIconBtn extends StatelessWidget {
  final String icon;
  final VoidCallback onTap;
  final Color? color;
  const _GlassIconBtn({
    required this.icon,
    required this.onTap,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    final pal = context.pal;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        customBorder: const CircleBorder(),
        child: Container(
          width: 40,
          height: 40,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: pal.bg.withValues(alpha: 0.55),
          ),
          child: Iconify(icon, size: 22, color: color ?? pal.text),
        ),
      ),
    );
  }
}

/// Компактный список багов над клавиатурой.
class _MentionPicker extends StatelessWidget {
  final List<BugItem> bugs;
  final String query;
  final ValueChanged<BugItem> onSelect;
  final VoidCallback onDismiss;
  const _MentionPicker({
    required this.bugs,
    required this.query,
    required this.onSelect,
    required this.onDismiss,
  });

  @override
  Widget build(BuildContext context) {
    final pal = context.pal;
    return Material(
      color: Colors.transparent,
      elevation: 0,
      child: Container(
        constraints: const BoxConstraints(maxHeight: 220),
        decoration: BoxDecoration(
          color: pal.cont,
          borderRadius: BorderRadius.circular(14),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: pal.isDark ? 0.45 : 0.12),
              blurRadius: 24,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        clipBehavior: Clip.antiAlias,
        child: bugs.isEmpty
            ? Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                child: Row(
                  children: [
                    Iconify('solar:bug-bold', size: 16, color: pal.sub),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        query.isEmpty
                            ? 'Нет багов для упоминания'
                            : 'Ничего не найдено по «#$query»',
                        style: TextStyle(color: pal.sub, fontSize: 13),
                      ),
                    ),
                    GestureDetector(
                      onTap: onDismiss,
                      child: Iconify('solar:close-circle-linear',
                          size: 18, color: pal.sub),
                    ),
                  ],
                ),
              )
            : ListView.separated(
                shrinkWrap: true,
                padding: const EdgeInsets.symmetric(vertical: 6),
                itemCount: bugs.length,
                separatorBuilder: (_, __) => Divider(
                  height: 1,
                  thickness: 1,
                  color: pal.sep,
                  indent: 44,
                ),
                itemBuilder: (_, i) {
                  final b = bugs[i];
                  final title =
                      b.title.trim().isEmpty ? 'Без названия' : b.title.trim();
                  final short = b.id.length >= 4
                      ? b.id.substring(b.id.length - 4)
                      : b.id;
                  return InkWell(
                    onTap: () => onSelect(b),
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
                      child: Row(
                        children: [
                          Container(
                            width: 28,
                            height: 28,
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              color: AppColors.accent.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Iconify('solar:bug-bold',
                                size: 15, color: AppColors.accent),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  title,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    color: pal.text,
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  '#$short',
                                  style: TextStyle(
                                    color: pal.sub,
                                    fontSize: 11.5,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          // Превью плашки с названием (ellipsis).
                          Container(
                            constraints: const BoxConstraints(maxWidth: 110),
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: AppColors.accent.withValues(alpha: 0.16),
                              borderRadius: BorderRadius.circular(999),
                            ),
                            child: Text(
                              title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: AppColors.accent,
                                fontSize: 11.5,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
      ),
    );
  }
}

/// Горизонтальный ряд плашек уже упомянутых в тексте багов.
class _MentionedChipsBar extends StatelessWidget {
  final List<BugItem> bugs;
  final ValueChanged<BugItem> onRemove;
  const _MentionedChipsBar({required this.bugs, required this.onRemove});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          for (final b in bugs) ...[
            _BugChip(bug: b, onRemove: () => onRemove(b)),
            const SizedBox(width: 6),
          ],
        ],
      ),
    );
  }
}

class _BugChip extends StatelessWidget {
  final BugItem bug;
  final VoidCallback onRemove;
  const _BugChip({required this.bug, required this.onRemove});

  @override
  Widget build(BuildContext context) {
    final title = bug.title.trim().isEmpty ? '#${bug.id}' : bug.title.trim();
    return Container(
      constraints: const BoxConstraints(maxWidth: 160),
      padding: const EdgeInsets.fromLTRB(10, 5, 6, 5),
      decoration: BoxDecoration(
        color: AppColors.accent.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Flexible(
            child: Text(
              title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: AppColors.accent,
                fontSize: 12.5,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const SizedBox(width: 4),
          GestureDetector(
            onTap: onRemove,
            behavior: HitTestBehavior.opaque,
            child: Padding(
              padding: const EdgeInsets.all(2),
              child: Iconify(
                'solar:close-circle-bold',
                size: 14,
                color: AppColors.accent.withValues(alpha: 0.85),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
