# CHANGELOG

## v0.3.1

* When the `-screen_prompt` menu is used from within GNU screen, it'll now
  scale and resize the prompt window based on the size of the return, if there
  are multiple matching files and fed is configured to `ask` in that situation.

## v0.3.0

* Added GNU Screen awareness. If running from within GNU Screen, fed will
  auto-rename the window to the name of the opened file, and if the file is
  already open in an existing GNU Screen window, will switch screen to that
  window.
* Added a new `-screen_prompt` option that's designed to be connected to a
  GNU Screen hotkey. For Example: `bind "^e" eval "screen fed --screen_prompt"`.
  With that config in your `.screenrc`, when you press `C-a C-e`, fed will open
  a small region at the bottom of your terminal to prompt for a filename.
  This will auto-close once fed is finished.

## v0.2.0

* Add `FORCE_EDITOR` env variable
* Add a `-prompt` switch that will then prompt the user to provide a pattern
  for finding and opening.
* Add support for `--` style switches in addition to `-` switches

## v0.1.1

* Remove smartmatching operator, which is experimental and generating warnings
  on Perl 5.18+.
* Fix error on Perl 5.20 for ambiguous return value.

## v0.1.0

* First functional version that includes all initial design ideas.
* Default configuration, Project-specific file (.fed), and user-preference file
  (.fedconf in $HOME)
* Traversing back to the root of the project based on .fed or `alt_roots`
* Support for different editors for different extensions.
* Properly handle multiple matching files (`multiple_matches` in config) as
  well as no matching files (`no_exist` in config)
* Mark certain extensions and file patterns as files to ignore (`ignore` in
  config)
* Initialization of project with `fed -init`
* Global setting initilization with `fed -global`
* Substring partial searching (`fed el/panel.e` will find
  `elements/forms/element_panel.erl` but not
  `elements/forms/elements_pane_l.erl`).
* If substring partial searching fails to find anything, fuzzy searching takes
  over (e.g. `fed db/tmt.e` would find `src/db/db_tournament.erl`)


## Proof of Concept

* Implemented as a dumb shell script to test for a while if it "feels" like a
  good solution. After a few months, it feels good. Let's move forward.
