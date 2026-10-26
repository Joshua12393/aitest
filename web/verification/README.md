# Implementation verification — 2026-10-26

- `../run.ps1 -Mode test`: **25 PlUnit tests passed** on the existing local SWI-Prolog runtime.
- `../smoke.ps1`: **23 HTTP integration checks passed**, using isolated temporary data and a separate server port. Includes startup, 120 system facts/20 types, example task groups, exact time fit, completion/reopening, validation failures, foreign-origin rejection, malformed JSON, invalid query handling, deletion, static HTML serving, and persistence across a real process restart.
- In-app browser: added the document's three example tasks through the forms and verified Do First / Do Next / Do Later; added Monday Computer Networks 08:00–10:00; reloaded and verified records remained; completed/reopened reading; changed available time to 15 minutes and verified tasks remained visible with “Needs more time.”
- Browser error/warning log: no entries during the checked workflow.
- Desktop layout inspected. At the 390 × 844 mobile viewport, measured document content width equaled client width (375 CSS pixels after the scrollbar); no horizontal overflow. Temporary viewport override reset afterward.
- `example-desktop.png` and `example-mobile.png` show the temporary records from the supplied specification. These are verification examples, not seeded user data. They were removed after verification.

The original command-line sources were retained. The web app intentionally stores classes without allocating tasks into calendar slots, following the document's first-version scope.
