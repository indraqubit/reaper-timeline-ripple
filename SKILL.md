---
name: "reaper-rpp-timeline-edit"
description: "Ubah timeline project REAPER (.RPP) multi-track secara massal: ripple cut / insert ruang kosong di semua track, menerapkan edit dari sesi referensi ke sesi besar, dan menyisipkan track antar project. Gunakan saat pengguna minta potong/geser/cut-paste track REAPER, samakan timing semua track ke sebuah guide, atau pindahkan track dari satu .RPP ke .RPP lain."
---

# REAPER RPP timeline edit (multi-track, ripple, lintas project)

Dipakai saat pengguna minta operasi cut/paste/geser/ripple pada project REAPER `.RPP`, menerapkan edit sesi referensi ke sesi besar (sinkron semua track), atau memindah/menyisipkan track antar `.RPP`.

## Aturan keras

1. **JANGAN rewrite `.RPP` besar dengan tangan.** Project film/skor berisi `PARMENV` (FX-param envelope), `<SOURCE MIDI`, `<SOURCE RPP` (subproject), multi-take, dan `PLAYRATE ≠ 1`. Rewrite manual item saja akan bikin automation desync, MIDI note dobel, take rusak. **Biarkan REAPER yang melakukan ripple** (engine-nya menangani envelope + MIDI + subproject + take + playrate native).
2. **Backup dulu**, tiap kali menyentuh file: `cp -p "X.RPP" "X.RPP.bak-$(date +%Y%m%d-%H%M%S)"`, verifikasi `shasum -a 256`.
3. **Kalau REAPER sedang membuka project**, edit file di disk akan ditimpa saat Save. Setelah edit disk: tutup project **tanpa save**, lalu buka ulang.
4. File `.RPP` umumnya **CRLF** — pertahankan.

## 1. Baca struktur RPP

Field kunci per item: `POSITION` (timeline detik), `LENGTH` (timeline detik), `SOFFS` (offset di media, bukan timeline), `PLAYRATE`, `FILE`, `NAME`.

- **Timeline == source** bila tiap item `SOFFS == POSITION` dan kontinu (item end == item berikutnya start), total == durasi media. Cek dulu sebelum berasumsi.
- Item spanning batas cut → nanti harus **split**; jangan diasumsikan per-item.

Lihat [reference.md](reference.md) untuk skrip parse (coverage source, gap timeline, cek SOFFS==POSITION, cek playrate/multi-take).

## 2. Turunkan transform dari sesi referensi

Dua peran terpisah: **sesi referensi/sandbox** (`scratch.RPP`) = tempat edit *ditentukan*, jadi "resep"; **sesi target** (`target.RPP`) = tempat resep *dieksekusi* ke semua track. Resep diturunkan di sesi kecil, lalu diterapkan global di sesi besar.

Dari sesi scratch, bandingkan item asli vs akhir untuk dapat:
- **Removed source ranges** (konten dibuang) = bagian [0,durasi] yang tidak tercakup item mana pun.
- **Gap timeline** = celah antar item di layout akhir.
- **Offset per segmen**: `off = new_pos - orig_pos`. Gap muncul otomatis dari selisih offset antar segmen.

Model transform = fungsi piecewise on **original timeline**:
```
segmen retained: [a,b) -> off
diremove:        [x,y)
```
Untuk tiap item `[p,p+L)`, potong ke tiap segmen retained; piece baru:
`new_pos = s0+off`, `new_len = s1-s0`, `new_soffs = soffs + (s0-p)*playrate`. (Kalau tidak menulis file, ini hanya untuk memastikan matematika ripple-nya benar.)

## 3. Terapkan via ReaScript ripple (metode utama)

Pakai `scripts/reaper_ripple_ops.lua`. Isi tabel `OPS` dengan operasi, lalu jalankan di REAPER: `Actions` → `ReaScript: Run ReaScript (EEL2, Lua, or python)...` (Command ID **41060**) → pilih file.

Action native yang dipakai:
- `40201` = **Remove contents of time selection (moving later items)**
- `40200` = **Insert empty space at time selection (moving later items)**

Keduanya jalan **regardless mode ripple**, kena **semua track + envelope + marker**. Operasi dibungkus satu undo block (`Ctrl+Z` membatalkan semua).

### Trik koordinat: proses KANAN → KIRI di koordinat ASLI

Ripple hanya menggeser konten di **kanan** titik edit. Jika operasi diproses urut posisi menurun, tiap operasi selalu dieksekusi di koordinat **aslinya** — tidak ada drift, tak perlu hitung ulang offset. Contoh urutan gabungan remove + insert:

```
1 insert @T3  w=...        (gap terkanan)
2 remove [A2,B2]
3 insert @A2  w=...
4 remove [A1,B1]
5 insert @A1  w=...
6 insert @T1  w=...
```
Aturan tie di titik yang sama: **remove dulu, insert sesudah**.

Verifikasi hasil: project end = `durasi_awal - Σremoved + Σgaps`; spot-check track guide vs layout scratch.

## 4. Menyisipkan track antar `.RPP`

1. Ekstrak blok track dari sumber: dari baris `  <TRACK ...` sampai baris penutup `  >` (2 spasi) berikutnya. Item menutup dengan `    >` (4 spasi), track dengan `  >`.
2. **Cek bentrok GUID** dulu: `grep -c '<TRACK_GUID_ATAU_ITEM_GUID>' target.RPP` harus `0`.
3. Sisipkan blok setelah penutup track acuan.
4. Tulis kembali dengan CRLF, lalu validasi: jumlah `TRACK` naik 1, blok well-formed, file tetap ditutup `>`.
5. Ingat aturan REAPER-open (tutup tanpa save → buka ulang).

Track referensi (video cut baru) **jangan** di-cut — biarkan utuh sebagai acuan.

## Checklist

- [ ] Backup dibuat + sha dicek
- [ ] Verifikasi timeline==source (SOFFS==POSITION) sebelum asumsi
- [ ] Operasi ripple disusun kanan→kiri, koordinat asli, remove-sebelum-insert saat tie
- [ ] Dijalankan lewat ReaScript (bukan rewrite RPP) di project besar
- [ ] Undo block ada; hasil diverifikasi (end time + spot-check)
- [ ] Track insert: GUID tidak bentrok, posisi benar, CRLF
- [ ] Kalau REAPER open: close tanpa save lalu reopen

## Sumber daya

- [reference.md](reference.md) — field RPP, skrip parse Python, skema transform, jebakan.
- [scripts/reaper_ripple_ops.lua](scripts/reaper_ripple_ops.lua) — runner ripple generik.
