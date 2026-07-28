# Sway

macOS-приложение, превращающее челку (notch) в интерактивный Dynamic Island с Pomodoro таймером и управлением музыкой.

## Notch Overlay

- **Collapsed** — невидим (2×2 pt), не мешает
- **Hovering** — чёрный блок при наведении на челку/мини-таймер (220 или 306×safeTop+8 pt, скругление снизу 16pt)
- **Expanded** — 500×110 pt, таб-бар + контент, скругление снизу 16pt
- **Мини-таймер** — отдельное окно 300×safeTop pt, отображается во время Pomodoro, показывает оставшееся время (Forza Thin 14pt)
- **Иконки** — flame.fill (фокус) / cup.and.saucer.fill (кофе) справа от мини-таймера, видны при активном таймере
- **Клик вне expanded** — сворачивает
- **Уровень окна** — .popUpMenu (выше иконок менюбара)

## Pomodoro Timer

- 25/5/15 мин (фокус / короткий перерыв / длинный перерыв)
- N сессий до длинного перерыва (настраивается)
- Кнопки play/pause/skip/reset
- Круговой прогресс-бар
- Звуковые оповещения: "Bottle" (старт), "Blow" (перерыв)
- **Mini timer** — всегда поверх окон, отображает оставшееся время
- **Цвет** — purple RGB(137,52,235): play/pause, прогресс-бар, selected tab

## Music Integration

- **Spotify** — AppleScript, 2s polling, play/pause/next/prev, track info
- **Apple Music** — AppleScript, 2s polling, play/pause/next/prev, track info
- **Yandex Music** — HID media key events, play/pause/next/prev (MediaRemote). Без названия трека (Electron-приложение не публикует now playing info). Иконка пламени при фокусе, чашки при кофе.

## Full Concentration

- **Sound Alerts** — вкл/выкл звуков приложения (toggle)
- **Full Concentration** — заглушка (системный DND не удалось реализовать — XPC сервис требует entitlements, AppleScript требует Accessibility и нестабилен)

## Settings

- Окно 480×360, тёмный фон, вкладки: General / Timer / Notification / About
- General: автозапуск, язык (en/ru), выход
- Timer: длительности сессий, количество сессий до long break
- Notification: Sound Alerts, Full Concentration
- About: версия, разработчик, технологии

## Технологии

- SwiftUI + AppKit
- macOS 14+
- LSUIElement = true (без иконки в Dock)
- MediaRemote.framework (Yandex Music)
- Keychain (токен Яндекс Музыки — не используется, сохранено для совместимости)
- Шрифт: Forza Thin

## Статус DND

Исследованы: `DNDModeAssertionService`, `DNDStateService`, `DNDModeAssertionDetails`, `DNDGlobalConfigurationService`, `DNDModeConfigurationService`. Все XPC-сервисы падают с `BSServiceConnectionErrorDomain Code=3` (не хватает entitlements). Дополнительно: `defaults + killall`, AppleScript с Control Center. Текущее решение — только хранение preference без системного DND.
