# Emoji Tahmin Oyunu — Flutter Projesi

## Proje Özeti
Türkçe, offline çalışan bir Emoji Tahmin oyunu. Emoji kombinasyonlarından film, dizi, atasözü, deyim, şarkı vb. tahmin edilir. Tek oyunculu (solo) modda çalışır. Seviye/bölüm sistemi vardır.

## Teknik Stack
- Flutter 3.x, Dart 3.x, null safety zorunlu
- State Management: Riverpod (flutter_riverpod + riverpod_annotation)
- Local Storage: Hive (hive_flutter)
- Navigasyon: GoRouter
- Monetizasyon: in_app_purchase + google_mobile_ads
- Mimari: Clean Architecture (feature-based)

## Kurallar
- Tüm UI metinleri Türkçe olacak
- Her dosya tek bir sorumluluk taşımalı
- Tüm widget'lar const constructor kullanmalı (mümkün olduğunca)
- Kod tamamen null-safe olmalı
- Her yeni özellik mevcut kodu bozmamalı
- Placeholder veya TODO bırakma, tam çalışan kod yaz

## Klasör Yapısı
lib/
├── core/           # Tema, sabitler, ortak widget'lar
├── features/
│   ├── home/
│   ├── categories/
│   ├── levels/
│   ├── game/
│   ├── hint/
│   └── purchase/
├── models/
├── services/
├── providers/
└── main.dart

## JSON Soru Formatı
{
  "id": "movies_1",
  "emojis": "🦁👑",
  "answer": "Aslan Kral",
  "category": "Filmler",
  "categoryId": "movies",
  "difficulty": 1,
  "letterCount": 8,
  "isPremium": false
}

## Oyun Mekaniği
- Kullanıcıya emojiler gösterilir
- Altta karışık harfler bulunur (cevaptaki harfler + rastgele ekstra harfler)
- Kullanıcı harflere tıklayarak cevabı oluşturur
- Boşluk karakterleri otomatik yerleştirilir
- Doğru cevap → sonraki soruya geç + puan kazan
- Yanlış cevap → harfler sıfırlanır, tekrar dene
- İpucu sistemi: harf açma, yanlış harfleri eleme (coin veya reklam ile)
