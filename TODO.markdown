## TODO

* `loadall` - This is a wonky option, since what happens if multiple files have
  different extensions that are handled by different programs. Running them in
  serial would be ineffective. It might not even be necessary to implement at
  all.
* Fuzzy searching - Search for a file based on a fuzzy match of full path, and
  partial parts of file name. For example, `fed dbt.e` should be able to find
  `src/db/tournament.erl`.
