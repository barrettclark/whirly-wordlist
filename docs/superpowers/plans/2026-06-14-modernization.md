# Whirly Wordlist Modernization Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Upgrade Ruby to 4.0.5 with mise, add Tailwind CSS mobile-first redesign, fix the Heroku asset pipeline, add test coverage, and document the Scrabble word list upgrade path.

**Architecture:** Single-controller Rails 8.1 app with no database. Changes confined to config, gems, tests, assets, and views. Stimulus handles auto-advance JS via importmap (no Node build step). Tailwind CSS compiled by the bundled `tailwindcss-rails` binary during Heroku build.

**Tech Stack:** Ruby 4.0.5, Rails 8.1.3, Tailwind CSS via `tailwindcss-rails`, Stimulus via `importmap-rails`, Minitest, Heroku Ruby buildpack, mise for local version management.

**Beads task IDs:** whirly-wordlist-18u → 2ag → [6x0 ∥ 66e] → [j0l ∥ 5ys → 86k → df7 ∥ 960] → qhy

---

## File Map

| Action | File | Purpose |
|--------|------|---------|
| Create | `mise.toml` | Local Ruby + Node version pinning |
| Delete | `.ruby-version` | rvm/rbenv artifact, replaced by mise.toml |
| Delete | `.ruby-gemset` | rvm artifact |
| Modify | `Gemfile` | Ruby version, add tailwindcss-rails, remove webdrivers |
| Modify | `Gemfile.lock` | Updated by bundle commands |
| Modify | `.gitignore` | Add `/public/assets` |
| Create | `Procfile` | Heroku web process |
| Create | `test/models/word_list_test.rb` | WordList solver logic tests |
| Create | `test/controllers/solver_controller_test.rb` | HTTP request/response tests |
| Modify | `app/controllers/solver_controller.rb` | Fix nil-param crash on missing letters |
| Create | `config/importmap.rb` | Pin Stimulus for importmap |
| Create | `app/javascript/application.js` | Stimulus app entry point |
| Create | `app/javascript/controllers/letter_input_controller.js` | Auto-advance between letter inputs |
| Generate | `config/tailwind.config.js` | Via `tailwindcss:install`, then customized |
| Generate | `app/assets/stylesheets/application.tailwind.css` | Via `tailwindcss:install` |
| Modify | `app/assets/stylesheets/application.css` | Remove solver.css inline styles |
| Modify | `app/views/layouts/application.html.erb` | Tailwind layout + importmap tags |
| Modify | `app/views/solver/index.html.erb` | Mobile-first letter entry form |
| Modify | `app/views/solver/letters.html.erb` | Results grouped by word length |
| Modify | `README.md` | Word list upgrade instructions |
| Remove (git) | `public/assets/` | Stop tracking precompiled assets |

---

## Task 1: Upgrade Ruby to 4.0.5 and add mise.toml

**Beads:** `bd update whirly-wordlist-18u --claim`

**Files:**
- Create: `mise.toml`
- Delete: `.ruby-version`
- Delete: `.ruby-gemset`
- Modify: `Gemfile`

- [ ] **Step 1: Create mise.toml**

```toml
[tools]
ruby = "4.0.5"
node = "24.16.0"
```

Save to project root as `mise.toml`.

- [ ] **Step 2: Delete rvm artifacts**

```bash
rm .ruby-version .ruby-gemset
```

- [ ] **Step 3: Update Gemfile ruby directive**

In `Gemfile`, replace:
```ruby
ruby ">= 3.2.0"
```
With:
```ruby
ruby "~> 4.0"
```

- [ ] **Step 4: Install gems under Ruby 4.0.5**

```bash
mise exec -- bundle install
```

Expected: Bundler installs successfully, no errors about Ruby version incompatibility. If Rails raises a Ruby version requirement error, check `bundle exec rails --version` — Rails 8.1 targets Ruby 3.x; a patch may be needed.

- [ ] **Step 5: Verify Rails boots**

```bash
mise exec -- bundle exec rails runner "puts Rails.version"
```

Expected output: `8.1.x`

- [ ] **Step 6: Update Gemfile.lock Ruby version**

```bash
mise exec -- bundle update --ruby
```

Expected: `RUBY VERSION` section in Gemfile.lock updates to `ruby 4.0.5`.

- [ ] **Step 7: Commit**

```bash
git add mise.toml Gemfile Gemfile.lock
git rm .ruby-version .ruby-gemset
git commit -m "chore: upgrade Ruby to 4.0.5, add mise.toml, drop rvm files"
```

- [ ] **Step 8: Close beads task**

```bash
bd close whirly-wordlist-18u
```

---

## Task 2: Update gem dependencies

**Beads:** `bd update whirly-wordlist-2ag --claim`

**Files:**
- Modify: `Gemfile`
- Modify: `Gemfile.lock`

- [ ] **Step 1: Remove webdrivers gem from Gemfile**

In `Gemfile`, delete this line from the test group:
```ruby
gem "webdrivers"
```

Selenium 4.x manages browser drivers automatically — webdrivers is deprecated and causes warnings.

- [ ] **Step 2: Add tailwindcss-rails to Gemfile**

In `Gemfile`, add to the main (ungrouped) gems section, after `gem "bootsnap"`:
```ruby
gem "tailwindcss-rails"
```

- [ ] **Step 3: Run bundle update**

```bash
mise exec -- bundle update
```

Expected: Rails bumps to 8.1.3, all gems update to latest compatible patch. No errors.

- [ ] **Step 4: Verify test suite still loads**

```bash
mise exec -- bundle exec rails test --dry-run 2>&1 | head -5
```

Expected: No load errors (there are no test files yet, so 0 tests run is fine).

- [ ] **Step 5: Commit**

```bash
git add Gemfile Gemfile.lock
git commit -m "chore: update gems, add tailwindcss-rails, remove webdrivers"
```

- [ ] **Step 6: Close beads task**

```bash
bd close whirly-wordlist-2ag
```

---

## Task 3: Add WordList and SolverController tests

**Beads:** `bd update whirly-wordlist-6x0 --claim`

**Files:**
- Create: `test/models/word_list_test.rb`
- Create: `test/controllers/solver_controller_test.rb`
- Modify: `app/controllers/solver_controller.rb` (fix nil-param crash revealed by tests)

- [ ] **Step 1: Create test/models/word_list_test.rb**

```ruby
require "test_helper"

# Avoids loading the 109k-word production file during tests
class TestWordList < WordList
  TEST_WORDS = %w[a ab act acts arc arcs car care card cat cats scat catch].freeze

  private

  def read_list
    @words = TEST_WORDS.dup
  end
end

class WordListTest < ActiveSupport::TestCase
  setup do
    @wl = TestWordList.new
  end

  test "returns only words constructable from given letters" do
    results = @wl.check_letters("c", "a", "t", "x", "y", "z")
    assert_includes results, "cat"
    refute_includes results, "car"   # 'r' not available
    refute_includes results, "care"  # 'r' and 'e' not available
  end

  test "respects letter counts - cannot use a letter more times than supplied" do
    # 's' appears once, so 'cats' needs exactly one 's' - ok
    # but give no 's': cats should not appear
    results = @wl.check_letters("c", "a", "t", "x", "y", "z")
    refute_includes results, "cats"
  end

  test "when a letter appears in input, words using it once are allowed" do
    results = @wl.check_letters("c", "a", "t", "s", "x", "y")
    assert_includes results, "cat"
    assert_includes results, "cats"
    assert_includes results, "acts"
  end

  test "enforces minimum word length of 3" do
    results = @wl.check_letters("a", "b", "c", "x", "y", "z")
    refute_includes results, "a"
    refute_includes results, "ab"
  end

  test "enforces maximum word length of 6 (number of letters given)" do
    results = @wl.check_letters("c", "a", "t", "c", "h", "s")
    assert results.all? { |w| w.length <= 6 },
      "Expected all words to be 6 letters or fewer, got: #{results.select { |w| w.length > 6 }}"
  end

  test "results sorted by length ascending then alphabetically within length" do
    results = @wl.check_letters("c", "a", "r", "t", "s", "e")
    lengths = results.map(&:length)
    assert_equal lengths.sort, lengths, "Expected results sorted by length"

    by_length = results.group_by(&:length)
    by_length.each do |_len, words|
      assert_equal words.sort, words, "Expected words of same length to be sorted alphabetically"
    end
  end

  test "returns empty array when no words match" do
    results = @wl.check_letters("q", "q", "q", "q", "q", "q")
    assert_equal [], results
  end
end
```

- [ ] **Step 2: Run WordList tests — expect them to pass (baseline check)**

```bash
mise exec -- bundle exec rails test test/models/word_list_test.rb -v
```

Expected: All 7 tests pass. These characterize existing behavior before any further changes.

- [ ] **Step 3: Create test/controllers/solver_controller_test.rb**

```ruby
require "test_helper"

class SolverControllerTest < ActionDispatch::IntegrationTest
  test "GET / returns 200" do
    get root_url
    assert_response :success
  end

  test "POST /solver/letters with all 6 letters returns 200 and renders words" do
    post solver_letters_url, params: {
      letter1: "c", letter2: "a", letter3: "t",
      letter4: "s", letter5: "e", letter6: "r"
    }
    assert_response :success
    assert_select "li", minimum: 1
  end

  test "POST /solver/letters with a blank letter redirects to root" do
    post solver_letters_url, params: {
      letter1: "c", letter2: "", letter3: "t",
      letter4: "s", letter5: "e", letter6: "r"
    }
    assert_redirected_to root_url
  end

  test "POST /solver/letters with a missing letter param redirects to root" do
    post solver_letters_url, params: {
      letter1: "c", letter2: "a", letter3: "t",
      letter4: "s", letter5: "e"
      # letter6 intentionally omitted
    }
    assert_redirected_to root_url
  end
end
```

- [ ] **Step 4: Run controller tests — expect the missing-param test to FAIL**

```bash
mise exec -- bundle exec rails test test/controllers/solver_controller_test.rb -v
```

Expected: 3 tests pass, 1 fails — the missing `letter6` param test raises `NoMethodError: undefined method 'downcase' for nil` because `params[:letter6]` is `nil` and the controller calls `.downcase` on it before checking emptiness.

- [ ] **Step 5: Fix the nil-param crash in solver_controller.rb**

In `app/controllers/solver_controller.rb`, replace:
```ruby
def letters
  letter1 = params[:letter1].downcase
  letter2 = params[:letter2].downcase
  letter3 = params[:letter3].downcase
  letter4 = params[:letter4].downcase
  letter5 = params[:letter5].downcase
  letter6 = params[:letter6].downcase
```
With:
```ruby
def letters
  letter1 = params[:letter1].to_s.downcase
  letter2 = params[:letter2].to_s.downcase
  letter3 = params[:letter3].to_s.downcase
  letter4 = params[:letter4].to_s.downcase
  letter5 = params[:letter5].to_s.downcase
  letter6 = params[:letter6].to_s.downcase
```

`nil.to_s` returns `""`, so a missing param becomes an empty string, which the existing `empty?` check already handles correctly.

- [ ] **Step 6: Run all tests — expect all to pass**

```bash
mise exec -- bundle exec rails test -v
```

Expected: 11 tests, 0 failures, 0 errors.

- [ ] **Step 7: Commit**

```bash
git add test/models/word_list_test.rb \
        test/controllers/solver_controller_test.rb \
        app/controllers/solver_controller.rb
git commit -m "test: add WordList and SolverController tests; fix nil param crash"
```

- [ ] **Step 8: Close beads task**

```bash
bd close whirly-wordlist-6x0
```

---

## Task 4: Install Tailwind CSS

**Beads:** `bd update whirly-wordlist-66e --claim`

**Files:**
- Generate: `config/tailwind.config.js`
- Generate: `app/assets/stylesheets/application.tailwind.css`
- Modify: `app/assets/stylesheets/application.css`
- Modify: `Procfile.dev` (generated or updated)

- [ ] **Step 1: Run the Tailwind installer**

```bash
mise exec -- bundle exec rails tailwindcss:install
```

Expected output includes lines like:
```
      create  config/tailwind.config.js
      create  app/assets/stylesheets/application.tailwind.css
      append  app/assets/stylesheets/application.css
```

- [ ] **Step 2: Verify generated tailwind.config.js content paths**

Open `config/tailwind.config.js`. The `content` array must include ERB views. It should look like:

```js
module.exports = {
  content: [
    './app/views/**/*.html.erb',
    './app/helpers/**/*.rb',
    './app/javascript/**/*.js',
  ],
  theme: {
    extend: {
      fontFamily: {
        mono: ['monaco', 'Consolas', "'Lucida Console'", 'monospace'],
      },
    },
  },
  plugins: [],
}
```

If `content` paths are missing or wrong, update them to match the above. Add the `fontFamily.mono` extension under `theme.extend` to preserve the monospace aesthetic.

- [ ] **Step 3: Update application.css to use Tailwind output**

Open `app/assets/stylesheets/application.css`. The installer appends a `require` line. Verify it now looks like:

```css
/*
 * This is a manifest file...
 *= require_tree .
 *= require_self
 */
```

Remove all inline styles from `application.css` — the monospace font rule was the only one, and it will be handled by Tailwind's `font-mono` class and the config extension above. The file should contain only the manifest comment block after cleanup.

- [ ] **Step 4: Remove solver.css (styles now in Tailwind)**

```bash
rm app/assets/stylesheets/solver.css
```

- [ ] **Step 5: Do a local Tailwind build to verify CSS compiles**

```bash
mise exec -- bundle exec rails tailwindcss:build
```

Expected: No errors. A compiled CSS file appears in `app/assets/builds/tailwind.css` (or similar path determined by the installer).

- [ ] **Step 6: Run tests to confirm nothing broke**

```bash
mise exec -- bundle exec rails test -v
```

Expected: 11 tests, 0 failures.

- [ ] **Step 7: Commit**

```bash
git add config/tailwind.config.js \
        app/assets/stylesheets/application.tailwind.css \
        app/assets/stylesheets/application.css \
        Procfile.dev
git rm app/assets/stylesheets/solver.css
git commit -m "feat: install tailwindcss-rails with monospace font extension"
```

- [ ] **Step 8: Close beads task**

```bash
bd close whirly-wordlist-66e
```

---

## Task 5: Fix Heroku asset pipeline

**Beads:** `bd update whirly-wordlist-j0l --claim`

**Files:**
- Modify: `.gitignore`
- Remove from git: `public/assets/`
- Create: `Procfile`

- [ ] **Step 1: Add public/assets to .gitignore**

Open `.gitignore` and add this line:
```
/public/assets
```

- [ ] **Step 2: Remove committed precompiled assets from git tracking**

```bash
git rm -r --cached public/assets
```

Expected output: many `rm 'public/assets/...'` lines. This removes files from git's index without deleting them from disk. After the next `git commit`, they will no longer be tracked.

- [ ] **Step 3: Create Procfile**

Create `Procfile` in the project root:
```
web: bundle exec puma -C config/puma.rb
```

This tells Heroku how to start the web process. The Ruby buildpack auto-runs `rake assets:precompile` before starting — this compiles Tailwind CSS during the Heroku slug build, replacing the previous manual-precompile workaround.

- [ ] **Step 4: Verify RAILS_MASTER_KEY is documented**

Open `config/credentials.yml.enc`. You don't need to decrypt it — just confirm `config/master.key` exists locally (it does, it's in `.gitignore`). On Heroku, set the key as a config var:

```
heroku config:set RAILS_MASTER_KEY=$(cat config/master.key)
```

Add a note about this to `README.md`:
```markdown
## Heroku deployment

Set the master key as a config var before deploying:
```bash
heroku config:set RAILS_MASTER_KEY=$(cat config/master.key)
```
```

- [ ] **Step 5: Commit**

```bash
git add .gitignore Procfile README.md
git commit -m "fix: remove committed public/assets, add Procfile, fix Heroku asset pipeline"
```

- [ ] **Step 6: Verify public/assets is now untracked**

```bash
git status public/assets
```

Expected: `public/assets` is not mentioned (untracked and gitignored).

- [ ] **Step 7: Close beads task**

```bash
bd close whirly-wordlist-j0l
```

---

## Task 6: Redesign application layout

**Beads:** `bd update whirly-wordlist-5ys --claim`

**Files:**
- Modify: `app/views/layouts/application.html.erb`
- Create: `config/importmap.rb`
- Create: `app/javascript/application.js`

- [ ] **Step 1: Create config/importmap.rb**

```ruby
pin "application"
pin "@hotwired/stimulus", to: "https://cdn.jsdelivr.net/npm/@hotwired/stimulus@3.2.2/dist/stimulus.js"
pin "controllers/letter_input_controller", to: "controllers/letter_input_controller.js"
```

- [ ] **Step 2: Create app/javascript/application.js**

```bash
mkdir -p app/javascript/controllers
```

```javascript
import { Application } from "@hotwired/stimulus"
import LetterInputController from "controllers/letter_input_controller"

const application = Application.start()
application.register("letter-input", LetterInputController)
```

Save to `app/javascript/application.js`.

- [ ] **Step 3: Rewrite app/views/layouts/application.html.erb**

```erb
<!DOCTYPE html>
<html lang="en" class="h-full">
  <head>
    <title>Whirly Word Solver</title>
    <meta name="viewport" content="width=device-width,initial-scale=1">
    <%= csrf_meta_tags %>
    <%= csp_meta_tag %>
    <%= stylesheet_link_tag "application", "data-turbo-track": "reload" %>
    <%= javascript_importmap_tags %>
  </head>

  <body class="h-full bg-gray-50 font-mono">
    <div class="min-h-full flex flex-col items-center justify-center px-4 py-12">
      <div class="w-full max-w-sm">
        <%= yield %>
      </div>
    </div>
  </body>
</html>
```

- [ ] **Step 4: Run tests to confirm layout change doesn't break requests**

```bash
mise exec -- bundle exec rails test test/controllers/solver_controller_test.rb -v
```

Expected: 4 tests pass.

- [ ] **Step 5: Commit**

```bash
git add app/views/layouts/application.html.erb \
        config/importmap.rb \
        app/javascript/application.js \
        app/javascript/
git commit -m "feat: Tailwind mobile-first layout with importmap/Stimulus wiring"
```

- [ ] **Step 6: Close beads task**

```bash
bd close whirly-wordlist-5ys
```

---

## Task 7: Redesign solver index view

**Beads:** `bd update whirly-wordlist-86k --claim`

**Files:**
- Modify: `app/views/solver/index.html.erb`

- [ ] **Step 1: Rewrite app/views/solver/index.html.erb**

```erb
<h1 class="text-3xl font-bold tracking-tight text-gray-900 text-center mb-2">
  Whirly Word
</h1>
<p class="text-sm text-gray-500 text-center mb-8">Enter your 6 letters</p>

<%= form_with url: solver_letters_path, method: :post,
      data: { controller: "letter-input" } do |f| %>

  <div class="flex justify-center gap-2 mb-8">
    <% (1..6).each do |i| %>
      <%= text_field_tag "letter#{i}", nil,
            maxlength: 1,
            inputmode: "text",
            autocomplete: "off",
            autocorrect: "off",
            autocapitalize: "characters",
            spellcheck: "false",
            data: { "letter-input-target": "input" },
            class: "w-12 h-12 text-center text-2xl font-bold uppercase border-2
                    border-gray-300 rounded-lg focus:border-indigo-500
                    focus:outline-none focus:ring-2 focus:ring-indigo-200
                    bg-white text-gray-900 caret-transparent" %>
    <% end %>
  </div>

  <%= f.submit "Solve",
        class: "w-full py-3 px-4 bg-indigo-600 hover:bg-indigo-700
                text-white font-semibold rounded-lg transition-colors
                focus:outline-none focus:ring-2 focus:ring-indigo-500 focus:ring-offset-2" %>
<% end %>
```

Note: `form_with` replaces the deprecated `form_tag`. `autocapitalize: "characters"` prompts mobile keyboards to type uppercase. `caret-transparent` hides the cursor in the small boxes.

- [ ] **Step 2: Run controller test to confirm form still submits**

```bash
mise exec -- bundle exec rails test test/controllers/solver_controller_test.rb -v
```

Expected: 4 tests pass.

- [ ] **Step 3: Commit**

```bash
git add app/views/solver/index.html.erb
git commit -m "feat: mobile-first letter entry form with Tailwind"
```

- [ ] **Step 4: Close beads task**

```bash
bd close whirly-wordlist-86k
```

---

## Task 8: Add Stimulus letter-input controller

**Beads:** `bd update whirly-wordlist-df7 --claim`

**Files:**
- Create: `app/javascript/controllers/letter_input_controller.js`

- [ ] **Step 1: Create app/javascript/controllers/letter_input_controller.js**

```javascript
import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["input"]

  connect() {
    // Focus the first empty input when the page loads
    const first = this.inputTargets.find(i => i.value === "")
    if (first) first.focus()
  }

  input(event) {
    const input = event.target
    // Enforce single letter and uppercase display
    input.value = input.value.replace(/[^a-zA-Z]/g, "").slice(-1).toUpperCase()

    if (input.value.length === 1) {
      const index = this.inputTargets.indexOf(input)
      if (index === this.inputTargets.length - 1) {
        // Last box filled — submit
        this.element.requestSubmit()
      } else {
        this.inputTargets[index + 1].focus()
      }
    }
  }

  keydown(event) {
    if (event.key === "Backspace" && event.target.value === "") {
      const index = this.inputTargets.indexOf(event.target)
      if (index > 0) {
        const prev = this.inputTargets[index - 1]
        prev.value = ""
        prev.focus()
      }
    }
  }

  paste(event) {
    event.preventDefault()
    const text = (event.clipboardData || window.clipboardData)
      .getData("text")
      .replace(/[^a-zA-Z]/g, "")
      .toUpperCase()
      .slice(0, this.inputTargets.length)

    text.split("").forEach((letter, i) => {
      this.inputTargets[i].value = letter
    })

    if (text.length === this.inputTargets.length) {
      this.element.requestSubmit()
    } else {
      const next = this.inputTargets[text.length]
      if (next) next.focus()
    }
  }
}
```

- [ ] **Step 2: Wire up event handlers in the index view**

The `data-action` attributes connect DOM events to the Stimulus controller. In `app/views/solver/index.html.erb`, update each letter input to add event actions:

Replace the `text_field_tag` call inside the loop:
```erb
<% (1..6).each do |i| %>
  <%= text_field_tag "letter#{i}", nil,
        maxlength: 1,
        inputmode: "text",
        autocomplete: "off",
        autocorrect: "off",
        autocapitalize: "characters",
        spellcheck: "false",
        data: {
          "letter-input-target": "input",
          action: "input->letter-input#input keydown->letter-input#keydown paste->letter-input#paste"
        },
        class: "w-12 h-12 text-center text-2xl font-bold uppercase border-2
                border-gray-300 rounded-lg focus:border-indigo-500
                focus:outline-none focus:ring-2 focus:ring-indigo-200
                bg-white text-gray-900 caret-transparent" %>
<% end %>
```

- [ ] **Step 3: Run tests**

```bash
mise exec -- bundle exec rails test -v
```

Expected: 11 tests, 0 failures.

- [ ] **Step 4: Commit**

```bash
git add app/javascript/controllers/letter_input_controller.js \
        app/views/solver/index.html.erb
git commit -m "feat: Stimulus letter-input controller with auto-advance and paste"
```

- [ ] **Step 5: Close beads task**

```bash
bd close whirly-wordlist-df7
```

---

## Task 9: Redesign letters results view

**Beads:** `bd update whirly-wordlist-960 --claim`

**Files:**
- Modify: `app/views/solver/letters.html.erb`
- Modify: `app/controllers/solver_controller.rb` (group words by length)

- [ ] **Step 1: Update SolverController to group words by length**

In `app/controllers/solver_controller.rb`, update the `letters` action to expose grouped words:

```ruby
def letters
  letter1 = params[:letter1].to_s.downcase
  letter2 = params[:letter2].to_s.downcase
  letter3 = params[:letter3].to_s.downcase
  letter4 = params[:letter4].to_s.downcase
  letter5 = params[:letter5].to_s.downcase
  letter6 = params[:letter6].to_s.downcase
  unless letter1.empty? || letter2.empty? || letter3.empty? || letter4.empty? || letter5.empty? || letter6.empty?
    wl = WordList.new
    words = wl.check_letters(letter1, letter2, letter3, letter4, letter5, letter6)
    @words = words
    @words_by_length = words.group_by(&:length)
    @total_count = words.length
  else
    redirect_to root_path
    return
  end
end
```

- [ ] **Step 2: Rewrite app/views/solver/letters.html.erb**

```erb
<div class="mb-6 text-center">
  <h1 class="text-2xl font-bold text-gray-900">Results</h1>
  <p class="text-sm text-gray-500 mt-1">
    <%= @total_count %> <%= "word".pluralize(@total_count) %> found
  </p>
</div>

<% if @words_by_length.present? %>
  <% @words_by_length.each do |length, words| %>
    <div class="mb-6">
      <h2 class="text-xs font-semibold uppercase tracking-wider text-gray-400 mb-2">
        <%= length %>-letter words (<%= words.length %>)
      </h2>
      <div class="flex flex-wrap gap-2">
        <% words.each do |word| %>
          <span class="inline-block px-3 py-1 bg-white border border-gray-200
                        rounded-full text-sm font-mono text-gray-800 shadow-sm">
            <%= word %>
          </span>
        <% end %>
      </div>
    </div>
  <% end %>
<% else %>
  <p class="text-center text-gray-500 py-8">No words found. Try different letters.</p>
<% end %>

<div class="mt-8 text-center">
  <%= link_to "Try again", root_path,
        class: "inline-flex items-center px-4 py-2 border border-gray-300
                rounded-lg text-sm font-medium text-gray-700 bg-white
                hover:bg-gray-50 transition-colors" %>
</div>
```

- [ ] **Step 3: Run tests**

```bash
mise exec -- bundle exec rails test -v
```

Expected: 11 tests, 0 failures. The `assert_select "li", minimum: 1` test will fail if words are no longer in `<li>` tags — update it to match the new markup:

In `test/controllers/solver_controller_test.rb`, update the assertion in `"returns 200 and renders words"`:
```ruby
assert_select "span.rounded-full", minimum: 1
```

Re-run until all 11 pass.

- [ ] **Step 4: Commit**

```bash
git add app/views/solver/letters.html.erb \
        app/controllers/solver_controller.rb \
        test/controllers/solver_controller_test.rb
git commit -m "feat: results view grouped by word length with Tailwind pill badges"
```

- [ ] **Step 5: Close beads task**

```bash
bd close whirly-wordlist-960
```

---

## Task 10: Document word list upgrade path

**Beads:** `bd update whirly-wordlist-qhy --claim`

**Files:**
- Modify: `README.md`

- [ ] **Step 1: Replace README.md contents**

```markdown
# Whirly Word Solver

A Rails app that finds all words (3–6 letters) formable from a set of 6 given letters. Useful for solving the Whirly Word puzzle.

## Local development

Requires [mise](https://mise.jdx.dev) for version management.

```bash
mise install          # installs Ruby 4.0.5 and Node 24.16.0
bundle install
bin/dev               # starts Puma + Tailwind CSS watcher
```

Open http://localhost:3000.

## Running tests

```bash
bundle exec rails test
```

## Upgrading the word list

The default word list (`lib/wordsEn.txt`) is the SIL English word list (~109k words). For a Scrabble-quality list:

1. Download one of:
   - **SOWPODS** (Collins international Scrabble): widely available in open-source Scrabble projects
   - **TWL06** (North American tournament Scrabble): available from the same sources
   - **Collins CSW** (latest Collins Scrabble Words)

2. Replace `lib/wordsEn.txt` with your chosen list (one word per line, no headers, lowercase).

3. No code changes required — `WordList` reads whatever is at that path.

Note: these lists are copyrighted (Hasbro/Mattel/Collins) and cannot be redistributed. Obtain them from a legal source.

## Heroku deployment

```bash
heroku config:set RAILS_MASTER_KEY=$(cat config/master.key)
git push heroku main
```

Heroku's Ruby buildpack compiles Tailwind CSS automatically during the build (`rake assets:precompile`). No manual precompilation needed.
```

- [ ] **Step 2: Commit**

```bash
git add README.md
git commit -m "docs: update README with mise setup, word list upgrade, Heroku deploy"
```

- [ ] **Step 3: Close beads task and close epic**

```bash
bd close whirly-wordlist-qhy
bd close whirly-wordlist-udn --reason="All subtasks complete"
```

- [ ] **Step 4: Final test run**

```bash
mise exec -- bundle exec rails test -v
```

Expected: 11 tests, 0 failures, 0 errors.

- [ ] **Step 5: Check beads stats**

```bash
bd stats
```

Expected: 0 open issues.

---

## Self-Review Notes

- **Spec coverage:** All 8 goals covered. Infrastructure (Tasks 1–2), Tests (Task 3), Tailwind (Task 4), Heroku fix (Task 5), Layout (Task 6), Index view (Task 7), Stimulus (Task 8), Results view (Task 9), Word list docs (Task 10).
- **Bug found and fixed:** `params[:letter].downcase` nil crash fixed in Task 3 and carried forward to Task 9's controller update. Task 3 is where it's first introduced via `.to_s` — Task 9's controller block shows the full final state.
- **Test selector updated:** Task 9 notes the `assert_select "li"` assertion must be updated to `"span.rounded-full"` after the view redesign — this prevents a hidden test regression.
- **importmap CDN pin:** Uses jsdelivr CDN for Stimulus. If offline or CDN-blocked builds are a concern, run `bin/importmap pin @hotwired/stimulus` instead to vendor it locally.
- **`form_tag` deprecation:** Task 7 uses `form_with` (Rails 5.1+ recommended) rather than the deprecated `form_tag`.
