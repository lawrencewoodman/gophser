# TODO

* Create a better name for the project

* Allow caching option for mount and cache refresh frequency
* Try using coroutines for server to serve multiple connections - benchmark - also maybe only resort to if load high
* Be able to rate limit ip addresses and display their details on a page
  so that people can check
* Record the number of connections using [dict size sendMsgs]
* Turn into a module
* Have an option to run a security audit
  - Which could include whether their are user definable functions being called
  - Whether directories within /home are mounted
  - Whether tcl gopher server is within mounted directories and has safe permissions
* Warn if userName in menu items is > 70 character or contains non-printable characters
