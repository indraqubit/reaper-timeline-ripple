# Reference — REAPER RPP timeline edit

## Field RPP yang relevan

| Baris | Arti |
|---|---|
| `<REAPER_PROJECT DOMAIN "ver/os" id 0` | header; `id` naik tiap save/undo (abaikan saat diff) |
| `CURSOR <t>` | posisi playhead (detik) |
| `SELECTION <a> <b>` / `SELECTION2` | time selection |
| `TIMELOCKMODE 1` | item lock ke **time** (detik absolut) — koordinat ripple valid |
| `RIPPLE 0 0` | mode ripple tersimpan (tidak mempengaruhi 40200/40201) |
| `  <TRACK {GUID}` … `  >` | satu track; penutup `  >` (2 spasi) |
| `    NAME "..."` | nama track |
| `    <ITEM` … `    >` | satu item; penutup `    >` (4 spasi) |
| `      POSITION <t>` | posisi item di timeline (detik) |
| `      LENGTH <t>` | panjang di timeline (detik) |
| `      SOFFS <t>` | offset di media (detik media), BUKAN timeline |
| `      PLAYRATE <r>` | rasio kecepatan; source advance = timeline_advance × r |
| `      <SOURCE VIDEO\|WAVE\|MP3\|MIDI\|RPP` | tipe sumber; `MIDI` & `RPP` tidak boleh di-split manual |

**Kunci:** `SOFFS` = sumber, `POSITION` = timeline. Timeline==source hanya bila `SOFFS==POSITION` dan kontinu.

## Parse: coverage source, gap timeline, cek kesetaraan

```python
import sys
f = sys.argv[1]
lines = open(f, encoding='latin-1').read().replace('\r\n','\n').split('\n')
items, cur = [], None
for l in lines:
    s = l.strip()
    if s.startswith("<ITEM"): cur = {}
    elif cur is not None:
        if s.startswith("POSITION "): cur['pos'] = float(s.split()[1])
        elif s.startswith("LENGTH "): cur['len'] = float(s.split()[1])
        elif s.startswith("SOFFS ") and 'soffs' not in cur: cur['soffs'] = float(s.split()[1])
        elif s.startswith("FILE "): cur['file'] = s[5:].strip().strip('"'); items.append(cur); cur = None

items.sort(key=lambda x: x['pos'])
cov = sorted((it['soffs'], it['soffs']+it['len']) for it in items)
prev, removed = 0.0, []
for s, e in cov:
    if s > prev + 1e-6: removed.append((round(prev,3), round(s,3), round(s-prev,3)))
    prev = max(prev, e)
gaps = [(round(items[i]['pos']+items[i]['len'],3), round(items[i+1]['pos'],3),
         round(items[i+1]['pos']-(items[i]['pos']+items[i]['len']),3)) for i in range(len(items)-1)]
print("removed source:", removed)   # rentang konten yang dibuang
print("timeline gaps:", gaps)       # celah kosong di layout akhir
```

Cek cepat timeline==source satu track:
```python
print(all(abs(it['soffs']-it['pos'])<1e-6 for it in items))   # True = timeline==source
```

Cek kerumitan sebelum memutuskan metode:
```bash
grep -oE '^      PLAYRATE [0-9.]+' X.RPP | sort | uniq -c   # playrate != 1?
grep -c '<SOURCE MIDI' X.RPP                               # MIDI item
grep -c '<SOURCE RPP'  X.RPP                               # subproject item
grep -c '<PARMENV'     X.RPP                               # FX-param envelope
grep -c '^      TAKE'  X.RPP                               # multi-take
```
Ada MIDI / subproject / PARMENV / playrate≠1 → **wajib ReaScript ripple**, jangan rewrite file.

## Skema transform (piecewise, original timeline)

```
retained: [a,b) with offset o   ->  new_pos = orig + o
removed:  [x,y)                 ->  buang
```

Tiap item `[p, p+L)`:
- iris per segmen retained `[s0,s1)`
- `new_pos = s0 + o`, `new_len = s1 - s0`
- `new_soffs = soffs + (s0 - p) * playrate`
- sobek FADEIN/FADEOUT: hanya piece pertama pertahankan fade-in asli, piece terakhir fade-out asli, sisanya 0.

Gap tidak perlu dioperasikan eksplisit — muncul otomatis dari selisih offset antara dua segmen bersebelahan:
`gap = (new_start_segmen_kanan) - (new_end_segmen_kiri)`.

## Urutan operasi ripple (kanan → kiri)

Ripple (40200/40201) hanya menggeser konten di kanan titik edit. Proses menurun posisi ⇒ tiap operasi memakai koordinat **aslinya**.

```
ops = sorted(ops, key=pos, reverse=True)
```
Tie di titik sama: **remove dulu**, baru **insert**.

Bukti singkat: op kiri dieksekusi belakangan memakai koordinat asli karena semua op yang sudah dijalankan berada di kanan (tak menggeser titik kiri). Setelah op kiri jalan, konten kanan ikut bergeser (benar), tapi koordinat kanan tak dipakai lagi.

## Menyisipkan track antar project

```python
src = open("SRC.RPP", encoding='latin-1').read().replace('\r\n','\n').split('\n')
starts = [i for i,l in enumerate(src) if l.startswith("  <TRACK")]
s = starts[1]                                        # mis. track ke-2 di sumber
e = next(i for i in range(s+1, len(src)) if src[i] == "  >")
block = src[s:e+1]                                   # termasuk penutup track
```
- Cek GUID: `grep -c '<guid>' TARGET.RPP` harus 0 (track GUID, TRACKID, IGUID, item GUID).
- Sisipkan setelah penutup track acuan (`  >`).
- Tulis ulang dengan CRLF: `("\r\n".join(out)).encode('latin-1')`.
- Validasi: hitung `  <TRACK` naik 1, blok well-formed, file ditutup `>`.

## Jebakan

- **REAPER open**: edit disk hilang saat Save. Tutup tanpa save → buka ulang.
- **CRLF**: jangan tulis `\n` saja; convert ke `\r\n`.
- **`ffprobe` bisa rusak** (mis. `Library not loaded: libass`). Andalkan durasi dari `LENGTH` item, bukan ffprobe.
- **Track referensi** (video cut baru) jangan di-cut; biarkan utuh sebagai acuan.
- **Jangan tebak action ID**: `40201` = remove contents (moving later), `40200` = insert empty space (moving later), `41060` = Run ReaScript. Verifikasi dari dokumentasi Cockos bila ragu.
