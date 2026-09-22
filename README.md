# Sway

<p align="center">
  <img src="app-icon.png" width="128" alt="Sway">
</p>

Ru: MacOS-приложение, интерактивная панель в челке экрана с таймером Pomodoro и музыкой.
En: MacOS Application: Interactive Menu Bar Panel with Pomodoro Timer and Music

## RU: Возможности

- **Pomodoro таймер** — 25/5/15 минут, длинный перерыв после N сессий, звуковые оповещения
- **Мини-таймер** — отображается поверх всех окон во время работы, показывает оставшееся время
- **Музыка** — управление Spotify, Apple Music и Yandex Music (play/pause, next, previous)
- **Настройки** — General, Timer, About
- **Язык** — английский / русский

## EN: Features
- **Pomodoro Timer** — 25/5/15 minutes, long break after N sessions, sound notifications
- **Mini Timer** — displays on top of all windows during work, shows remaining time
- **Music** — control Spotify, Apple Music and Yandex Music (play/pause, next, previous)
- **Settings** — General, Timer, About
- **Language** — English / Russian

## RU: Установка

1. Скачайте последнюю версию со [страницы релизов](https://github.com/Matot1/FocusNotch/releases)
2. Распакуйте архив и переместите `Sway.app` в папку `Программы`
3. Запустите приложение (потребуется подтверждение Gatekeeper)
4. Если Gatekeeper блокирует запуск, выполните в терминале:  _sudo xattr -dr com.apple.quarantine /Applications/Sway.app_

## EN: Installation
1. Download the latest version from the [Releases page](https://github.com/Matot1/FocusNotch/releases)
2. Extract the archive and move `Sway.app` to the `Applications folder`
3. Launch the application (Gatekeeper confirmation may be required)
4. If Gatekeeper blocks the launch, run the following in the terminal:  _sudo xattr -dr com.apple.quarantine /Applications/Sway.app_

> **Requirements:** macOS 14+, Xcode 15+ or Command Line Tools

## Technologies
SwiftUI + AppKit, macOS 14+
