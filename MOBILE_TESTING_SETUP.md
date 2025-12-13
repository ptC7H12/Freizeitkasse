# 📱 Mobile Testing Setup Guide - Windows 11 + IntelliJ

## Inhaltsverzeichnis
1. [Android Setup](#android-setup)
2. [iOS Setup (Einschränkungen unter Windows)](#ios-setup)
3. [IntelliJ Konfiguration](#intellij-konfiguration)
4. [Troubleshooting](#troubleshooting)

---

## 🤖 Android Setup

### Voraussetzungen

1. **Flutter SDK** muss installiert sein
   - Download: https://flutter.dev/docs/get-started/install/windows
   - Fügen Sie Flutter zum PATH hinzu

2. **Android Studio** (empfohlen) ODER **Android Command Line Tools**
   - Download: https://developer.android.com/studio

### Schritt 1: Android SDK Installation

#### Option A: Mit Android Studio (Empfohlen)

1. Installieren Sie Android Studio
2. Öffnen Sie Android Studio
3. Gehen Sie zu: `File` → `Settings` → `Appearance & Behavior` → `System Settings` → `Android SDK`
4. Installieren Sie:
   - **Android SDK Platform 34** (oder höher)
   - **Android SDK Build-Tools**
   - **Android SDK Command-line Tools**
   - **Android Emulator**
   - **Android SDK Platform-Tools**

#### Option B: Nur Command Line Tools

1. Laden Sie die Command Line Tools herunter
2. Setzen Sie die Umgebungsvariable:
   ```
   ANDROID_HOME=C:\Users\<IhrName>\AppData\Local\Android\Sdk
   ```
3. Fügen Sie zum PATH hinzu:
   ```
   %ANDROID_HOME%\platform-tools
   %ANDROID_HOME%\cmdline-tools\latest\bin
   ```

### Schritt 2: Flutter für Android konfigurieren

Öffnen Sie PowerShell/CMD und führen Sie aus:

```bash
flutter doctor
```

Sie sollten sehen:
```
[✓] Flutter (Channel stable, 3.x.x, on Microsoft Windows...)
[✓] Android toolchain - develop for Android devices
[✗] Xcode - develop for iOS and macOS (not available on Windows)
[✓] IntelliJ IDEA (version 2024.x)
```

Falls Android Probleme zeigt:
```bash
flutter doctor --android-licenses
```
(Akzeptieren Sie alle Lizenzen mit `y`)

### Schritt 3: Android Emulator erstellen

#### In Android Studio:
1. Öffnen Sie den **Device Manager** (Smartphone-Symbol in der Toolbar)
2. Klicken Sie auf `Create Device`
3. Wählen Sie ein Gerät (z.B. **Pixel 7**)
4. Wählen Sie ein System Image (z.B. **Android 14 (API 34)**)
5. Klicken Sie auf `Finish`

#### Über Kommandozeile:
```bash
# Verfügbare System Images anzeigen
sdkmanager --list | findstr "system-images"

# Image installieren (Beispiel für Android 34)
sdkmanager "system-images;android-34;google_apis;x86_64"

# AVD erstellen
avdmanager create avd -n Pixel7 -k "system-images;android-34;google_apis;x86_64" -d pixel_7
```

### Schritt 4: Android Emulator starten

#### In Android Studio:
- Device Manager → Wählen Sie Ihr Gerät → Klicken Sie auf ▶️

#### Über Kommandozeile:
```bash
# Verfügbare AVDs anzeigen
emulator -list-avds

# Emulator starten
emulator -avd Pixel7
```

### Schritt 5: App auf Android testen

```bash
# Ins Projektverzeichnis wechseln
cd Freizeitkasse

# Dependencies installieren
flutter pub get

# Code generieren (wichtig für Drift!)
dart run build_runner build

# Verbundene Geräte anzeigen
flutter devices

# App im Debug-Modus starten
flutter run -d <device-id>

# ODER direkt auf dem Emulator
flutter run
```

### Schritt 6: Physisches Android-Gerät verbinden (Optional)

1. **Entwickleroptionen aktivieren** auf Ihrem Android-Gerät:
   - Gehen Sie zu `Einstellungen` → `Über das Telefon`
   - Tippen Sie 7x auf `Build-Nummer`

2. **USB-Debugging aktivieren**:
   - `Einstellungen` → `Entwickleroptionen` → `USB-Debugging` aktivieren

3. **Gerät per USB verbinden**

4. **Verbindung bestätigen** (Popup auf dem Gerät)

5. **Prüfen**:
   ```bash
   flutter devices
   ```

   Sie sollten Ihr Gerät sehen:
   ```
   SM-G996B (mobile) • R5CRA1234AB • android-arm64 • Android 14 (API 34)
   ```

6. **App starten**:
   ```bash
   flutter run -d R5CRA1234AB
   ```

---

## 🍎 iOS Setup (Einschränkungen unter Windows)

### ⚠️ Grundproblem

**iOS-Apps können NICHT direkt unter Windows kompiliert werden**, da:
- Xcode ist nur für macOS verfügbar
- Apple's Code-Signing erfordert macOS
- iOS Simulator läuft nur auf macOS

### Workaround-Optionen

#### Option 1: Cloud-basierte macOS (Empfohlen für gelegentliches Testing)

**MacStadium** oder **MacinCloud** mieten:
- https://www.macstadium.com/
- https://www.macincloud.com/

**Vorteile:**
- Vollwertiges macOS in der Cloud
- Stundenweise oder monatlich mietbar
- Zugriff über Remote Desktop

**Nachteile:**
- Kostenpflichtig (ab ~$20/Monat)
- Internetverbindung erforderlich
- Latenz bei der Fernsteuerung

**Setup:**
1. Mieten Sie einen Mac in der Cloud
2. Verbinden Sie sich per Remote Desktop
3. Installieren Sie Xcode auf dem Remote-Mac
4. Klonen Sie Ihr Repository
5. Öffnen Sie das Projekt in Xcode
6. Starten Sie den iOS Simulator

#### Option 2: Remote Mac im lokalen Netzwerk

Wenn Sie oder ein Kollege einen Mac besitzen:

1. **SSH-Zugriff auf Mac einrichten**
2. **Code über Git synchronisieren**
3. **Remote-Build über SSH**:
   ```bash
   # Auf Windows
   git push origin claude/setup-mobile-testing-016HuTgieVK76Rhh4AX1qL4J

   # Auf Mac (per SSH)
   git pull
   flutter build ios
   open ios/Runner.xcworkspace
   ```

#### Option 3: Codemagic / Bitrise (CI/CD)

Nutzen Sie CI/CD-Plattformen mit macOS-Agents:

**Codemagic** (https://codemagic.io/):
- 500 kostenlose Build-Minuten/Monat
- Automatische iOS-Builds
- Test auf virtuellen iOS-Geräten

**Bitrise** (https://www.bitrise.io/):
- 90 Minuten kostenlos/Monat
- macOS-basierte Build-Agents

**Setup:**
1. Repository mit Codemagic verbinden
2. `codemagic.yaml` Konfiguration erstellen:
   ```yaml
   workflows:
     ios-workflow:
       name: iOS Workflow
       max_build_duration: 60
       environment:
         flutter: stable
       scripts:
         - name: Get Flutter packages
           script: flutter pub get
         - name: Build Runner
           script: dart run build_runner build
         - name: Build iOS
           script: flutter build ios --release --no-codesign
       artifacts:
         - build/ios/iphoneos/*.app
   ```
3. Push zum Repository triggert automatisch iOS-Build

#### Option 4: Expo/React Native (Nicht anwendbar)

❌ Funktioniert nicht, da Sie bereits eine Flutter-App haben

#### Option 5: Nur Android entwickeln, iOS später

**Pragmatischer Ansatz:**
1. Entwickeln und testen Sie primär auf Android
2. Nutzen Sie responsive Design (bereits implementiert via `ResponsiveFormContainer`)
3. Testen Sie iOS nur vor Releases über eine der obigen Optionen

**Flutter ist sehr plattformübergreifend**, daher sollten 95% der Funktionen auf beiden Plattformen identisch funktionieren.

### iOS Testing Checkliste (wenn Mac verfügbar)

Wenn Sie Zugriff auf einen Mac haben:

```bash
# Auf dem Mac
cd Freizeitkasse

# Dependencies
flutter pub get
dart run build_runner build

# iOS Pods installieren
cd ios
pod install
cd ..

# iOS Simulator starten
open -a Simulator

# App bauen und starten
flutter run -d <simulator-id>
```

**CocoaPods Probleme?**
```bash
# Pods neu installieren
cd ios
rm -rf Pods Podfile.lock
pod install --repo-update
cd ..
```

---

## 🛠️ IntelliJ IDEA Konfiguration

### Flutter Plugin installieren

1. Öffnen Sie IntelliJ IDEA
2. `File` → `Settings` → `Plugins`
3. Suchen Sie nach **Flutter**
4. Installieren Sie das Flutter-Plugin
5. Starten Sie IntelliJ neu

### Projekt öffnen

1. `File` → `Open`
2. Wählen Sie den `Freizeitkasse`-Ordner
3. IntelliJ erkennt automatisch das Flutter-Projekt

### Flutter SDK Pfad setzen

1. `File` → `Settings` → `Languages & Frameworks` → `Flutter`
2. Setzen Sie den **Flutter SDK path** (z.B. `C:\src\flutter`)
3. Klicken Sie auf `Apply`

### Run Configuration erstellen

1. Klicken Sie auf `Add Configuration` (oben rechts)
2. Klicken Sie auf `+` → `Flutter`
3. Konfigurieren Sie:
   - **Name**: `Android Debug`
   - **Dart entrypoint**: `lib/main.dart`
   - **Additional arguments**: (leer lassen oder z.B. `--flavor dev`)
4. Klicken Sie auf `Apply`

### Device Selector nutzen

1. Starten Sie einen Android Emulator
2. Oben rechts in IntelliJ erscheint ein Device-Dropdown
3. Wählen Sie Ihr Gerät
4. Klicken Sie auf ▶️ (Run) oder 🐛 (Debug)

### Hot Reload nutzen

Während die App läuft:
- **Hot Reload**: `Ctrl + S` (speichern) oder ⚡-Symbol
- **Hot Restart**: `Ctrl + Shift + \` oder 🔄-Symbol

### Debugging

1. Setzen Sie Breakpoints (Klick links neben Zeilennummer)
2. Starten Sie im Debug-Modus (🐛)
3. Nutzen Sie die Debug-Konsole für Variablen-Inspektion

---

## 🔧 Troubleshooting

### Android

#### Problem: "No devices found"
```bash
# Prüfen Sie ADB
adb devices

# ADB-Server neustarten
adb kill-server
adb start-server
```

#### Problem: "Gradle build failed"
```bash
# Android-Ordner bereinigen
cd android
./gradlew clean

# In PowerShell (Windows):
cd android
.\gradlew.bat clean
```

#### Problem: "SDK location not found"
Erstellen Sie `android/local.properties`:
```properties
sdk.dir=C:\\Users\\<IhrName>\\AppData\\Local\\Android\\Sdk
```

#### Problem: Emulator startet nicht (Virtualization)
1. BIOS öffnen (beim Boot `F2` / `DEL` drücken)
2. **Intel VT-x** oder **AMD-V** aktivieren
3. In Windows: **Hyper-V** deaktivieren
   ```powershell
   # Als Administrator
   bcdedit /set hypervisorlaunchtype off
   ```
4. PC neu starten

### Flutter Allgemein

#### Problem: "Build runner fails"
```bash
# Bereinigen und neu generieren
dart run build_runner clean
dart run build_runner build --delete-conflicting-outputs
```

#### Problem: "Package not found"
```bash
# Cache bereinigen
flutter clean
flutter pub get
```

#### Problem: "Version conflict"
```bash
# Dependencies aktualisieren
flutter pub upgrade
```

### IntelliJ

#### Problem: "Flutter SDK not found"
1. `File` → `Settings` → `Languages & Frameworks` → `Flutter`
2. Klicken Sie auf `...` neben "Flutter SDK path"
3. Navigieren Sie zu Ihrem Flutter-Installations-Ordner
4. Klicken Sie auf `OK`

#### Problem: "Dart analysis very slow"
1. `File` → `Settings` → `Languages & Frameworks` → `Dart`
2. Deaktivieren Sie **Enable Dart support for the project** kurz, dann wieder aktivieren
3. ODER: Invalidate Caches: `File` → `Invalidate Caches / Restart`

---

## 📝 Empfohlener Workflow

### Für Android-only Entwicklung (Windows)

1. **Entwickeln** in IntelliJ auf Windows
2. **Testen** auf Android Emulator oder physischem Gerät
3. **Vor Release**: iOS über Cloud-Mac oder CI/CD testen

### Für iOS + Android (mit Mac-Zugang)

1. **Entwickeln** auf Windows (IntelliJ)
2. **Android testen** auf Windows
3. **Code pushen** zu Git
4. **iOS testen** auf Mac (per SSH oder lokal)

### Daily Development

```bash
# Terminal 1: App starten
flutter run

# Terminal 2: Logs verfolgen
flutter logs

# Code ändern → Automatisches Hot Reload
# Bei größeren Änderungen: Hot Restart (R drücken)
```

---

## ✅ Setup-Checkliste

### Android
- [ ] Flutter SDK installiert und im PATH
- [ ] Android SDK installiert (via Android Studio)
- [ ] `flutter doctor` zeigt ✓ für Android
- [ ] Android Emulator läuft
- [ ] `flutter devices` zeigt Emulator/Gerät
- [ ] `flutter run` startet die App erfolgreich
- [ ] Hot Reload funktioniert

### IntelliJ
- [ ] Flutter Plugin installiert
- [ ] Projekt geöffnet
- [ ] Flutter SDK Pfad konfiguriert
- [ ] Run Configuration erstellt
- [ ] Device Selector zeigt Geräte
- [ ] Debug-Modus funktioniert

### iOS (Optional)
- [ ] Mac-Zugang vorhanden (lokal/remote/cloud)
- [ ] Xcode auf Mac installiert
- [ ] CocoaPods installiert
- [ ] iOS Simulator funktioniert
- [ ] `flutter run -d ios` startet die App

---

## 🚀 Schnellstart-Kommandos

```bash
# Projekt-Setup (einmalig)
cd Freizeitkasse
flutter pub get
dart run build_runner build

# Android Emulator starten (in separatem Terminal)
emulator -avd Pixel7

# App starten
flutter run

# Während der Entwicklung
# r = Hot Reload
# R = Hot Restart
# q = Quit
# d = Detach (App läuft weiter)
```

---

## 📚 Nützliche Links

- **Flutter Docs**: https://flutter.dev/docs
- **Flutter Windows Setup**: https://flutter.dev/docs/get-started/install/windows
- **Android Studio**: https://developer.android.com/studio
- **Flutter DevTools**: https://flutter.dev/docs/development/tools/devtools
- **IntelliJ Flutter Plugin**: https://plugins.jetbrains.com/plugin/9212-flutter

---

## 🆘 Support

Bei Problemen:

1. **Flutter Doctor** laufen lassen:
   ```bash
   flutter doctor -v
   ```

2. **Logs checken**:
   ```bash
   flutter logs
   ```

3. **Clean Build**:
   ```bash
   flutter clean
   flutter pub get
   dart run build_runner build
   ```

4. **GitHub Issues**: Erstellen Sie ein Issue in Ihrem Repository

---

**Viel Erfolg beim Mobile Testing! 🎉**
