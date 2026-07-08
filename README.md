# TCO Agreement Generator

A tool for creating client **service agreements** for **TCO (The Contractors Office)**.
It runs on your own computer, in your web browser. There is nothing to install, no
account to create, and it works without an internet connection (the optional AI
drafting feature is the only part that goes online).

It comes pre-loaded with TCO's real setup:

- **Your 4 services** — Bookkeeping, Accounts Payable & Payroll, Billing Administration,
  and Reception & Outbound Calling — each with its standard agreement wording, plus an
  **Other / Custom** option for anything else.
- **Combined agreements** — tick any two (or more) services to generate one combined
  agreement (e.g. Bookkeeping + Accounts Payable & Payroll) with the wording, fees, and
  packages of both merged properly.
- **Your packages & prices** — all 5 Bookkeeping packages ($500–$7,000) and all
  3 Reception packages ($500–$3,500), with each package's own add-on prices.
- **Your legal clauses** — Confidentiality, Limitation of Liability, Hold Harmless &
  Indemnification, Term & Termination, and Annual Pricing Review.
- **Your branding** — the TCO logo and colours are built in.
- **AI drafting from meeting notes** — paste notes or a client's email and Claude fills
  in the whole agreement for you to review (see below).

---

## ⚠ Important legal note (please read)

The legal wording in this tool started from your existing agreements, but it is
**NOT legal advice**. Before sending agreements to clients, have a **qualified
attorney review and approve every clause**, then paste the approved wording into
**Settings → Legal clauses**.

---

## The desktop app (recommended — one program, Windows & Mac)

The app ships as a single desktop program with the TCO logo as its icon.
Everything is inside it: the agreement generator, PDF saving, and one-click
AI drafting on your Claude subscription.

**Windows**
1. Download `TCO-Agreement-Generator-Windows.zip`, right-click → **Extract All…**
   to a permanent folder (e.g. `Documents`).
2. Open the extracted folder and double-click **`TCO Agreement Generator.exe`**.
   First run only: if SmartScreen appears, click **More info → Run anyway**.
3. Right-click the exe → **Send to → Desktop (create shortcut)**, or pin the
   running app to your taskbar.

**Mac**
1. Download the Mac ZIP that matches your machine — **Apple Silicon** (M1/M2/M3/M4)
   or **Intel** — and double-click it to unzip.
2. Drag **TCO Agreement Generator.app** into **Applications**.
3. First run only: **right-click the app → Open → Open** (it isn't signed with an
   Apple developer certificate, so a normal double-click is blocked the first time).

**One-click AI drafting:** install **Claude Code** from claude.ai/download and sign
in once with your Claude account — the app finds it automatically and "Draft with
Claude" runs on your subscription. No other setup.

Your data (prices, wording, drafts) is stored by the app on your computer and saves
automatically. Use *Settings → Download backup* now and then.

---

## Alternative: run it from the plain file

`index.html` is the same app as a single file — double-click it and it opens in
your web browser (Chrome or Edge work best). Handy if you can't install anything.

---

## Drafting from meeting notes (AI)

At the top of the New Agreement page there's a **"Draft from meeting notes"** box.
Paste your meeting notes or a client's email (or upload a .txt file), and Claude reads
them and fills in the whole agreement — services, client details, package, add-ons,
fees, and client-specific scope points. **Always review before sending.**

### Option A — one-click with your Claude subscription (recommended, no extra cost)

Your claude.ai subscription can't be plugged into other apps directly, but it **does
include Claude Code**, which runs on your computer.

- **Desktop app:** just install Claude Code from
  [claude.ai/download](https://claude.ai/download) and sign in once with your Claude
  account. The app detects it automatically — "Draft with Claude" then works in one
  click, billed to your subscription, no API key ever.
- **Plain `index.html` in a browser:** additionally run the small **TCO AI Helper**
  (`tco_ai_helper.py` / `TCO-AI-Helper.ps1`, in this repository) and leave its window
  open; it bridges the browser to Claude Code. It only listens on your own computer
  (`127.0.0.1`) — nothing is exposed to the network.

*Settings → AI assistant → Test Claude connection* confirms it's working.

### Option B — claude.ai in a browser tab (zero setup)

Click **"Open claude.ai with prompt"** — a claude.ai chat opens with the prompt ready
(it's also copied to your clipboard). Send it, then copy Claude's reply into the
**"Paste Claude's reply"** box → **Apply**. Also runs on your subscription.

### Option C — API key (optional)

Paste an Anthropic **API key** into *Settings → AI assistant* (from
[console.anthropic.com](https://console.anthropic.com); pay-per-use, a typical draft
costs a few cents). Only used when the helper isn't running.

Privacy note: with every method, the notes you paste are sent to Anthropic (Claude)
to be read — don't include anything you wouldn't put in a Claude chat.

---

## Making an agreement (the everyday steps)

1. **Choose the service** — or tick several for a **combined agreement** (e.g.
   Bookkeeping + Accounts Payable & Payroll). Use **Other / Custom** for anything else.
   The standard wording and default fees load automatically.
2. Fill in the **client details** (business name, representative, effective date).
3. Build the **fees**:
   - **＋ Package** — inserts a pricing package (the "most popular" one is pre-selected;
     switch it from the drop-down).
   - **＋ Add-on** — package add-ons with their correct prices (e.g. Allocating by Job).
   - **＋ One-time / Monthly / Per-unit fee** — for custom pricing like $10 per payment
     or a $1,000 monthly retainer.
   - **＋ Seasonal pricing** — different prices for different periods (e.g. tax season
     vs off season).
   - **＋ Project calculator** — line items (qty × rate) with automatic subtotal,
     discount, and grand total — perfect for historical cleanup projects.
   - **💾 Insert a saved rate** — drops in one of your common fees (onboarding $300,
     $2/transaction cleanup, etc.).
   Totals calculate automatically and appear in the agreement.
4. (Optional) Open **"Wording for this client"** to tweak the scope, limitations, or
   responsibilities for this one agreement.
5. (Optional) Untick any **legal section** you want to leave out this time.
6. Watch the live preview on the right — that is exactly what the PDF will look like.
7. Click **⬇️ Save as PDF**, set the destination to **"Save as PDF"**, and save.
   Email that PDF to your client.

---

## Settings (change anything, any time)

Open the **Settings** tab:

- **Company & branding** — contact details, logo, and brand colours (your TCO logo
  and navy/green colours are already built in).
- **Services, packages & standard wording** — edit package prices and add-ons,
  what each package includes, and the standard agreement wording per service.
  You can also add entirely new services or packages.
- **Saved rates** — manage your list of common fees.
- **Legal clauses** — edit the standard clause wording (see the legal note above),
  the acceptance statement, and the default payment terms.

Your changes save automatically **on this computer**, and every **new** agreement
starts from your updated settings — so the annual pricing review is just a few edits
here, once a year.

---

## Don't lose your work: Backup

Because your settings are saved inside this browser, keep a backup:

- **Settings → Download backup** saves one small file with all your packages, prices,
  wording, and branding.
- **Settings → Restore from backup** loads it back — also how you move to a
  **new computer** (copy `index.html` over, open it, restore your backup).

---

## Frequently asked

**Do I need the internet?** No. Everything runs on your computer.

**Where are my agreements saved?** Each finished agreement is saved by you as a PDF
when you click *Save as PDF* (the file name is set to the client's name automatically).
The tool remembers your settings and the agreement you're currently working on, but
doesn't keep a library of past agreements — your PDFs are the record.

**I changed computers / cleared my browser and my setup is gone.** Restore it from your
backup file (Settings → Restore from backup). This is why the backup matters. Even with
no backup, the built-in TCO defaults (services, packages, prices, wording) are always
there — you'd only lose your own edits.

**Prices changed — do I edit the code?** No. Settings → the service → change the number.
Done.

**Can I start over completely?** Settings → *Reset everything to TCO defaults*.
Download a backup first if you might want your current setup again.
