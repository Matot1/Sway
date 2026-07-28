import SwiftUI

class LanguageManager: ObservableObject {
    static let shared = LanguageManager()
    @Published var language: String = UserDefaults.standard.string(forKey: "language") ?? "en"

    func setLanguage(_ lang: String) {
        language = lang
        UserDefaults.standard.set(lang, forKey: "language")
    }
}

func tr(_ key: String) -> String {
    let lang = LanguageManager.shared.language
    return Localization.strings[lang]?[key] ?? Localization.strings["en"]?[key] ?? key
}

func tr(_ key: String, _ args: CVarArg...) -> String {
    String(format: tr(key), arguments: args)
}

enum Localization {
    static let strings: [String: [String: String]] = [
        "en": [
            "General": "General",
            "Timer": "Timer",
            "Notification": "Notification",
            "About": "About",
            "Settings": "Settings",
            "Focus": "Focus",
            "Music": "Music",

            "Launch at Login": "Launch at Login",
            "Music Integration": "Music Integration",
            "Spotify, Apple Music, Yandex Music": "Spotify, Apple Music, Yandex Music",
            "Yandex Music Token": "Yandex Music Token",
            "Enter your token": "Enter your token",
            "Tap to configure": "Tap to configure",
            "OAuth Token": "OAuth Token",
            "Save": "Save",
            "Language": "Language",
            "English": "English",
            "Russian": "Russian",
            "Quit Sway": "Quit Sway",

            "Focus Duration": "Focus Duration",
            "Coffee Break Time": "Coffee Break Time",
            "Short Break": "Short Break",
            "Long Break": "Long Break",
            "Sessions before long break": "Sessions before long break",
            "min": "min",

            "Sound Alerts": "Sound Alerts",
            "Turn on/off sounds app": "Turn on/off sounds app",
            "Full Concentration": "Full Concentration",
            "Disable macOS notification when timer starting": "Open Focus settings to enable",

            "Sway": "Sway",
            "Version 0.3.5": "Version 0.3.5",
            "Developer": "Developer",
            "Sway Team": "Sway Team",
            "Built with": "Built with",
            "SwiftUI + AppKit": "SwiftUI + AppKit",

            "Spotify": "Spotify",
            "Apple Music": "Apple Music",
            "Yandex Music": "Yandex Music",
            "No Track Playing": "No Track Playing",
            "Music Player": "Music Player",

            "Ready to Focus": "Ready to Focus",
            "Focus Session %d": "Focus Session %d",
            "Coffee break": "Coffee break",
            "Automatically start break after focus session": "Automatically start break after focus session",

            "Unknown Artist": "Unknown Artist",

            "Theme": "Theme",
            "Default": "Default",
            "Light": "Light",
            "Monochrome": "Monochrome",
        ],
        "ru": [
            "Automatically start break after focus session": "Автоматически начинать перерыв после сессии",
            "General": "Основные",
            "Timer": "Таймер",
            "Notification": "Уведомления",
            "About": "О программе",
            "Settings": "Настройки",
            "Focus": "Фокус",
            "Music": "Музыка",

            "Launch at Login": "Автозапуск",
            "Music Integration": "Интеграция музыки",
            "Spotify, Apple Music, Yandex Music": "Spotify, Apple Music, Яндекс Музыка",
            "Yandex Music Token": "Токен Яндекс Музыки",
            "Enter your token": "Введите токен",
            "Tap to configure": "Нажмите для настройки",
            "OAuth Token": "OAuth токен",
            "Save": "Сохранить",
            "Language": "Язык",
            "English": "Английский",
            "Russian": "Русский",
            "Quit Sway": "Выйти из Sway",

            "Focus Duration": "Длительность фокуса",
            "Coffee Break Time": "Время кофе",
            "Short Break": "Короткий перерыв",
            "Long Break": "Длинный перерыв",
            "Sessions before long break": "Сессий до длинного перерыва",
            "min": "мин",

            "Sound Alerts": "Звуковые оповещения",
            "Turn on/off sounds app": "Вкл/выкл звуки приложения",
            "Full Concentration": "Полная концентрация",
            "Disable macOS notification when timer starting": "Открыть настройки Focus для включения",

            "Sway": "Sway",
            "Version 0.3.5": "Версия 0.3.5",
            "Developer": "Разработчик",
            "Sway Team": "Команда Sway",
            "Built with": "Создано с",
            "SwiftUI + AppKit": "SwiftUI + AppKit",

            "Spotify": "Spotify",
            "Apple Music": "Apple Music",
            "Yandex Music": "Яндекс Музыка",
            "No Track Playing": "Ничего не играет",
            "Music Player": "Музыка",

            "Ready to Focus": "Готов к работе",
            "Focus Session %d": "Сессия %d",
            "Coffee break": "Перерыв на кофе",

            "Unknown Artist": "Неизвестный исполнитель",

            "Theme": "Тема",
            "Default": "Стандартная",
            "Light": "Светлая",
            "Monochrome": "Монохром",
        ],
    ]
}
