#  AirDraw

Aplikasi Flutter yang memungkinkan kamu **menggambar di udara** menggunakan gerakan jari telunjuk secara real-time. AI tracking tangan berjalan langsung di device tanpa koneksi internet (*on-device edge AI*).

---

##  Demo


https://github.com/user-attachments/assets/345134fb-ed6c-4517-9f99-59e083695c0d


---

##  AI & Edge Computing

| Properti | Detail |
|---|---|
| **Model** | MediaPipe Hand Landmarker |
| **Package** | hand_landmarker ^2.2.0 |
| **Inference** | On-device (GPU accelerated) |
| **Internet** | Tidak diperlukan |
| **Landmark** | 21 titik per tangan |

Model mendeteksi 21 landmark tangan secara real-time dari stream kamera, lalu koordinat ujung jari telunjuk (landmark #8) digunakan sebagai posisi kursor gambar.

---

##  Fitur

- **Hand Tracking Real-time** — AI tracking jari menggunakan MediaPipe
- **Air Drawing** — Gambar di udara dengan gerakan jari telunjuk
- **Multi-color** — 8 pilihan warna dengan visual feedback
- **Stroke Width** — Atur ketebalan garis dengan slider
- **Per-stroke Color** — Setiap garis menyimpan warnanya sendiri
- **Spike Filter** — Filter otomatis untuk mengurangi gerakan tiba-tiba
- **Smoothing** — Gerakan jari dihaluskan untuk hasil gambar yang lebih rapi
- **Undo** — Hapus garis terakhir
- **Clear Canvas** — Bersihkan semua gambar

---

##  Setup & Instalasi

### Prasyarat

| Kebutuhan | Versi minimum |
|---|---|
| Flutter SDK | 3.0.0 |
| Dart SDK | 3.0.0 |
| Android SDK | API 24 (Android 7.0) |
| JDK | 17 |

### Clone & Install

```bash
git clone https://github.com/AgungEkaR/air_draw.git
cd air_draw
flutter pub get
```

### Jalankan

```bash
flutter run
```

>  Disarankan menggunakan **device fisik** untuk hasil terbaik. Kamera emulator tidak optimal untuk hand tracking.

---

##  Dependencies

| Package | Kegunaan |
|---|---|
| `hand_landmarker` | MediaPipe hand landmark detection |
| `camera` | Akses kamera device |

---

## 🎮 Cara Pakai

1. Buka app → kamera depan aktif otomatis
2. Arahkan tangan ke kamera
3. **Tap & tahan** tombol "Hold to Draw" → gerakkan jari telunjuk untuk menggambar
4. Lepas tombol untuk berhenti menggambar
5. Pilih warna di bagian bawah
6. Atur ketebalan garis dengan slider
7. Tap ↩️ untuk undo, 🗑️ untuk clear semua

---

##  Catatan: Permission Android

Tambahkan di `AndroidManifest.xml`:

```xml
<uses-permission android:name="android.permission.CAMERA" />
```
