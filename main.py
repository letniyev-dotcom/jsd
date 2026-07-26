"""
тапок — мобильное приложение (Kivy + Android WebView)
Точная 1:1 копия HTML-прототипа ленты.
"""

from kivy.app import App
from kivy.clock import Clock
from kivy.utils import platform

# На Android используем нативный WebView через pyjnius.
# На десктопе (для отладки) просто показываем заглушку.


class TapokApp(App):
    def build(self):
        # На Android контент будет заменён на WebView в on_start
        from kivy.uix.floatlayout import FloatLayout
        from kivy.uix.label import Label

        root = FloatLayout()
        if platform != "android":
            root.add_widget(
                Label(
                    text="тапок\n\nОткройте на Android\nили соберите APK",
                    halign="center",
                    valign="middle",
                    color=(1, 1, 1, 1),
                    font_size="22sp",
                )
            )
        return root

    def on_start(self):
        if platform == "android":
            Clock.schedule_once(self._create_webview, 0)

    def _create_webview(self, *args):
        from jnius import autoclass
        from android.runnable import run_on_ui_thread
        from android import mActivity

        WebView = autoclass("android.webkit.WebView")
        WebViewClient = autoclass("android.webkit.WebViewClient")
        WebSettings = autoclass("android.webkit.WebSettings")
        ViewGroup = autoclass("android.view.ViewGroup")
        LayoutParams = ViewGroup.LayoutParams

        @run_on_ui_thread
        def _init():
            webview = WebView(mActivity)
            settings = webview.getSettings()
            settings.setJavaScriptEnabled(True)
            settings.setDomStorageEnabled(True)
            settings.setAllowFileAccess(True)
            settings.setAllowContentAccess(True)
            settings.setAllowFileAccessFromFileURLs(True)
            settings.setAllowUniversalAccessFromFileURLs(True)
            settings.setLoadWithOverviewMode(True)
            settings.setUseWideViewPort(True)
            settings.setBuiltInZoomControls(False)
            settings.setDisplayZoomControls(False)
            settings.setSupportZoom(False)
            settings.setMediaPlaybackRequiresUserGesture(False)
            # Разрешаем HTTPS-картинки из file:// контекста
            try:
                settings.setMixedContentMode(WebSettings.MIXED_CONTENT_ALWAYS_ALLOW)
            except Exception:
                pass

            webview.setWebViewClient(WebViewClient())
            webview.setVerticalScrollBarEnabled(False)
            webview.setHorizontalScrollBarEnabled(False)
            webview.setOverScrollMode(2)  # OVER_SCROLL_NEVER

            # Загружаем локальный HTML из assets
            webview.loadUrl("file:///android_asset/index.html")

            # Делаем WebView единственным контентом Activity
            mActivity.setContentView(webview)

        _init()


if __name__ == "__main__":
    TapokApp().run()
