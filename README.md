# MeetingOS

A calm, native iOS meeting notebook. Prepare a short agenda, keep time, capture notes and decisions, track action items, then share a clean summary.

> Less time organizing meetings. More clarity about what happens next.

No accounts, no server, no AI calls. Everything stays on the device.

## Run it

**On iPad (no Mac needed):** download the repo ZIP, unzip it in Files, tap `MeetingOS.swiftpm` and press ▶︎ in Swift Playgrounds.

**On GitHub's Macs:** every push builds the app, runs the unit tests and builds the Playgrounds app (`.github/workflows/build.yml`).

**TestFlight:** add the repo secrets `ASC_KEY_ID`, `ASC_ISSUER_ID` and `ASC_KEY_P8` (same App Store Connect API key as the other Duo apps), create the app `com.ariberkowitz.meetingos` in App Store Connect, then run "Upload to TestFlight" or push a commit with `[testflight]` in its message.

**On a Mac:** `brew install xcodegen && xcodegen`, then open `MeetingOS.xcodeproj`.

## What's in the MVP

| Area | What works |
| --- | --- |
| Home | Start Meeting, Quick start (no setup), in-progress meetings with live timer, upcoming, recent, search across titles, notes, tasks and people, open action item count, first-run empty state |
| Start meeting | Optional title, participants (comma separated), agenda, or schedule for later |
| Live workspace | Editable title and agenda (tick items off), fast note entry, decisions, action items with optional owner and due date, complete, edit, delete, timer in the nav bar |
| End meeting | Timer stops, unsent text can be kept or dropped, summary is saved |
| Summary | Duration, decisions, outstanding and completed tasks, notes, agenda, all editable. Copy as plain text or share through the iOS share sheet. Optional hand-edited summary text with reset |
| History | Reopen any past meeting. All open tasks across meetings in one list |
| Storage | JSON file in Application Support, atomic writes, saved on every change and when the app goes to background. Live meetings survive relaunch |

## The "Duo" layout

A meeting has two things going on at once: **what is being discussed** and **what needs to happen next**. The live workspace is built around that.

- **Wide display (about 600 pt or more):** two panes side by side. Left is title, agenda and notes. Right is action items. Each pane has its own input at the bottom, so you can write a note and add a task without switching.
- **Compact display:** a Notes / Tasks switch. The Notes input can also add a task (Note, Decision, Task picker) so a task is one tap away without leaving your notes. The Tasks tab shows its open count.
- **Timer** sits in the navigation bar as a small pill and never covers content.
- **Summary** on a wide display shows the editable sections on the left and the exact text that will be shared on the right.
- Typed text, the chosen tab and the agenda's collapsed state are kept per meeting in memory, so rotating, unfolding, resizing or switching tabs never loses work.
- The screen stays awake while a meeting is open, which helps when the phone sits on the desk.

The switch is based only on the width the system actually gives the app (`GeometryReader`) and on Dynamic Type size. It works the same in landscape iPhone, iPad, Split View and Stage Manager, and would apply automatically to any wider or unfolded iPhone display.

### What is **not** assumed

- No posture or hinge APIs are used. iOS has no public API for fold state or tabletop posture today, so there is no tabletop-specific layout. If Apple ships one, the place to add it is `LiveMeetingView.workspace`.
- Both halves are one SwiftUI scene. The app never assumes two screens can run separate interfaces.

## Project layout

```
MeetingOS.swiftpm/     All app code. Opens in Swift Playgrounds on iPad.
  App/                 App entry, root navigation, MeetingLibrary (state + saving), LiveDraft
  Sources/Model/       Meeting, AgendaItem, Note, ActionItem, editing rules, JSON store, summary
  Sources/Views/       Home, setup, live workspace and its two panes, summary, shared components
Tests/MeetingOSTests/  Unit tests (lifecycle, editing, summary, persistence)
project.yml            Builds the App Store app and tests from the same code (XcodeGen)
AppAssets/             App icon and accent color. Redraw the icon: python3 scripts/make_icon.py
```

The model and storage files have no SwiftUI dependency and are fully unit tested.

## Adding AI later

`MeetingSummarizing` in `Sources/Model/MeetingSummary.swift` is the seam. The MVP uses `DeterministicSummarizer`, which only formats what the user typed. A future version should:

- Call your own backend, never a model API directly from the app. No keys in the client.
- Throw `SummarizerError` (`missingCredentials`, `networkUnavailable`, `invalidResponse`) and fall back to the deterministic summary.
- Show AI output as a suggestion the user accepts, never as recorded fact.

## Known limitations

- No pause for the timer. Duration is wall-clock time from start to end.
- Out of scope by design: accounts, sync, calendar, recording, transcription, integrations, subscriptions.

## Manual test checklist

1. Quick start, type a note, a decision and a task. Kill the app, relaunch: the meeting is still in progress with the timer running and everything there.
2. Add a task with owner and due date, complete it, reopen it, edit it, delete it.
3. Rotate to landscape (or use iPad): two panes appear. Type in both inputs, rotate back: text is still there.
4. End with text still in an input: you're asked to keep or drop it.
5. On the summary, tap Copy and paste somewhere. Tap Share and pick Mail or Notes.
6. Go home, search for a word from a note, open the past meeting.
7. Try largest Dynamic Type and dark mode on each screen.
