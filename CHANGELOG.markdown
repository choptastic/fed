# CHANGELOG

## v0.1.0 (in development)

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
* Fuzzy searching (e.g. `fed db/tmt.e` would find `src/db/db_tournament.erl`)

## Proof of Concept

* Implemented as a dumb shell script to test for a while if it "feels" like a
  good solution. After a few months, it feels good. Let's move forward.
