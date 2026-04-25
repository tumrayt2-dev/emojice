# Emojice — Oturum Devri (2026-04-24 → 2026-04-25)

Bu dosya bu session'dan yarınki session'a geçiş notudur. Yarın ilk iş olarak bu dosyayı oku.

## Proje Durumu

- Klasör: `C:\Projects\Emojice`
- Flutter 3.41.6, `flutter analyze` → 0 hata, `flutter test` → 1/1 GREEN
- Puzzle toplam: **386** / **20 kategori** (12 Nisan session'unda 166 idi)
- Play Store publish öncesi blokerler: applicationId (`com.example`), keystore, gerçek AdMob ID'ler, launcher icon, privacy policy, splash asset, iOS Info.plist GADApplicationIdentifier

## Bu Session'da Yapılan Büyük İşler

### 1. Series Audit + Fix (20 → 8 uygulandı, 2 backlog)
- `audit series` çalıştırıldı, 10 düşük skorlu bulundu
- 8 kart skor 4+ fix ile uygulandı (Kara Sevda, Bir Zamanlar Çukurova, vb.)
- 2 kart skor 3'te kaldı → backlog: turkish_series_11 (Bizim Aile), turkish_series_13 (Gençlik)

### 2. Kategori Yeniden Yapılandırması — 8 → 20 kategori
- `movies` → `foreign_movies` (22 puzzle taşındı)
- `series` → `turkish_series` (14) + `foreign_series` (6) olarak bölündü
- 11 yeni kategori eklendi: turkish_movies, jobs, sports, turkish_food, places, history, celebrities, books, cartoons, technology, mythology

### 3. Tüm 146 puzzle audit edildi, 11 fix uygulandı
- Pide (baget→🫓🧆🇹🇷), Ayran (cacık salatalık kaldırıldı), Çay (limon kaldırıldı)
- Proverbs: Bir Elin Nesi Var (el emojisi eklendi), İt Ürür (kervan eklendi), Armut (elma→🍐)
- Idioms: Dili Tutulmak (💀→🤐), Gözü Dönmek (🟢→💫)
- Countries: Portekiz, Güney Afrika — Türk oyuncuya daha net ipuçları
- foreign_movies: Ted → 🧸😈💬 (bira/sigara yerine yaramaz ayı, Play Store politikası)

### 4. Songs Kategorisi Yeniden Kuruldu (Seçenek B)
- 13 jenerik tek kelime + 3 tautoloji (Piyano=🎹🎼, Yıldızlar=🌟✨, Zaman=🕰⏳) silindi
- 13 yeni spesifik şarkı eklendi (Tarkan Şımarık, Barış Manço Dağlar Dağlar, Hadise Düm Tek Tek, Gülşen Yatcaz Kalkcaz Ordayım, vb.)
- 7 eski iyi kart korundu (Gülpembe, Kara Sevda, vb.)
- Sonuç: 20 kart, kadın sanatçı dengesi + dönem çeşitliliği

### 5. Yeni İçerik Üretimi — Wave 1+2+3 (220 kart)
- Wave 1: turkish_movies (20), jobs (20), sports (20)
- Wave 2: turkish_food (20), places (20), history (20), celebrities (20)
- Wave 3: books (20), cartoons (20), technology (20), mythology (20)
- Her kategori için kalite kapısı: min skor 4, 2 tur revize döngüsü

### 6. Kilitli Kategori Sistemi (Tier + Reklam Bypass)

Bugün kodlandı, YARIN TEST EDİLECEK. 7 dosya güncellendi/oluşturuldu.

#### Tier Yapısı
| Tier | Şart | Kategoriler | Reklam |
|---|---|---|---|
| T1 | Açık | animals, food, proverbs | — |
| T2 | 20 çöz | turkish_series, turkish_movies, jobs, idioms(+proverbs 15) | 3 |
| T3 | 60 çöz | foreign_series, foreign_movies, songs, sports, turkish_food(+food 15) | 5 |
| T4 | 120 çöz | countries, places, history, celebrities, books | 7 |
| T5 | 220 çöz | cartoons, technology, mythology(+history 10) | 10 |

#### Dosya Değişiklikleri (kilitli kategori sistemi)
1. `assets/data/categories.json` — her kategoriye `unlock` bloğu
2. `lib/models/category.dart` — `UnlockRequirement` + `UnlockType` enum
3. `lib/models/player_progress.dart` — `categoryUnlockAds: Map<String, int>` alanı + `totalSolvedCount` getter + `unlockAdsFor()`
4. `lib/services/progress_service.dart` — `incrementUnlockAd(categoryId)` method
5. `lib/services/unlock_service.dart` — **YENİ** saf hesap servisi, `statusFor()` + `unlockedIds()`
6. `lib/providers/service_providers.dart` — `unlockServiceProvider`
7. `lib/features/categories/category_selection_screen.dart` — kilit UI (opacity + 🔒) + tıklama guard + `_LockedBottomSheet` (şart metni + ilerleme + "Reklam İzle (+1)" butonu)
8. `lib/providers/game_controller.dart` — karışık mod sadece açık kategorilerden puzzle çeker

## YARIN İLK İŞ — TEST LİSTESİ

Kilitli kategori sistemini Android emülatörde/cihazda test et:

### Temel Davranış
- [ ] İlk açılışta T1 (animals, food, proverbs) açık, diğerleri kilitli gösterilmeli
- [ ] Kilitli kart görünümü: opak + 🔒 overlay + gri border
- [ ] Kilitli karta tıklayınca bottom sheet açılmalı (navigasyon YOK)
- [ ] Bottom sheet: kategori adı + ikon + şart metni + ilerleme çubuğu + reklam butonu
- [ ] 20 bulmaca çözünce T2 kategorileri otomatik açılmalı (animals/food/proverbs'ten karışık 20)
- [ ] Zincir şartı: idioms açılması için proverbs'ten 15 çözme gerekli
- [ ] 60 bulmaca → T3, 120 → T4, 220 → T5

### Reklam ile Bypass
- [ ] T2 kategorisi için "Reklam İzle" 3 kez izlenince kategori açılmalı
- [ ] Reklam sayacı biriktirilmeli (art arda zorunlu değil, kapatıp açınca korunmalı)
- [ ] Rewarded ad yüklenemezse mock fallback (3s dialog) çalışmalı
- [ ] Provider invalidate sonrası UI yenilenmeli (reklam izleyince kart hemen açılmalı)

### Karışık Mod
- [ ] Ana menüdeki "🎁 Bedava Jeton" ve "Karışık" butonları çalışmalı
- [ ] Karışık moddaki puzzle'lar YALNIZ açık kategorilerden gelmeli (kilitli kategori puzzle'ı çıkmamalı)
- [ ] İlk açılışta karışık sadece animals+food+proverbs havuzundan çeksin (44+22=~64 puzzle)

### Geriye Uyumluluk
- [ ] Eski kayıt (categoryUnlockAds alanı olmayan) yüklenince crash OLMASINI — 0 reklam başlangıçlı fallback
- [ ] Başarım sistemi (AchievementService) dinamik kategori listesiyle çalışıyor — kilit başarımı etkilemez ama kilitli kategori için ilerlemezse başarım açılmaz

### Bulunabilecek Sorunlar (önceden düşün)
- Hive box'ındaki ESKİ kayıt yeni alan olmadan yüklenirken sorun çıkabilir — geriye uyumlu kod yazıldı ama test et
- Reklam butonunda birden fazla hızlı tıklama → `_watchingAd` guard var
- Bottom sheet açıkken geri butonu çalışmalı

## Sıradaki Öncelikler (kilitli kategori test sonrası)

1. **Play Store publish checklist** — blokerleri halletmek:
   - applicationId değiştir
   - Gerçek AdMob ID'leri (şu an test)
   - Launcher icon
   - Privacy policy URL
   - Splash asset
   - iOS Info.plist GADApplicationIdentifier
   - Keystore
2. **Backlog kartlar** — turkish_series_11 (Bizim Aile) + turkish_series_13 (Gençlik) için cevap değişikliği veya kaldırma
3. **Opsiyonel UX:** Kilitli kategoriyi ana menüde karışık moda dahil ettirme ipucu

## Dizinler ve Referanslar

- Proje: `C:\Projects\Emojice`
- Puzzle JSON: `C:\Projects\Emojice\assets\data\puzzles.json` (386 puzzle)
- Kategoriler: `C:\Projects\Emojice\assets\data\categories.json` (20 kategori + unlock)
- Puzzle backup: `C:\Projects\Emojice\assets\data\puzzles.json.bak` (movies bölme öncesi)
- Audit raporları: `C:\Projects\Emojice\generated_content\audit_reports\`
  - `series_20260424_1354.json` (series ilk audit)
  - `all_20260424_1500.json` (tam audit)
- Fix raporları: `C:\Projects\Emojice\generated_content\`
  - `fixes_series_20260424_1354.json`
  - `fixes_all_20260424_1500.json`

## Son Puzzle Dağılımı

```
animals: 22        foreign_movies: 22    proverbs: 20
books: 20          foreign_series: 6     songs: 20
cartoons: 20       history: 20           sports: 20
celebrities: 20    idioms: 20            technology: 20
countries: 20      jobs: 20              turkish_food: 20
food: 22           mythology: 20         turkish_movies: 20
                   places: 20            turkish_series: 14
TOPLAM: 386 puzzle / 20 kategori
```
