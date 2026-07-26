# тапок — мобильное приложение

Точная 1:1 копия HTML-прототипа ленты «тапок» в виде Android-приложения на **Python + Kivy + WebView**.

Дизайн, анимации FLIP, masonry-лента, темы, карусели, скелетоны, бесконечный скролл — всё работает идентично прототипу.

## Структура

```
tapok-app/
├── main.py                 # Kivy-приложение (Android WebView)
├── buildozer.spec          # Конфигурация сборки APK
├── assets/
│   └── index.html          # HTML-прототип 1:1 (дизайн + логика)
├── .github/workflows/
│   └── build-apk.yml       # GitHub Actions → автоматическая сборка APK
└── README.md
```

## Как собрать APK локально

### Требования
- Linux (Ubuntu 22.04+ рекомендуется)
- Python 3.10–3.11
- Buildozer

```bash
# Установка зависимостей системы (один раз)
sudo apt update
sudo apt install -y git unzip openjdk-17-jdk autoconf libtool pkg-config \
  zlib1g-dev libncurses5-dev libncursesw5-dev libtinfo5 cmake \
  libffi-dev libssl-dev libltdl-dev

pip install "Cython<3.0" buildozer

# Сборка debug-APK
buildozer android debug

# Готовый файл появится в bin/
ls -lh bin/*.apk
```

### Release APK (подписанный)
1. Создайте keystore:
   ```bash
   keytool -genkey -v -keystore release.keystore -alias tapok \
     -keyalg RSA -keysize 2048 -validity 10000
   ```
2. Пропишите в `buildozer.spec`:
   ```
   android.keystore = release.keystore
   android.keystore_passwd = ваш_пароль
   android.keyalias = tapok
   android.keyalias_passwd = ваш_пароль
   ```
3. Соберите:
   ```bash
   buildozer android release
   ```

## Автоматическая сборка на GitHub Actions

1. Создайте репозиторий на GitHub и залейте этот проект:
   ```bash
   git init
   git add .
   git commit -m "тапок v1.0.0"
   git branch -M main
   git remote add origin https://github.com/ВАШ_ЮЗЕР/tapok-app.git
   git push -u origin main
   ```

2. После пуша на `main` / `master` или создания тега `v*` GitHub Actions автоматически:
   - Соберёт **debug APK**
   - Загрузит его в Artifacts (вкладка Actions → скачать)
   - При наличии secrets — соберёт **release APK**
   - На тегах `v*` создаст GitHub Release с APK

### Secrets для подписанного Release APK (опционально)

В Settings → Secrets and variables → Actions добавьте:

| Secret              | Описание                                      |
|---------------------|-----------------------------------------------|
| `KEYSTORE_BASE64`   | `base64 -w0 release.keystore`                 |
| `KEYSTORE_PASSWORD` | Пароль keystore                               |
| `KEY_ALIAS`         | Алиас ключа (например `tapok`)                |
| `KEY_PASSWORD`      | Пароль ключа                                  |

После этого при следующем запуске workflow появится артефакт `tapok-release-apk`.

## Особенности

- **Полный экран** на реальном устройстве (media-query в HTML убирает рамку макета)
- **Тёмная / светлая тема** (кнопка в шапке)
- **Masonry-лента** + бесконечная подгрузка через Picsum
- **FLIP-анимации** открытия/закрытия постов
- **Карусели**, голосовые, цитаты, истории
- Интернет нужен только для фото (LoremFlickr / Picsum)

## Лицензия

Прототип и код — для демонстрации. Используйте свободно.
