# TODO

* Unify menu and gophermap?
* Try using coroutines for server to serve multiple connections - benchmark - also maybe only resort to if load high
* Be able to rate limit ip addresses and display their details on a page
  so that people can check
* Be able to use ip addresses as primitive access control
* Record the number of connections using [dict size sendMsgs]
* Have an option to run a security audit
  - Which could include whether there are user definable functions being called
  - Whether directories within /home are mounted
  - Whether tcl gopher server is within mounted directories and has safe permissions
  - Whether the executable is world readable
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
* Reduce complication of router to simple mount points to a proc which takes
  care of the test
* Make all sub namespaces Capitalized
