<div align="center">

# 🖥️ AnyDesk Block Remover

**Stuck on "_commercial use suspected_" or "_session ended_" on the free AnyDesk?**
This resets your local AnyDesk **ID** so the block is lifted — while **keeping your saved PC IDs** (favorites / address book).

Works on **Windows** and **Linux**. One command. No install.

</div>

---

## ⚠️ Read this first

- This tool **resets your own machine's AnyDesk ID**. That's the standard fix for the free-tier block on a personal computer. Use it only on machines you own.
- Your **saved PC IDs** (the favorites / address book) are stored in `user.conf`. This tool **deliberately keeps that file**, so your saved connections should survive.
- **But please write down any IDs/aliases you care about first.** A full backup is made automatically, yet no reset can be 100% guaranteed.
- A timestamped backup of your entire AnyDesk config is saved to your home/user folder before anything is deleted.

---

## 🚀 One-command fix

### Windows (PowerShell)

Open **PowerShell** (it will ask for Administrator automatically) and paste:

```powershell
$f="$env:TEMP\fix-anydesk.ps1"; irm https://raw.githubusercontent.com/trongio/anydesk_block_remove/main/fix-anydesk.ps1 -OutFile $f; powershell -NoProfile -ExecutionPolicy Bypass -File $f
```

### Linux (Terminal)

```bash
curl -fsSL https://raw.githubusercontent.com/trongio/anydesk_block_remove/main/fix-anydesk.sh | sudo bash
```

That's it. Reopen AnyDesk — you'll have a **new ID** and the block should be gone.

---

## 🔧 What it does

1. **Stops** the AnyDesk service and any running AnyDesk processes.
2. **Backs up** your full AnyDesk config to a timestamped folder in your home directory.
3. **Deletes** only the identity / block-state files (`service.conf`, `system.conf`, trace files) — these regenerate with a fresh, unblocked ID.
4. **Keeps** `user.conf` so your saved PC IDs / favorites stay intact.
5. **Restarts** the service so AnyDesk comes back with a clean ID.

### Flags

| Flag | Windows | Linux | Effect |
|------|---------|-------|--------|
| Skip confirmation | `-Yes` | `-y` / `--yes` | Don't prompt before resetting |
| No backup | `-NoBackup` | `--no-backup` | Skip the safety backup |

---

## 📍 Where your data lives

| | Windows | Linux |
|---|---|---|
| Identity (reset) | `%PROGRAMDATA%\AnyDesk\`, `%APPDATA%\AnyDesk\` | `~/.anydesk/`, `/etc/anydesk/` |
| Saved IDs (kept) | `…\AnyDesk\user.conf` | `~/.anydesk/user.conf` |

---

## 🛟 Restore

If anything looks wrong, just copy the files back from the
`AnyDesk-backup-<timestamp>` folder created in your home/user directory,
then restart AnyDesk.

---

## 📜 License

MIT — see [LICENSE](LICENSE). Provided as-is, for use on your own machines.
