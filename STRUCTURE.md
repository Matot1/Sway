Sway/
├── Package.swift                        # Swift Package Manager конфиг (macOS 14+)
├── Info.plist                           # LSUIElement = true (без иконки в Dock)
├── build.sh                             # Скрипт сборки .app бандла
│
└── Sources/
    └── Sway/
        │
        ├── App/                         # ——— Entry Point ———
        │   ├── SwayApp.swift            # @main, SwiftUI App, Settings Scene
        │   └── AppDelegate.swift        # NSApplicationDelegate, запуск оверлейного окна
        │
        ├── Notch/                       # ——— Notch Overlay ———
        │   ├── NotchWindowController.swift # NSWindowController + NotchWindow (CGShieldingWindowLevel)
        │   ├── NotchViewModel.swift     # Состояние: collapsed/expanded, выбранный таб
        │   ├── NotchRootView.swift      # CollapsedNotchView + VisualEffectView (blur)
        │   └── ExpandedNotchView.swift  # Развёрнутая панель: таб-бар + контент
        │
        ├── Timer/                       # ——— Pomodoro Timer ———
        │   ├── PomodoroViewModel.swift  # 25/5/15 мин, N сенссов до long break
        │   └── TimerView.swift          # Circle progress, play/pause/skip/reset
        │
        ├── Music/                       # ——— Music Integration ———
        │   ├── MusicServiceProtocol.swift # Протокол: authorize, playPause, next, prev
        │   ├── MusicViewModel.swift     # Агрегатор трёх сервисов, автопереключение
        │   ├── SpotifyService.swift     # AppleScript → com.spotify.client
        │   ├── AppleMusicService.swift  # AppleScript → com.apple.Music
        │   ├── YandexMusicService.swift # API music.yandex.net + Keychain
        │   └── MusicPlayerView.swift    # Provider picker, album art, controls
        │
        ├── Views/                       # ——— Other Views ———
        │   └── SettingsView.swift       # Настройки, ввод Yandex Music токена, quit
        │
        └── Services/
            └── Models.swift             # Track, NotchState, NotchTab, PomodoroConfig, MusicProvider
