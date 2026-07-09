# Whirly Wordlist Modernization Design

**Date:** 2026-06-14  
**Status:** Approved

---

## Context

Whirly Wordlist is a simple Rails word-solver app with no database. Users enter 6 letters and the app returns all 3–6 letter words formable from those letters, sourced from a flat text file. The primary interface is mobile. There are two views: an entry form (`solver#index`) and a results list (`solver#letters`).

Current state:
- Ruby 3.3.5 (via `.ruby-version`, rvm-era setup)
- Rails 8.1.1 with Sprockets asset pipeline
- No CSS framework — minimal monospace font styles only
- 109k-word SIL word list
- Heroku deployment broken: precompiled `public/assets/` committed to git as a workaround (commit 42704e6)
- Task tracking: none

---

## Goals

1. Upgrade Ruby to 4.0.5 and migrate version management to `mise.toml`
2. Bump Rails to 8.1.3 (current patch) and update all gem dependencies
3. Add tests for `WordList` (core solver logic) and `SolverController` (request/response)
4. Add Tailwind CSS via `tailwindcss-rails` (no Node build step, no importmap changes)
5. Redesign both views as mobile-first, with auto-advancing letter input UX
6. Fix the Heroku asset pipeline so precompiled assets are no longer committed to git
7. Use Beads (`bd`) for all task tracking throughout implementation
8. Document the path to upgrade the word list to a Scrabble-compatible dictionary

---

## Architecture

No structural changes to the Rails app. Single controller (`SolverController`), no database, no authentication. Changes are confined to:

- **Config**: `mise.toml`, `Gemfile`, `Gemfile.lock`, `.gitignore`
- **Tests**: `test/models/word_list_test.rb`, `test/controllers/solver_controller_test.rb`
- **Assets**: Tailwind config, application stylesheet, new Stimulus controller
- **Views**: `layouts/application.html.erb`, `solver/index.html.erb`, `solver/letters.html.erb`
- **Deployment**: `Procfile`, removal of committed `public/assets/`

---

## Section 1 — Infrastructure

### Ruby

- Drop `.ruby-version` and `.ruby-gemset` (rvm artifacts)
- Add `mise.toml` with `ruby = "4.0.5"` and `node = "24.16.0"`
- Update Gemfile: `ruby "~> 4.0"` — Heroku reads version from Gemfile only; `mise.toml` is for local dev
- Run `bundle update --ruby` to lock `Gemfile.lock` to Ruby 4.0

### Gems

- Bump `gem "rails", "~> 8.0"` — `bundle update rails` will pull 8.1.3
- Add `gem "tailwindcss-rails"` to base group
- Remove `gem "webdrivers"` from test group (Selenium 4.x manages drivers itself)
- Run `bundle update` for remaining patch-level bumps
- Remove `gem "importmap-rails"` only if confirmed unused (it ships with the Rails template but this app has no JS imports beyond Stimulus)

### Heroku

- Add `public/assets` to `.gitignore`
- Remove committed assets from git tracking: `git rm -r --cached public/assets`
- Add `Procfile`: `web: bundle exec puma -C config/puma.rb`
- Heroku's Ruby buildpack auto-runs `rake assets:precompile` during slug compile — this replaces the manual precompile workaround
- Document `RAILS_MASTER_KEY` must be set as a Heroku config var

---

## Section 2 — Tests

No tests currently exist. Adding two files using Rails built-in Minitest.

### `test/models/word_list_test.rb`

Tests for `WordList#check_letters` — the entire solver logic:

- Returns only words constructable from the given letters
- Respects letter counts (cannot use a letter more times than it appears in the input)
- Enforces minimum word length of 3
- Enforces maximum word length equal to the number of letters given (6)
- Results sorted by length ascending, then alphabetically within each length
- Returns empty array when no words match

Use a small inline word list in tests (stub `read_list` or pass a fixture) rather than loading the full 109k-word file — keeps tests fast and independent of the word list file.

### `test/controllers/solver_controller_test.rb`

- `GET /` → 200
- `POST /solver/letters` with all 6 letters present → 200, `@words` assigned
- `POST /solver/letters` with any blank letter → redirects to root

Tests are written **before** other implementation tasks. The `WordList` tests establish baseline behavior so any regression from the Ruby 4.0 upgrade or word list swap is caught immediately.

---

## Section 3 — Tailwind CSS Setup

Use `tailwindcss-rails` gem, which bundles the Tailwind CSS CLI binary — no Node build step, no webpack, no importmap changes required.

After `bin/rails tailwindcss:install`:
- `config/tailwind.config.js` generated — configure `content` paths to scan `app/views/**/*.html.erb`
- `app/assets/stylesheets/application.tailwind.css` — Tailwind entry point with `@tailwind base/components/utilities`
- `app/assets/stylesheets/application.css` — Sprockets manifest updated to `require application.tailwind`
- `Procfile.dev` updated for local dev (`foreman` runs puma + tailwind watch)

Keep the monospace font (`monaco, Consolas, 'Lucida Console', monospace`) as the base font — extend in `tailwind.config.js`.

---

## Section 4 — Frontend Redesign

### Layout (`layouts/application.html.erb`)

Mobile-first shell:
- `<html lang="en" class="h-full">`
- `<body class="h-full bg-white">` (or a subtle gray `bg-gray-50`)
- Centered container: `max-w-lg mx-auto px-4 py-8`
- Tailwind stylesheet tag replaces current `stylesheet_link_tag "application"`

### Index view — Letter Entry (`solver/index.html.erb`)

Replace the unstyled form with:
- App title: `<h1>` styled large, bold, monospace
- 6 large square letter inputs in a flex row:
  - Each: `w-12 h-12` (48×48px minimum touch target), `text-center text-2xl uppercase border-2 rounded`, `maxlength=1`, `inputmode="text"`
  - Wired to Stimulus `letter-input` controller for auto-advance
- "Solve" submit button below: full-width on mobile, styled prominently
- Auto-submit on 6th letter filled (configurable via Stimulus controller)

### Stimulus Controller (`app/javascript/controllers/letter_input_controller.js`)

Rails 8.1 ships Stimulus via importmap. New controller:
- `input` event: if value is non-empty, focus next input; if 6th input filled, submit form
- `keydown` event: on Backspace with empty value, focus previous input
- `paste` event: distribute pasted text across inputs left-to-right

Wire up with `data-controller="letter-input"` on the form element.

### Results view — Word List (`solver/letters.html.erb`)

Replace the unstyled `<ul>` with:
- Group `@words` by length (Ruby `.group_by(&:length)`)
- Render each group as a labeled section: "3-letter words (12)", "4-letter words (8)", etc.
- Words in each section as a responsive flex-wrap grid of pill-style badges
- Total word count shown at top
- "Try again" link styled as a secondary button, back to root

---

## Section 5 — Word List

The current SIL list (`lib/wordsEn.txt`, 109k words) is functional but not game-curated. Barrett wants to move to a Scrabble-compatible list (TWL or Collins/SOWPODS).

These lists are copyrighted (Hasbro/Mattel/Collins) and cannot be bundled in the repo. The `WordList` class requires no changes — it already reads one word per line from `lib/wordsEn.txt`. To swap:

1. Download a Scrabble word list (TWL06, SOWPODS, or Collins CSW) from a community source
2. Place it at `lib/wordsEn.txt` (replacing existing file)
3. No code changes needed

README will be updated with this guidance.

---

## Task Tracking

All implementation tasks are tracked in Beads (`bd`). Run `bd ready` to see what's unblocked. Dependency order:

```
Ruby 4.0.5 + mise.toml (18u)
  └── bundle update (2ag)
        ├── Tests: WordList + SolverController (6x0)
        │     └── Fix Heroku asset pipeline (j0l)
        └── tailwindcss-rails install (66e)
              └── Redesign layout (5ys)
                    ├── Redesign index view (86k)
                    │     └── Stimulus controller (df7)
                    └── Redesign results view (960)

[independent] Document word list upgrade (qhy)
```

---

## Out of Scope

- No database, no authentication, no background jobs — no changes to these
- No dark mode (can be added later with Tailwind's `dark:` variant)
- No system/browser tests (Stimulus auto-advance is simple enough to skip browser automation)
- No CI pipeline changes
