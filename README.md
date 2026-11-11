# IPTV Box (Android TV / Android Box, Kotlin + Compose + Media3)

## APK üretme (GitHub)
1. Yeni boş bir repo açın, bu klasörün TÜM içeriğini repo köküne yükleyin
   (`settings.gradle.kts`, `app/`, `.github/` yan yana olmalı; `git push` en güvenlisi).
2. Actions > Build APK > Run workflow.
3. Bitince Artifacts > `IPTVBox-apk` > zip içinden `app-debug.apk`.
   (Debug anahtarıyla imzalıdır, doğrudan kurulabilir.)

## Kutuya kurma
- USB bellek + dosya yöneticisi ile, veya kutuda "Downloader" uygulamasıyla, veya `adb install app-debug.apk`.
- Ayarlar > Güvenlik > Bilinmeyen kaynaklardan kurulum izni verin.

## Kumanda
- Yukarı/Aşağı: kanal değiştir (oynatırken) · OK: duraklat/devam · Geri: listeye dön
- Listede OK basılı tutma: favori ekle/çıkar
