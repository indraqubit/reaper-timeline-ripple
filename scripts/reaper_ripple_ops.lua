-- reaper_ripple_ops.lua
-- Jalankan di REAPER: Actions -> "ReaScript: Run ReaScript (EEL2, Lua, or python)..." (41060)
--
-- EDIT tabel OPS di bawah. Format: { cmd, a, b }
--   cmd 40200 = Insert empty space at time selection (moving later items)
--   cmd 40201 = Remove contents of time selection (moving later items)
--   a,b = batas time selection (DETIK, koordinat ORIGINAL)
--         untuk insert: b = a + lebar_gap
--         untuk remove: [a,b] = rentang yang dibuang
--
-- URUTAN PENTING: susun OPS posisi MENURUN (kanan -> kiri) supaya
-- koordinat tetap valid. Di titik sama: remove dulu, insert sesudah.
-- Kedua action jalan regardless ripple mode, kena semua track + envelope + marker.

local OPS = {
  -- contoh pola (ganti dengan angka project Anda):
  -- {40200, 4169.005, 4169.005 + 18.579},   -- insert gap kanan
  -- {40201,  93.546, 168.241},              -- remove konten
  -- {40200,  93.546,  93.546 + 0.283},      -- insert gap
  -- {40201,  81.437,  87.533},              -- remove konten
  -- {40200,  81.437,  81.437 + 6.052},      -- insert gap
  -- {40200,  23.763,  23.763 + 4.080},      -- insert gap kiri
}

if #OPS == 0 then
  reaper.MB("Tabel OPS kosong. Edit script dan isi operasinya dulu.", "Ripple Ops", 0)
  return
end

reaper.Undo_BeginBlock()
reaper.PreventUIRefresh(1)

local function setsel(a, b)
  reaper.GetSet_LoopTimeRange2(0, true, false, a, b, false)
end

for _, op in ipairs(OPS) do
  setsel(op[2], op[3])
  reaper.Main_OnCommand(op[1], 0)
end

reaper.GetSet_LoopTimeRange2(0, true, false, 0, 0, false)
reaper.PreventUIRefresh(-1)
reaper.UpdateArrange()
reaper.Undo_EndBlock("Ripple ops (" .. #OPS .. " langkah)", -1)

reaper.MB("Selesai: " .. #OPS .. " operasi ripple.\nCtrl+Z untuk membatalkan.", "Ripple Ops", 0)
