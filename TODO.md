# TODO

* Create a better name for the project

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
* Warn if selector string is > 255 characters
* Finalize name used for gophermap files in directories - perhaps use menu in name
* Use exit [runAllTests] ??
* Support a search engine
* Don't serve the gophermap
* Support getting files using gopher
* Add an option to gophermap, not to cache
* Test that a delay in sending the selector after connect doesn't stop other connections
* Replace error statements as necessary
