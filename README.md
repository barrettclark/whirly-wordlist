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

The credentials file was regenerated locally. Update the Heroku config var before deploying:

```bash
heroku config:set RAILS_MASTER_KEY=$(cat config/master.key)
git push heroku main
```

Heroku's Ruby buildpack compiles Tailwind CSS automatically during the build (`rake assets:precompile`). No manual precompilation needed.
