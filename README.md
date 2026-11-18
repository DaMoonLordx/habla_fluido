# Habla Fluido (Flutter + proxy Node + TDD)

Código del manual "Manual paso a paso con TDD: Habla Fluido" (UTNG).

```powershell
flutter create .          # genera android/ios/windows (no pisa lib/ ni pubspec.yaml)
flutter pub get
flutter test              # pruebas de Dart
cd proxy; node --test     # pruebas del proxy (12)
flutter run               # tutor simulado, sin internet
```

Para las capturas en orden ROJO -> VERDE:

```powershell
powershell -ExecutionPolicy Bypass -File .\capturas_habla_fluido.ps1
```
