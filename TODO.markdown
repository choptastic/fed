## TODO

* `fed -init` option needs to work
* `fed -global` option (which works like `-init` except acts on `~/.fedconf`)
* `loadall` - This is a wonky option, since what happens if multiple files have
  different extensions that are handled by different programs. Running them in
  serial would be ineffective. It might not even be necessary to implement at
  all.
