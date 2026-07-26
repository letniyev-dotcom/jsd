import 'package:flutter/material.dart';

import '../iconify.dart';
import '../navigation.dart';
import '../state.dart';
import '../theme.dart';
import '../widgets/common.dart';
import 'bug_constants.dart';
import 'bug_detail.dart';

/// Символ-плейсхолдер для упоминания бага внутри текста. Он занимает
/// РОВНО один code unit в строке (как и любой обычный символ) — это
/// критично для корректной работы курсора/выделения в [TextField]:
/// Flutter привязывает каждый [WidgetSpan] к позиции такого символа в
/// исходном тексте, поэтому один плейсхолдер = одна «плашка».
const String _kMentionPlaceholder = '\uFFFC';

/// Раскрывает `changelog`-текст с плейсхолдерами упоминаний в читаемый
/// текст для коммита/показа в деталях сборки — например, `#1234
/// (Название бага)`. Используется при пуше (см. commit.dart) и в
/// превью на экране коммита.
String expandChangelogText(String raw, List<String> mentionIds) {
  if (!raw.contains(_kMentionPlaceholder)) return raw;
  final buf = StringBuffer();
  var idx = 0;
  for (final rune in raw.runes) {
    if (rune == 0xFFFC) {
      final id = idx < mentionIds.length ? mentionIds[idx] : '';
      idx++;
      final shortId = id.length >= 4 ? id.substring(id.length - 4) : id;
      String title = '';
      for (final b in AppState.I.bugs) {
        if (b.id == id) {
          title = b.title;
          break;
        }
      }
      buf.write(title.isEmpty ? '#$shortId' : '#$shortId ($title)');
    } else {
      buf.writeCharCode(rune);
    }
  }
  return buf.toString();
}

/// [TextEditingController], который умеет рисовать упоминания багов
/// (`#1234`) как скруглённые плашки прямо внутри редактируемого текста.
/// Технически это [WidgetSpan] на месте символа [_kMentionPlaceholder] —
/// текст в `text` при этом остаётся плоской строкой (плейсхолдер = 1
/// символ), а какому багу соответствует какой плейсхолдер, знает список
/// [mentionIds] (тот же порядок, что и вхождения плейсхолдера в тексте).
class _MentionTextController extends TextEditingController {
  final List<String> Function() mentionIds;
  final BugItem? Function(String id) resolveBug;
  final void Function(int occurrenceIndex) onRemoveMention;
  final void Function(BugItem bug) onOpenBug;

  _MentionTextController({
    required String text,
    required this.mentionIds,
    required this.resolveBug,
    required this.onRemoveMention,
    required this.onOpenBug,
  }) : super(text: text);

  @override
  TextSpan buildTextSpan({
    required BuildContext context,
    TextStyle? style,
    required bool withComposing,
  }) {
    final ids = mentionIds();
    final t = text;
    final spans = <InlineSpan>[];
    var start = 0;
    var idx = 0;
    for (var i = 0; i < t.length; i++) {
      if (t[i] == _kMentionPlaceholder) {
        if (i > start) {
          spans.add(TextSpan(text: t.substring(start, i), style: style));
        }
        final occurrence = idx;
        final id = occurrence < ids.length ? ids[occurrence] : '';
        idx++;
        final bug = resolveBug(id);
        spans.add(WidgetSpan(
          alignment: PlaceholderAlignment.middle,
          child: _MentionChip(
            bug: bug,
            bugId: id,
            onRemove: () => onRemoveMention(occurrence),
            onOpen: bug == null ? null : () => onOpenBug(bug),
          ),
        ));
        start = i + 1;
      }
    }
    if (start < t.length) {
      spans.add(TextSpan(text: t.substring(start), style: style));
    }
    if (spans.isEmpty) {
      spans.add(TextSpan(text: '', style: style));
    }
    return TextSpan(style: style, children: spans);
  }
}

/// Скруглённая плашка упоминания бага внутри текста. Тап по трём точкам
/// открывает мини-меню: «Открыть баг» / «Убрать упоминание».
class _MentionChip extends StatefulWidget {
  final BugItem? bug;
  final String bugId;
  final VoidCallback onRemove;
  final VoidCallback? onOpen;
  const _MentionChip({
    required this.bug,
    required this.bugId,
    required this.onRemove,
    required this.onOpen,
  });

  @override
  State<_MentionChip> createState() => _MentionChipState();
}

class _MentionChipState extends State<_MentionChip> {
  Offset _tapPos = Offset.zero;

  Future<void> _openMenu() async {
    final pal = context.pal;
    final overlayBox =
        Overlay.of(context).context.findRenderObject() as RenderBox;
    final selected = await showMenu<String>(
      context: context,
      color: pal.cont,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      position: RelativeRect.fromRect(
        _tapPos & const Size(1, 1),
        Offset.zero & overlayBox.size,
      ),
      items: [
        if (widget.onOpen != null)
          PopupMenuItem<String>(
            value: 'open',
            child: Row(children: [
              Iconify('solar:eye-bold', size: 17, color: pal.text),
              const SizedBox(width: 10),
              Text('Открыть баг',
                  style: TextStyle(color: pal.text, fontSize: 14)),
            ]),
          ),
        PopupMenuItem<String>(
          value: 'remove',
          child: Row(children: [
            Iconify('solar:close-circle-bold', size: 17, color: pal.red),
            const SizedBox(width: 10),
            Text('Убрать упоминание',
                style: TextStyle(color: pal.red, fontSize: 14)),
          ]),
        ),
      ],
    );
    if (!mounted) return;
    if (selected == 'remove') widget.onRemove();
    if (selected == 'open') widget.onOpen?.call();
  }

  @override
  Widget build(BuildContext context) {
    final pal = context.pal;
    final typeKey = widget.bug?.type == 'sugg' ? 'sugg' : 'bug';
    final meta = kTypeMeta[typeKey]!;
    final shortId = widget.bugId.length >= 4
        ? widget.bugId.substring(widget.bugId.length - 4)
        : widget.bugId;
    final title = widget.bug?.title ?? '';
    final label = title.isEmpty ? '#$shortId' : title;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 1),
      child: Container(
        padding: const EdgeInsets.only(left: 8, right: 3, top: 3, bottom: 3),
        decoration: BoxDecoration(
          color: meta.color.withValues(alpha: pal.isDark ? 0.22 : 0.13),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: meta.color.withValues(alpha: 0.38)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Iconify(meta.icon, size: 12, color: meta.color),
            const SizedBox(width: 4),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 150),
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: meta.color,
                  height: 1.1,
                ),
              ),
            ),
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTapDown: (d) => _tapPos = d.globalPosition,
              onTap: _openMenu,
              child: Padding(
                padding: const EdgeInsets.all(4),
                child: Iconify('solar:menu-dots-bold',
                    size: 13, color: meta.color),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Экран «Список изменений к сборке».
///
/// Как в заметках: никакой шапки-контейнера, всё безгранично и
/// прозрачно, курсор сразу в тексте. Единственные UI-элементы поверх
/// текста — плавающие кнопки «назад»/«готово» и, при наборе `#`,
/// небольшая всплывающая панель с багами прямо над клавиатурой.
///
/// При переходе на новую строку (Enter) перед курсором автоматически
/// подставляется маркер «• », как в списке. Текст хранится в
/// [AppState.changelog] и при пуше добавляется телом коммита — поэтому
/// потом виден в деталях сборки (см. commit.dart и run_detail.dart).
///
/// Набор `#<цифры>` открывает всплывающее окошко над клавиатурой со
/// списком багов; выбор превращает набранное в скруглённую плашку с
/// названием бага (см. [_MentionChip]) — три точки на плашке открывают
/// мини-меню «Открыть баг» / «Убрать упоминание».
class ChangelogScreen extends StatefulWidget {
  const ChangelogScreen({super.key});
  @override
  State<ChangelogScreen> createState() => _ChangelogScreenState();
}

class _ChangelogScreenState extends State<ChangelogScreen> {
  static const _bullet = '• ';

  late final _MentionTextController _ctrl;
  final _focus = FocusNode();
  String _prevText = '';
  bool _guard = false;
  List<String> _mentionIds = [];

  // Активное упоминание "#..." в процессе набора: индекс символа '#' и
  // то, что набрано после него (для фильтрации панели).
  int? _mentionStart;
  String? _mentionQuery;

  @override
  void initState() {
    super.initState();
    final existingText = AppState.I.changelog;
    final existing = existingText.isEmpty ? _bullet : existingText;
    _mentionIds = existingText.isEmpty
        ? <String>[]
        : List<String>.from(AppState.I.changelogMentions);
    _ctrl = _MentionTextController(
      text: existing,
      mentionIds: () => _mentionIds,
      resolveBug: _resolveBug,
      onRemoveMention: _removeMentionAt,
      onOpenBug: _openBug,
    );
    _ctrl.selection = TextSelection.collapsed(offset: existing.length);
    _prevText = existing;
    _ctrl.addListener(_onChanged);
  }

  @override
  void dispose() {
    final finalText = _ctrl.text == _bullet ? '' : _ctrl.text;
    AppState.I.changelog = finalText;
    AppState.I.changelogMentions =
        finalText.isEmpty ? <String>[] : List<String>.from(_mentionIds);
    _ctrl.removeListener(_onChanged);
    _ctrl.dispose();
    _focus.dispose();
    super.dispose();
  }

  BugItem? _resolveBug(String id) {
    if (id.isEmpty) return null;
    for (final b in AppState.I.bugs) {
      if (b.id == id) return b;
    }
    return null;
  }

  Future<void> _openBug(BugItem bug) async {
    _focus.unfocus();
    if (!mounted) return;
    await pushSlide(context, BugDetailScreen(id: bug.id));
  }

  /// Удаляет упоминание под индексом [occurrenceIndex] — и сам символ
  /// из текста, и запись из [_mentionIds].
  void _removeMentionAt(int occurrenceIndex) {
    final t = _ctrl.text;
    var seen = 0;
    for (var i = 0; i < t.length; i++) {
      if (t[i] != _kMentionPlaceholder) continue;
      if (seen == occurrenceIndex) {
        final newText = t.substring(0, i) + t.substring(i + 1);
        if (occurrenceIndex < _mentionIds.length) {
          _mentionIds.removeAt(occurrenceIndex);
        }
        _guard = true;
        _ctrl.value = TextEditingValue(
          text: newText,
          selection: TextSelection.collapsed(offset: i),
        );
        _guard = false;
        _prevText = newText;
        setState(() {});
        return;
      }
      seen++;
    }
  }

  /// Вставляет выбранный [bug] на место активного `#запроса`.
  void _insertMention(BugItem bug) {
    final start = _mentionStart;
    if (start == null) return;
    final text = _ctrl.text;
    final queryLen = _mentionQuery?.length ?? 0;
    var cursor = start + 1 + queryLen;
    if (cursor > text.length) cursor = text.length;
    if (cursor < start) cursor = start;

    final before = text.substring(0, start);
    final after = text.substring(cursor);
    final newText = '$before$_kMentionPlaceholder$after';

    final insertIdx = _kMentionPlaceholder.allMatches(before).length;
    _mentionIds.insert(insertIdx.clamp(0, _mentionIds.length), bug.id);

    _guard = true;
    _ctrl.value = TextEditingValue(
      text: newText,
      selection: TextSelection.collapsed(offset: start + 1),
    );
    _guard = false;
    _prevText = newText;
    setState(() {
      _mentionStart = null;
      _mentionQuery = null;
    });
  }

  /// Синхронизирует [_mentionIds], когда пользователь стёр (backspace,
  /// вырезал, выделил и удалил) кусок текста, содержавший плейсхолдеры
  /// упоминаний — определяет ИМЕННО какие по общей префикс/суффикс
  /// разнице между старым и новым текстом.
  void _syncMentionsOnShrink(String oldText, String newText) {
    var i = 0;
    final frontLimit =
        oldText.length < newText.length ? oldText.length : newText.length;
    while (i < frontLimit && oldText[i] == newText[i]) {
      i++;
    }
    var j = 0;
    final backLimit = (oldText.length - i) < (newText.length - i)
        ? (oldText.length - i)
        : (newText.length - i);
    while (j < backLimit &&
        oldText[oldText.length - 1 - j] == newText[newText.length - 1 - j]) {
      j++;
    }
    final removedStart = i;
    final removedEnd = oldText.length - j;
    if (removedEnd <= removedStart) return;
    final removedSegment = oldText.substring(removedStart, removedEnd);
    final removedCount =
        _kMentionPlaceholder.allMatches(removedSegment).length;
    if (removedCount == 0) return;
    final beforeSegment = oldText.substring(0, removedStart);
    final startIdx = _kMentionPlaceholder.allMatches(beforeSegment).length;
    final endIdx = startIdx + removedCount;
    if (startIdx >= 0 && endIdx <= _mentionIds.length) {
      _mentionIds.removeRange(startIdx, endIdx);
    }
  }

  void _cancelMentionQuery() {
    if (_mentionStart == null && _mentionQuery == null) return;
    setState(() {
      _mentionStart = null;
      _mentionQuery = null;
    });
  }

  /// Отслеживает набор `#запроса` для всплывающей панели упоминаний.
  void _updateMentionState(String text, TextSelection sel, bool grew) {
    if (!sel.isCollapsed) {
      _cancelMentionQuery();
      return;
    }
    final cursor = sel.baseOffset;
    if (cursor < 0) {
      _cancelMentionQuery();
      return;
    }

    final start = _mentionStart;
    if (start != null) {
      if (cursor <= start || cursor > text.length) {
        _cancelMentionQuery();
        return;
      }
      final q = text.substring(start + 1, cursor);
      if (q.contains('\n') ||
          q.contains(' ') ||
          q.contains(_kMentionPlaceholder)) {
        _cancelMentionQuery();
        return;
      }
      setState(() => _mentionQuery = q);
      return;
    }

    if (grew && cursor > 0 && cursor <= text.length && text[cursor - 1] == '#') {
      setState(() {
        _mentionStart = cursor - 1;
        _mentionQuery = '';
      });
    }
  }

  List<BugItem> get _mentionMatches {
    final q = (_mentionQuery ?? '').trim().toLowerCase();
    Iterable<BugItem> pool = AppState.I.bugs;
    if (q.isNotEmpty) {
      pool = pool.where((b) {
        final shortId =
            b.id.length >= 4 ? b.id.substring(b.id.length - 4) : b.id;
        return shortId.contains(q) || b.title.toLowerCase().contains(q);
      });
    }
    final list = pool.toList()
      ..sort((a, b) => b.createdAtMs.compareTo(a.createdAtMs));
    return list.take(6).toList();
  }

  void _onChanged() {
    if (_guard) return;
    final text = _ctrl.text;
    final sel = _ctrl.selection;
    final grew = text.length > _prevText.length;

    if (text.length < _prevText.length) {
      _syncMentionsOnShrink(_prevText, text);
    }

    _updateMentionState(text, sel, grew);

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

  double _mentionPanelReserve(int matchCount) {
    if (matchCount == 0) return 74;
    final rows = matchCount > 5 ? 5 : matchCount;
    return 16 + rows * 52.0;
  }

  @override
  Widget build(BuildContext context) {
    final pal = context.pal;
    final top = MediaQuery.of(context).padding.top;
    final bottomSafe = MediaQuery.of(context).padding.bottom;
    // Клавиатуру обрабатываем вручную (resizeToAvoidBottomInset: false +
    // паддинг от viewInsets.bottom) — тот же паттерн, что и в
    // commit.dart/bug_new.dart/bug_meta.dart: без него Scaffold дёргано
    // ресайзит контент при открытии/закрытии IME (баг n8502-стиль).
    // Никакой заливки под клавиатурой при этом не появляется — под ней
    // всё тот же прозрачный `pal.bg`, поэтому «границы» там быть не может.
    final viewInsetBottom = MediaQuery.of(context).viewInsets.bottom;
    final mentionActive = _mentionStart != null;
    final matches = mentionActive ? _mentionMatches : const <BugItem>[];

    return Scaffold(
      backgroundColor: pal.bg,
      resizeToAvoidBottomInset: false,
      // Никакой AppBar/шапки — текст начинается прямо под системной
      // статус-баром, экран прозрачный и «безграничный»: сверху нет
      // заливки, только два плавающих кружка-кнопки.
      body: Stack(
        children: [
          Positioned.fill(
            child: Padding(
              padding: EdgeInsets.fromLTRB(
                20,
                top + 64,
                20,
                24 +
                    bottomSafe +
                    viewInsetBottom +
                    (mentionActive ? _mentionPanelReserve(matches.length) : 0),
              ),
              child: TextField(
                controller: _ctrl,
                focusNode: _focus,
                autofocus: true,
                maxLines: null,
                expands: true,
                textAlignVertical: TextAlignVertical.top,
                keyboardType: TextInputType.multiline,
                cursorColor: AppColors.accent,
                // Убирает нативную полосу автоподсказок над клавиатурой
                // (у части IME она рисуется с заметной разделительной
                // линией — та самая «граница» над клавой).
                autocorrect: false,
                enableSuggestions: false,
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
                  hintText:
                      'Что изменилось в этой сборке…\nНаберите # чтобы упомянуть баг',
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
          if (mentionActive)
            Positioned(
              left: 0,
              right: 0,
              bottom: viewInsetBottom,
              child: _MentionPickerPanel(
                matches: matches,
                query: _mentionQuery ?? '',
                onPick: _insertMention,
              ),
            ),
        ],
      ),
    );
  }
}

/// Всплывающая панель со списком багов прямо над клавиатурой — открыта
/// пока пользователь набирает `#запрос`. Полупрозрачная плавающая
/// карточка (а не сплошная во всю ширину полоса), поэтому не перекрывает
/// контент жёсткой границей.
class _MentionPickerPanel extends StatelessWidget {
  final List<BugItem> matches;
  final String query;
  final ValueChanged<BugItem> onPick;
  const _MentionPickerPanel({
    required this.matches,
    required this.query,
    required this.onPick,
  });

  @override
  Widget build(BuildContext context) {
    final pal = context.pal;
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
      child: Container(
        decoration: BoxDecoration(
          color: pal.cont.withValues(alpha: 0.97),
          borderRadius: BorderRadius.circular(18),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: pal.isDark ? 0.4 : 0.12),
              blurRadius: 24,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        clipBehavior: Clip.antiAlias,
        child: Material(
          color: Colors.transparent,
          child: matches.isEmpty
              ? Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
                  child: Row(children: [
                    Iconify('solar:bug-bold', size: 16, color: pal.sub),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        query.isEmpty
                            ? 'Багов пока нет'
                            : 'Ничего не найдено по «#$query»',
                        style: TextStyle(fontSize: 13, color: pal.sub),
                      ),
                    ),
                  ]),
                )
              : Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    for (final b in matches)
                      _MentionOptionRow(bug: b, onTap: () => onPick(b)),
                  ],
                ),
        ),
      ),
    );
  }
}

class _MentionOptionRow extends StatelessWidget {
  final BugItem bug;
  final VoidCallback onTap;
  const _MentionOptionRow({required this.bug, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final pal = context.pal;
    final typeKey = bug.type == 'sugg' ? 'sugg' : 'bug';
    final meta = kTypeMeta[typeKey]!;
    final shortId =
        bug.id.length >= 4 ? bug.id.substring(bug.id.length - 4) : bug.id;
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        child: Row(
          children: [
            Container(
              width: 30,
              height: 30,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: meta.color.withValues(alpha: pal.isDark ? 0.22 : 0.13),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Iconify(meta.icon, size: 15, color: meta.color),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    bug.title.isEmpty ? '—' : bug.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: pal.text,
                    ),
                  ),
                  Text('#$shortId',
                      style: TextStyle(fontSize: 11.5, color: pal.sub)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
