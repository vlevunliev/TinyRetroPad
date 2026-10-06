# Changelog

## 2.8
- **Live sums:** a line `total =` (or `общо =`, `сума =`, `средно =`/`avg =`, `макс =`/`max =`, `мин =`/`min =`, `брой =`/`count =`) fills itself in from the numbers above it and updates as you type. The last number of each line counts. Times, dates and lines ending with `:` are skipped. `1 250,50` and `3.20` both work, and the result keeps your format. One Ctrl+Z undoes a recalculation. *Tools → Live Sums* turns it off.
- **Check boxes:** **Ctrl+Space** toggles `[ ]` → `[x] … ✓ 05.10 17:56` → `[ ]`. It works on several selected lines, and on an empty line it starts a new task. Enter continues the list, and Enter on an empty task ends it. `[х]` typed in Cyrillic also counts as done.
- **Ctrl+Enter on `[ ] 18:30 Call Ivan`** creates a reminder, just like an `@` line.
- **Multi-line scripts:** select several lines and press **Ctrl+Enter**. They run as one `.cmd` script, or as PowerShell / Python when the first line is `#ps` / `#py`. A single line such as `#ps Get-Date` works too.
- **Filter through a command:** **Ctrl+Shift+Enter** sends the selection (or the current line) to a command's stdin, and the command's output replaces it, like `!` in Vim. If the command prints nothing, the text stays as it was. Ctrl+Z restores the original. The last command is remembered.
- **History (time machine):** every Save keeps a version in `%LOCALAPPDATA%\TinyRetroPad\history`. The first save also keeps the version that was on disk before. Identical saves are not duplicated, and the last 100 versions are kept. *File → History* restores a version with one click, and Ctrl+Z goes back.

## 2.7.1
- **Ctrl+D** inserts the weekday, date and time (`понеделник, 05.10.2026 14:32`). The weekday name follows the Windows regional settings.

## 2.7
- **Planner:** `@ <when> <time> <text or command>` + Ctrl+Enter registers a task in Windows Task Scheduler (folder `\TinyRetroPad\`). Bulgarian and English syntax: today/tomorrow, dates, weekdays, every day, every mon,wed, in N min/h.
- Text becomes a reminder (`trpad.exe /remind`): a topmost box, read aloud. Programs and scripts are run.
- One-time tasks delete themselves after running. Missed reminders fire when the PC is back on.
- New **Tools** menu: Run Line, Stop, Scheduled Tasks, Delete Task on This Line, How to Schedule.

## 2.6.1
- `cmd /u` so built-in commands (`dir`, `echo`…) no longer lose Cyrillic (the "г." in dates).
- Fixed a blank line appearing when CRLF arrived split across two pipe reads.

## 2.6
- **Ctrl+Enter runs the current line** through `cmd /c`. Output streams in below the line. Esc kills the whole process tree (job object). `cd` / `D:` persist. `[exit code N]`.

## 2.5
- The reading position is remembered per file, across restarts.

## 2.4
- The spoken word is highlighted while reading aloud.

## 2.3
- Wrong keyboard layout fix (Ctrl+Shift+K / Pause), using the installed layouts.
- Inline calculator (F9).
- Auto-indent.

## 2.2
- Voice and speed selection. OneCore voices from Settings (e.g. Bulgarian) work through SAPI without registry hacks.

## 2.1
- Spell checking, word/character count, change case, Cyrillic ↔ Latin transliteration.
- Recent files, reload prompt on external change.
- Sort / dedup / trim lines.
- Print headers and footers.
- Read aloud (SAPI).
- Autosave and crash recovery.

## 2.0
- Full Unicode (W API). Encoding and line-ending detection, saved back in the same format. Encoding menu.
- Drag & drop, zoom, real status bar, print margins, manifest (visual styles + DPI), settings in the registry, dark title bar.
- Fixes from 1.0:
  - closing with X did not ask to save;
  - the MSGFILTER layout was wrong on Win64;
  - PRINTDLG packing was wrong on Win32;
  - printing could loop forever;
  - RTF paste;
  - Find up / whole word.

## 1.0
- Pascal port of Dave Plummer's `trpad.asm`.
