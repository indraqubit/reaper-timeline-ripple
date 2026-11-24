# REAPER RPP Timeline Edit — Skill

Skill untuk mengedit timeline project REAPER (`.RPP`) multi-track secara massal dan aman: memotong, menggeser, dan menyisipkan ruang kosong di **semua track sekaligus** (ripple), menerapkan edit dari satu sesi "resep" ke sesi besar, serta memindahkan track antar project — tanpa merusak automation, MIDI, subproject, atau take.

## Untuk siapa

Editor film/musik yang harus menyesuaikan ratusan track (musik, SFX, dialog, automation) ke cuttingan video baru, di REAPER.

## Kenapa bukan "edit file .RPP langsung"

Project besar berisi FX-param envelope (`PARMENV`), item MIDI, subproject, multi-take, dan clip ber-playrate ≠ 1. Mengubah file `.RPP` dengan skrip teks akan membuat automation desync, note MIDI dobel, take rusak. Skill ini memakai **engine ripple REAPER sendiri** lewat ReaScript, jadi semua itu ditangani native.

## Isi

```
reaper-rpp-timeline-edit/
├── SKILL.md                       # instruksi utama (untuk agent)
├── reference.md                   # field RPP, skrip parse, skema transform, jebakan
└── scripts/
    └── reaper_ripple_ops.lua      # runner ripple generik (40200 / 40201)
```

## Prasyarat

- REAPER 6 atau 7 (ReaScript/Lua aktif).
- Tidak butuh extension tambahan (tidak butuh SWS).

## Cara pakai cepat

1. **Backup** project: `cp -p project.RPP project.RPP.bak-$(date +%Y%m%d-%H%M%S)`.
2. Tentukan edit di sesi kecil (sesi "resep"): apa yang dipotong, gap berapa di titik mana.
3. Isi tabel `OPS` di `scripts/reaper_ripple_ops.lua` — **urut posisi menurun (kanan → kiri)**, pakai koordinat asli. Remove sebelum insert bila titiknya sama.
4. Di REAPER: `Actions` → `ReaScript: Run ReaScript (EEL2, Lua, or python)...` (Command ID **41060**) → pilih script.
5. Cek hasil. Salah? `Ctrl+Z` (satu undo block membatalkan semua).

Action yang dipakai:
- `40201` — Remove contents of time selection (moving later items)
- `40200` — Insert empty space at time selection (moving later items)

Keduanya bekerja **melampaui mode ripple** dan mengenai **semua track + envelope + marker**.

## Keamanan

- Selalu backup dulu.
- Kalau project sedang terbuka di REAPER, edit file di disk akan tertimpa saat Save — atau sebaliknya. Untuk perubahan berbasis file (sisip track antar project), tutup project **tanpa save** lalu buka ulang.
- Semua operasi dibungkus undo block.

## Instalasi sebagai skill agent

Taruh folder `reaper-rpp-timeline-edit/` di direktori skills milik harness Anda (mis. `~/.claude/skills/`, `~/.cursor/skills/`, atau `.agents/skills/`). `SKILL.md` adalah entry point; `reference.md` dan `scripts/` dipakai sesuai kebutuhan.

## Disclaimer

Uji dulu di salinan project. Skrip ini mengubah timeline; meski ada undo block, selalu punya backup.
