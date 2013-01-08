# fed - (F)inding (ED)itor

Quickly find and edit the files of a project with the editor of your choice.
This is optimized for developers for whom their IDE of choice is a terminal
screen in Linux and Unix.

[Homepage](http://sigma-star.com/page/fed)

## Installation

In the `fed` directory, type `make install`. This will copy the `fed` script to
`/usr/bin/fed`.

## Initialization

In the root of the project you wish to enable for usage with `fed`, you simply
type  `fed -init`.

```
$ fed -init

Enter the command of your editor of choice [default: vim]:
Enter any file extensions for this project you wish to ignore [default: none]
How to handle multiple matching filenames (fail|ask|loadall) [default: fail]
How to handle files that don't exist (fail|ask|create) [default: create]
```

This will create a .fed file in the current directory, which will serve as the
root of the project. This file contains the configuration information for `fed`.

## Usage

To use `fed`, anywhere in the root of the project, type `fed filename` where
filename is the name of a file you wish to enter. `fed` will then search the
entire project directory structure, and load the configured editor with the
found file.

Note, that `filename` can be a partial filename.

For example, if the file you wish to edit is called `db\_tournament.erl`, you
could probably get away with typing `fed db\_tourn`.

In the event of more than one file is found with that matching name, then
depending on your configuration above, `fed` will either:

  * `fail`: fail by letting you know which files conflict
  * `ask`: ask you which file you wish to load
  * `loadall`: load all files in the editor

## Files that don't exist, and file creation

If `fed` is provided with a file that does not exist it uses the setting above:

  * `fail`: fail and inform the user that the file was not found
  * `ask`: inform the user the file does not exist, and asks which filename to
	create
  * `create`: will automatically create a file with the provided name,

## Assumptions

`fed` will make the assumption that the editor of choice will end the command
with a single filename or a list of filenames. For example, let's say your
project contains 3 files: `file1.txt`, `file2.txt`, and `file3.txt`.

If your editor of choice is `vim`, and you've configured `fed` to load all
files (`loadall` during configuration) then typing `fed file` will be the same
as typing: `vim file1.txt file2.txt file3.txt`

## Additional Switches

You can provide additional switches to your editor by putting them before the
filenames.

As `fed` does not currently have any switches of its own except for `-init`, it
will simply pass all provided switches to the editor.

## FAQ

### Why not just use the $EDITOR environment variable?

It's perfectly common to use a different editor for different projects and
languages. Therefore, you can configure, for example, Erlang and Lisp projects
to use `emacs` while you'd prefer to use `vim` for PHP, Python.

### What if I want to provide switches to my default editor

In the "Editor of choice", you can enter switches with the command. For
example, you could choose to enable "lisp mode" in vim by making the default
editor `vim -l`.

Then any `fed` commands would be translated to `vim -l filename`

## TODO

See [TODO.markdown](http://github.com/choptastic/fed/TODO.markdown)

## Changelog

See [CHANGELOG.markdown](http://github.com/choptastic/fed/CHANGELOG.markdown)

## License

`fed` is licensed under the
[MIT License](http://github.com/choptastic/fed/MIT-LICENSE.txt)

## Copyright

`fed` is copyright 2013 (c) Sigma Star Systems, LLC
