package com.devin.github_pusher

import android.content.ContentValues
import android.os.Build
import android.os.Environment
import android.provider.MediaStore
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.io.FileOutputStream

class MainActivity : FlutterActivity() {
    private val downloadsChannel = "github_pusher/downloads"

    // ---- ВАЖНО ПРО СПЛЭШ ----
    //
    // В этом Activity НЕТ ничего, что касается системного сплэш-экрана:
    // ни `installSplashScreen()` (AndroidX backport), ни
    // `setKeepOnScreenCondition`, ни `setOnExitAnimationListener`.
    //
    // Конфигурация сплэша полностью лежит в:
    //   • res/values-v31/styles.xml (windowSplashScreen* для светлой темы)
    //   • res/values-night-v31/styles.xml (тёмная тема)
    //   • res/drawable/splash_icon.xml (статичный vector — один на обе темы)
    //   • res/values/ic_launcher_background.xml (#161618 — цвет фона
    //     launcher-иконки И сплэша одновременно, чтобы launcher→splash
    //     был визуально бесшовным; см. подробный комментарий в
    //     values-v31/styles.xml).
    //
    // Этот подход 1:1 копирует Telegram-Android (DrKLO/Telegram):
    // их LaunchActivity тоже не вызывает installSplashScreen() — они
    // полагаются исключительно на нативный Android 12+ SplashScreen
    // API из styles.xml. На стороне Java/Kotlin — пусто.
    //
    // Почему не использовать AndroidX SplashScreen library + hold через
    // `setKeepOnScreenCondition`:
    //   • setKeepOnScreenCondition опрашивает условие на КАЖДОМ кадре
    //     (OnPreDrawListener), и пока флаг не сброшен — окно сплэша
    //     ремаусится. На части OEM-ROM (MIUI, OneUI, ColorOS) это
    //     приводило к перезапуску встроенной enter-анимации иконки →
    //     визуально это видно как «мигания» иконки во время удержания;
    //   • AndroidX-shim добавляет дополнительный слой между нашим
    //     кодом и нативным API, который на 12+ должен быть прозрачным,
    //     но на ряде устройств всё-таки оставляет следы.
    //
    // Без shim'а ОС сама держит сплэш ровно до момента когда Activity
    // отрисует первый кадр. Для Flutter-приложения это первый кадр
    // FlutterView. В main.dart мы делаем await на загрузку AppState
    // и precache всех SVG-иконок ДО `runApp`, поэтому первый кадр
    // Flutter — это уже полностью готовый экран (онбординг или Shell).
    // По длительности сплэш висит от 500ms (enter-анимация) до
    // 1-2s (если холодный старт + тяжёлая загрузка) — система
    // сама решает.
    //
    // Exit-анимация — встроенная системная: короткий fade + лёгкий
    // scale иконки, ОС умеет это и делает гладко. Кастомный
    // setOnExitAnimationListener тоже убрали — он был нужен только
    // в паре с setKeepOnScreenCondition.

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        // Канал для метода сохранения в Downloads.
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, downloadsChannel).setMethodCallHandler { call, result ->
            when (call.method) {
                "saveToDownloads" -> {
                    val name = call.argument<String>("filename")
                    val mime = call.argument<String>("mime") ?: "application/zip"
                    val srcPath = call.argument<String>("srcPath")
                    if (name == null || srcPath == null) {
                        result.error("ARG", "filename и srcPath обязательны", null)
                        return@setMethodCallHandler
                    }
                    try {
                        val src = File(srcPath)
                        if (!src.exists()) {
                            result.error("NO_SRC", "Источник не найден: $srcPath", null)
                            return@setMethodCallHandler
                        }
                        val outPath = saveToDownloads(name, mime, src)
                        result.success(outPath)
                    } catch (e: Throwable) {
                        result.error("IO", e.message ?: "Не удалось сохранить", null)
                    }
                }
                else -> result.notImplemented()
            }
        }
    }

    private fun saveToDownloads(filename: String, mime: String, src: File): String {
        // Android 10+ — пишем через MediaStore.Downloads (без WRITE_EXTERNAL_STORAGE).
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            val resolver = applicationContext.contentResolver
            val values = ContentValues().apply {
                put(MediaStore.Downloads.DISPLAY_NAME, filename)
                put(MediaStore.Downloads.MIME_TYPE, mime)
                put(MediaStore.Downloads.RELATIVE_PATH, Environment.DIRECTORY_DOWNLOADS)
                put(MediaStore.Downloads.IS_PENDING, 1)
            }
            val collection = MediaStore.Downloads.getContentUri(MediaStore.VOLUME_EXTERNAL_PRIMARY)
            val uri = resolver.insert(collection, values)
                ?: throw IllegalStateException("MediaStore.insert вернул null")
            resolver.openOutputStream(uri).use { out ->
                if (out == null) throw IllegalStateException("Не удалось открыть OutputStream")
                src.inputStream().use { input -> input.copyTo(out) }
            }
            values.clear()
            values.put(MediaStore.Downloads.IS_PENDING, 0)
            resolver.update(uri, values, null, null)
            return uri.toString()
        }

        // Android 9 и ниже — пишем напрямую в /storage/emulated/0/Download/.
        val downloads = Environment.getExternalStoragePublicDirectory(Environment.DIRECTORY_DOWNLOADS)
        if (!downloads.exists()) downloads.mkdirs()
        val out = File(downloads, filename)
        FileOutputStream(out).use { o -> src.inputStream().use { it.copyTo(o) } }
        return out.absolutePath
    }
}
