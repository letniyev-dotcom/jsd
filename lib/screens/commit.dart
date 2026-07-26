import 'dart:typed_data';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';

import '../iconify.dart';
import '../navigation.dart';
import '../state.dart';
import '../theme.dart';
import '../widgets/common.dart';
import 'changelog.dart';
import 'other.dart' show ThemedSwitch;

class CommitScreen extends StatefulWidget {
  const CommitScreen({super.key});
  @override
  State<CommitScreen> createState() => _CommitScreenState();
}

class _CommitScreenState extends State<CommitScreen> {
  final _ctrl = TextEditingController();
  // _busy остаётся только для дизейбла кнопки на момент микроперехода
  // (между тапом и закрытием экрана); сам пуш теперь живёт в фоне
  // (AppState.I.activeUpload — баг n6178).
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _ctrl.text = AppState.I.commitMessage;
  }

  @override
  void dispose() {
    AppState.I.commitMessage = _ctrl.text;
    _ctrl.dispose();
    super.dispose();
  }

  void _setTpl(String s) {
    _ctrl.text = s;
    _ctrl.selection = TextSelection.collapsed(offset: s.length);
    setState(() {});
  }

  Future<void> _openChangelog() async {
    await pushSlide(context, const ChangelogScreen());
    if (mounted) setState(() {});
  }

  void _toggleAggressive() {
    // ignore: discarded_futures
    AppState.I.setAggressiveUpload(!AppState.I.aggressiveUpload);
    setState(() {});
  }

  void _push() {
    final api = AppState.I.api;
    final repo = AppState.I.activeRepo;
    final files = AppState.I.stagedFiles;
    final msg = _ctrl.text.trim();
    if (api == null || repo == null) return;
    if (files.isEmpty) return;
    if (msg.isEmpty) return;
    // Список изменений уходит в тело коммита (после пустой строки за
    // заголовком) — тогда GitHub Actions отдаёт его в head_commit.message
    // и он становится виден в деталях сборки (см. run_detail.dart). Раньше
    // changelog нигде не отправлялся и просто терялся при пуше.
    final changelogText =
        expandChangelogText(AppState.I.changelog, AppState.I.changelogMentions)
            .trim();
    final fullMessage = changelogText.isEmpty ? msg : '$msg\n\n$changelogText';
    // Уже идёт активная заливка — второй пуш не запускаем. Кнопка в
    // этом случае дизейблится в `_NewRepoCard`/`_UploadCard` через
    // AppState.activeUpload.status, но подстраховываемся ещё и здесь.
    if (AppState.I.activeUpload.status == UploadStatus.running) {
      return;
    }
    setState(() => _busy = true);

    // Стартуем фоновую задачу. На этой задаче подписаны:
    // - карточка «Залить файлы» на профиле (рисует progress-бар);
    // - аватарка в нижнем навбаре (ring around avatar).
    final task = AppState.I.activeUpload;
    final filesCount = files.length;
    final filesSnapshot = Map<String, Uint8List>.from(files);
    task.start(repoName: repo.fullName, filesCount: filesCount);

    // Чистим staged-файлы СРАЗУ — пользователь сразу видит, что
    // «заливка пошла», и может выбрать новые файлы или зайти в
    // другие разделы; фон сам всё дольёт.
    AppState.I.stagedFiles = {};
    AppState.I.stagedZipName = '';
    AppState.I.commitMessage = '';
    AppState.I.changelog = '';
    AppState.I.changelogMentions = [];
    AppState.I.touch();

    // Стрим прогресса. unawaited — задача живёт в фоне. pushFiles теперь
    // возвращает [PushResult] с количеством реально залитых и пропущенных
    // (без изменений) файлов — пробрасываем это в UploadTask, чтобы
    // карточка заливки могла показать «Без изменений», когда все файлы
    // уже совпадают с тем, что лежит в репо (пушим только изменённое).
    () async {
      // «Агрессивная заливка» (см. UploadScreen/CommitScreen переключатель,
      // AppState.aggressiveUpload, по умолчанию включена):
      //   • если во время заливки пропала сеть — не падаем, а ждём, пока
      //     connectivity_plus сообщит о восстановлении, и продолжаем;
      //   • если запрос упал по другой причине — повторяем до 5 раз;
      //   • сам таск живёт в отдельном detached Future (не привязан к
      //     BuildContext этого экрана), поэтому продолжает выполняться,
      //     даже если пользователь ушёл с экрана коммита или свернул
      //     приложение — процесс просто должен оставаться в памяти.
      final aggressive = AppState.I.aggressiveUpload;
      const maxRetries = 5;
      int attempt = 0;
      while (true) {
        try {
          final res = await api.pushFiles(
            fullName: repo.fullName,
            branch: repo.defaultBranch,
            files: filesSnapshot,
            message: fullMessage,
            onProgress: (s, p) => task.update(s, p),
          );
          task.finishSuccess(
            uploaded: res.uploadedCount,
            unchanged: res.unchangedCount,
          );
          break;
        } catch (e) {
          if (!aggressive) {
            var errMsg = e.toString();
            if (errMsg.startsWith('Exception: ')) errMsg = errMsg.substring(11);
            task.finishError(errMsg);
            break;
          }
          final conn = await Connectivity().checkConnectivity();
          final offline =
              conn.isEmpty || conn.every((r) => r == ConnectivityResult.none);
          if (offline) {
            task.update('Нет сети — продолжим при подключении…', task.progress);
            await Connectivity().onConnectivityChanged.firstWhere(
                (r) => r.isNotEmpty && r.any((x) => x != ConnectivityResult.none));
            // Восстановление сети не считается попыткой — пробуем заново.
            continue;
          }
          attempt++;
          if (attempt > maxRetries) {
            var errMsg = e.toString();
            if (errMsg.startsWith('Exception: ')) errMsg = errMsg.substring(11);
            task.finishError(errMsg);
            break;
          }
          task.update('Ошибка, попытка $attempt из $maxRetries…', task.progress);
          await Future.delayed(Duration(seconds: attempt.clamp(1, 5)));
        }
      }
    }();

    // Закрываем экран коммита и сам upload-экран — пользователь
    // возвращается в профиль и видит прогресс на карточке заливки.
    Navigator.of(context).pop();
    Navigator.of(context).maybePop();
  }

  String _changelogPreview() {
    final expanded =
        expandChangelogText(AppState.I.changelog, AppState.I.changelogMentions);
    final raw = expanded.replaceAll('•', '').trim();
    if (raw.isEmpty) return 'Не заполнен';
    final oneLine = raw.replaceAll('\n', ' · ').trim();
    return oneLine.length > 46 ? '${oneLine.substring(0, 46)}…' : oneLine;
  }

  @override
  Widget build(BuildContext context) {
    final pal = context.pal;
    final repo = AppState.I.activeRepo;
    final filesCount = AppState.I.stagedFiles.length;
    final viewInsetBottom = MediaQuery.of(context).viewInsets.bottom;
    final bottomSafe = MediaQuery.of(context).padding.bottom;
    // Хелпер для контента, которому нужны боковые отступы 18 — а ListView
    // шаблонов остаётся edge-to-edge, чтобы чипы могли скроллиться за
    // края экрана (баг n8502, ч. 1).
    Widget pad(Widget child) => Padding(
          padding: const EdgeInsets.symmetric(horizontal: 18),
          child: child,
        );
    return Scaffold(
      backgroundColor: pal.bg,
      // Баг n8502, ч. 3: раньше Scaffold с resize=true дёргал кнопку push
      // вверх вместе с клавиатурой и она «прыгала» при открытии/закрытии
      // IME. Делаем kb-инсет ручным AnimatedPadding'ом — кнопка стоит на
      // своём месте, контент мягко поджимается под высоту клавы.
      resizeToAvoidBottomInset: false,
      body: Stack(
        children: [
          Positioned.fill(
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              padding: EdgeInsets.only(
                top: MediaQuery.of(context).padding.top + kTopHeaderBarHeight,
                // Резервируем место под кнопку push (54 + 16 + safe).
                bottom: 86 + bottomSafe,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
              pad(Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: pal.cont,
                  borderRadius: BorderRadius.circular(22),
                ),
                child: Row(
                  children: [
                    Iconify('solar:folder-with-files-bold',
                        size: 24, color: AppColors.accent),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Репозиторий · ветка ${repo?.defaultBranch ?? 'main'}',
                            style:
                                TextStyle(fontSize: 12, color: pal.sub),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            repo?.name ?? '—',
                            style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                color: pal.text),
                          ),
                        ],
                      ),
                    ),
                    Text('$filesCount файлов',
                        style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: pal.sub)),
                  ],
                ),
              )),
              pad(const SecTitle('Сообщение коммита',
                  padding: EdgeInsets.only(top: 18, bottom: 10, left: 4))),
              pad(FieldBox(controller: _ctrl, hint: 'feat: добавил splash screen')),
              pad(const SecTitle('Шаблоны',
                  padding: EdgeInsets.only(top: 12, bottom: 10, left: 4))),
              // Баг n8502, ч.1: раньше горизонтальный ListView сидел
              // внутри Padding(horizontal:18), из-за чего крайние чипы
              // упирались в видимые «обрезанные» границы. Сейчас ListView
              // занимает всю ширину экрана и имеет внутренний
              // padding-стартер 18 — крайние чипы могут уезжать за края.
              SizedBox(
                height: 36,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  physics: const BouncingScrollPhysics(),
                  padding: const EdgeInsets.symmetric(horizontal: 18),
                  children: [
                    for (final t in const [
                      'фикс: ',
                      'новое: ',
                      'правка: ',
                      'рефакт: ',
                      'доки: ',
                    ]) ...[
                      CtChip(label: t.trim(), onTap: () => _setTpl(t)),
                      const SizedBox(width: 8),
                    ],
                  ],
                ),
              ),
              pad(const SecTitle('Перед заливкой',
                  padding: EdgeInsets.only(top: 20, bottom: 10, left: 4))),
              pad(TileGroup(children: [
                Tile(
                  iconBg: AppColors.purple,
                  icon: 'solar:clipboard-add-bold',
                  title: 'Список изменений',
                  sub: _changelogPreview(),
                  onTap: _openChangelog,
                ),
                Tile(
                  iconBg: AppState.I.aggressiveUpload
                      ? AppColors.orange
                      : (pal.isDark
                          ? const Color(0xFF3A3A3F)
                          : const Color(0xFFB7B7BD)),
                  icon: 'solar:bolt-bold',
                  title: 'Агрессивная заливка',
                  sub: 'Переживает обрыв сети и повторяет попытку до 5 раз, '
                      'не останавливаясь в фоне',
                  onTap: _toggleAggressive,
                  trailing:
                      ThemedSwitch(active: AppState.I.aggressiveUpload),
                ),
              ])),
                ],
              ),
            ),
          ),
          // Баг n8502, ч.2/3: кнопка «Запушить» (раньше «Push в main») —
          // прибита к низу экрана и НЕ прыгает с клавиатурой. AnimatedPadding
          // плавно уезжает над открывающимся IME, чтобы её всё-таки было
          // видно при необходимости (пользователю не нужно скроллить контент).
          Positioned(
            left: 18,
            right: 18,
            bottom: 0,
            child: AnimatedPadding(
              duration: const Duration(milliseconds: 180),
              curve: Curves.easeOut,
              padding: EdgeInsets.only(
                bottom: 16 + bottomSafe + viewInsetBottom,
              ),
              child: PushButton(
                label: _busy ? 'Заливка…' : 'Запушить',
                icon: _busy ? null : 'solar:upload-bold',
                loading: _busy,
                onTap: _busy ? null : _push,
              ),
            ),
          ),
          const Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: TopFadeHeader(title: 'Коммит'),
          ),
        ],
      ),
    );
  }
}
