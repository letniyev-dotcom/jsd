import 'package:flutter/material.dart';

import '../iconify.dart';
import '../navigation.dart';
import '../state.dart';
import '../theme.dart';
import 'bug_detail.dart';
import 'bugs.dart' show bugThumbColor;

/// Экран «Список изменений к сборке».
///
/// По просьбе пользователя — как в заметках: никакой шапки-контейнера,
/// всё безгранично и прозрачно, курсор сразу в тексте. Единственный
/// UI-элемент поверх текста — плавающие кнопки «назад»/«готово» в углах
/// (полупрозрачные кружки, не сплошная плашка).
///
/// При переходе на новую строку (Enter) перед курсором автоматически
/// подставляется маркер «• », как в списке.
///
/// Если ввести «#», открывается небольшая прокручиваемая панель со
/// списком баг-репортов (миниатюра + название, обрезается многоточием,
/// если длинное) — печатая дальше, список фильтруется по вхождению в
/// название. Выбор бага вставляет в текст токен вида «#n1234 », который
/// [_MentionController] всегда рендерит как скруглённую плашку с
/// миниатюрой и названием бага. Тап по плашке открывает соответствующий
/// баг-репорт.
///
/// Текст (включая токены «#n1234») хранится в [AppState.changelog] и
/// уходит в тело коммита при заливке — см. `commit.dart`.
class ChangelogScreen extends StatefulWidget {
  const ChangelogScreen({super.key});
  @override
  State<ChangelogScreen> createState() => _ChangelogScreenState();
}

class _ChangelogScreenState extends State<ChangelogScreen> {
  static const _bullet = '• ';

  late final _MentionController _ctrl;
  final _focus = FocusNode();
  String _prevText = '';
  bool _guard = false;

  /// Позиция символа «#», с которого начался текущий mention (null —
  /// панель выбора бага закрыта).
  int? _mentionStart;
  String _mentionQuery = '';

  @override
  void initState() {
    super.initState();
    final existing = AppState.I.changelog;
    // Если список ещё пуст — сразу подставляем первый маркер, чтобы
    // экран выглядел как начатый список, а не пустая страница.
    final initial = existing.isEmpty ? _bullet : existing;
    _ctrl = _MentionController(text: initial);
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

  static bool _isBreak(String ch) => ch == ' ' || ch == '\n';

  void _onChanged() {
    if (_guard) return;
    final text = _ctrl.text;
    final sel = _ctrl.selection;
    final grew = text.length > _prevText.length;

    // 1. Маркер новой строки.
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
    _updateMentionState(text, sel.isCollapsed ? sel.baseOffset : -1);
  }

  /// Пересчитывает, активен ли сейчас mention-попап (после «#») и что
  /// в нём набрано, по актуальному тексту/позиции курсора.
  void _updateMentionState(String text, int cursor) {
    if (cursor < 0) {
      if (_mentionStart != null) setState(() => _mentionStart = null);
      return;
    }
    var start = _mentionStart;

    // Начали новый mention: только что напечатали «#» в начале строки
    // или после пробела/переноса — не посреди слова вроде «C#».
    if (start == null &&
        cursor > 0 &&
        cursor <= text.length &&
        text[cursor - 1] == '#' &&
        (cursor == 1 || _isBreak(text[cursor - 2]))) {
      start = cursor - 1;
    }

    if (start == null) {
      if (_mentionStart != null) setState(() => _mentionStart = null);
      return;
    }

    // Проверяем, что «#» ещё на месте и курсор не убежал перед ним.
    if (start >= text.length || text[start] != '#' || cursor <= start) {
      if (_mentionStart != null) setState(() => _mentionStart = null);
      return;
    }

    final query = text.substring(start + 1, cursor);
    if (query.contains(' ') || query.contains('\n')) {
      if (_mentionStart != null) setState(() => _mentionStart = null);
      return;
    }

    setState(() {
      _mentionStart = start;
      _mentionQuery = query;
    });
  }

  void _selectBug(BugItem bug) {
    final start = _mentionStart;
    if (start == null) return;
    final text = _ctrl.text;
    final cursor = _ctrl.selection.baseOffset;
    final safeCursor = cursor < 0 ? text.length : cursor;
    final token = '#${bug.id} ';
    final newText =
        text.substring(0, start) + token + text.substring(safeCursor);
    _guard = true;
    _ctrl.value = TextEditingValue(
      text: newText,
      selection: TextSelection.collapsed(offset: start + token.length),
    );
    _prevText = newText;
    _guard = false;
    setState(() {
      _mentionStart = null;
      _mentionQuery = '';
    });
  }

  @override
  Widget build(BuildContext context) {
    final pal = context.pal;
    final top = MediaQuery.of(context).padding.top;
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    final mentionOpen = _mentionStart != null;

    return Scaffold(
      backgroundColor: pal.bg,
      resizeToAvoidBottomInset: true,
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
                // Без этого Android иногда решает, что это поле для логина
                // или заметки с чувствительными данными, и подключает
                // менеджер паролей / автозаполнение — на некоторых
                // прошивках (Flyme/MIUI) это приводило к тому, что в поле
                // раз за разом подставлялся сохранённый текст, забивая
                // экран повторяющейся тарабарщиной. Явно говорим системе
                // не трогать это поле автозаполнением.
                autofillHints: const [],
                enableIMEPersonalizedLearning: false,
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
                  hintText: 'Что изменилось в этой сборке… «#» — упомянуть баг',
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
            child: _IslandBtn(
              icon: 'solar:alt-arrow-left-linear',
              onTap: () => Navigator.of(context).maybePop(),
            ),
          ),
          Positioned(
            top: top + 10,
            right: 12,
            child: _IslandBtn(
              icon: 'solar:check-circle-bold',
              iconColor: AppColors.accent,
              onTap: () => Navigator.of(context).maybePop(),
            ),
          ),
          if (mentionOpen)
            Positioned(
              left: 16,
              right: 16,
              bottom: bottomInset + 12,
              child: _MentionPopup(
                query: _mentionQuery,
                onPick: _selectBug,
              ),
            ),
        ],
      ),
    );
  }
}

/// Кнопка-«островок»: сама шапка экрана прозрачная (никакого фонового
/// бара), но кнопки назад/готово сидят каждая на своём скруглённом
/// «островке» — тот же приём, что и в `bug_draw.dart` (`_Island` +
/// `_CircleBtn`), только локально для этого экрана.
class _IslandBtn extends StatelessWidget {
  final String icon;
  final Color? iconColor;
  final VoidCallback onTap;
  const _IslandBtn({required this.icon, required this.onTap, this.iconColor});

  @override
  Widget build(BuildContext context) {
    final pal = context.pal;
    return Material(
      color: pal.cont,
      shape: const CircleBorder(),
      clipBehavior: Clip.antiAlias,
      elevation: 0,
      child: InkWell(
        onTap: onTap,
        child: SizedBox(
          width: 40,
          height: 40,
          child: Center(
            child: Iconify(icon, size: 22, color: iconColor ?? pal.text),
          ),
        ),
      ),
    );
  }
}
/// текста как скруглённые плашки бага (миниатюра + название), а не как
/// сырой текст. Сам текст поля при этом остаётся обычной строкой — токен
/// хранится как есть, меняется только то, как он рисуется.
class _MentionController extends TextEditingController {
  _MentionController({super.text});

  static final _re = RegExp(r'#(n\d{4})');

  @override
  TextSpan buildTextSpan({
    required BuildContext context,
    TextStyle? style,
    required bool withComposing,
  }) {
    final src = text;
    final children = <InlineSpan>[];
    var last = 0;
    for (final m in _re.allMatches(src)) {
      if (m.start > last) {
        children.add(TextSpan(text: src.substring(last, m.start), style: style));
      }
      final id = m.group(1)!;
      BugItem? bug;
      for (final b in AppState.I.bugs) {
        if (b.id == id) {
          bug = b;
          break;
        }
      }
      if (bug == null) {
        // Баг мог быть удалён — не теряем текст, просто не рисуем плашку.
        children.add(TextSpan(text: m.group(0), style: style));
      } else {
        children.add(WidgetSpan(
          alignment: PlaceholderAlignment.middle,
          child: _BugPill(bug: bug),
        ));
      }
      last = m.end;
    }
    if (last < src.length) {
      children.add(TextSpan(text: src.substring(last), style: style));
    }
    return TextSpan(style: style, children: children);
  }
}

/// Скруглённая плашка с миниатюрой и названием бага, вставляемая в текст
/// вместо токена «#n1234». Тап открывает баг-репорт.
class _BugPill extends StatelessWidget {
  final BugItem bug;
  const _BugPill({required this.bug});

  @override
  Widget build(BuildContext context) {
    final pal = context.pal;
    final title = bug.title.trim().isEmpty ? 'Без названия' : bug.title.trim();
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => pushSlide(context, BugDetailScreen(id: bug.id)),
      child: Container(
        padding: const EdgeInsets.only(left: 3, right: 9, top: 2, bottom: 2),
        decoration: BoxDecoration(
          color: pal.cont,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: bug.shots.isNotEmpty
                  ? Image(
                      image: bug.imageProvider(0),
                      width: 20,
                      height: 20,
                      fit: BoxFit.cover,
                    )
                  : Container(
                      width: 20,
                      height: 20,
                      color: bugThumbColor(bug),
                      alignment: Alignment.center,
                      child: const Iconify('solar:bug-bold',
                          size: 12, color: Colors.white),
                    ),
            ),
            const SizedBox(width: 5),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 130),
              child: Text(
                title,
                maxLines: 1,
                softWrap: false,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 13,
                  height: 1,
                  color: pal.text,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Небольшая прокручиваемая панель со списком баг-репортов, которая
/// всплывает над клавиатурой при вводе «#». Печатая дальше, список
/// фильтруется по вхождению в название.
class _MentionPopup extends StatelessWidget {
  final String query;
  final void Function(BugItem) onPick;
  const _MentionPopup({required this.query, required this.onPick});

  @override
  Widget build(BuildContext context) {
    final pal = context.pal;
    final q = query.trim().toLowerCase();
    final all = AppState.I.bugs.reversed.toList(); // новые сверху
    final filtered = q.isEmpty
        ? all
        : all.where((b) => b.title.toLowerCase().contains(q)).toList();

    return Material(
      color: Colors.transparent,
      child: Container(
        constraints: const BoxConstraints(maxHeight: 260),
        decoration: BoxDecoration(
          color: pal.cont,
          borderRadius: BorderRadius.circular(18),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.25),
              blurRadius: 20,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: filtered.isEmpty
            ? Padding(
                padding: const EdgeInsets.symmetric(vertical: 22, horizontal: 16),
                child: Text(
                  all.isEmpty ? 'Пока нет ни одного бага' : 'Ничего не найдено',
                  style: TextStyle(fontSize: 13, color: pal.sub),
                ),
              )
            : ListView.builder(
                padding: const EdgeInsets.symmetric(vertical: 6),
                shrinkWrap: true,
                itemCount: filtered.length,
                itemBuilder: (context, i) {
                  final bug = filtered[i];
                  final title =
                      bug.title.trim().isEmpty ? 'Без названия' : bug.title.trim();
                  return InkWell(
                    onTap: () => onPick(bug),
                    child: Padding(
                      padding:
                          const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
                      child: Row(
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(9),
                            child: bug.shots.isNotEmpty
                                ? Image(
                                    image: bug.imageProvider(0),
                                    width: 32,
                                    height: 32,
                                    fit: BoxFit.cover,
                                  )
                                : Container(
                                    width: 32,
                                    height: 32,
                                    color: bugThumbColor(bug),
                                    alignment: Alignment.center,
                                    child: const Iconify('solar:bug-bold',
                                        size: 16, color: Colors.white),
                                  ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 14,
                                color: pal.text,
                                fontWeight: FontWeight.w500,
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
