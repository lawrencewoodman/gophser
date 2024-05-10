# TODO

* Use gophermap files to serve gophermaps and use another file name to generate them
  or have an option within to dynamically generate
* Unify menu and gophermap?
* Finalize name used for gophermap files in directories - perhaps use menu in name
* Record the number of connections using [dict size sendMsgs]
* Warn if userName in menu items is > 70 character or contains non-printable characters
* Warn if selector string is > 255 characters
* Don't serve the gophermap
* Add an option to gophermap, not to cache
* Replace error statements as necessary
* Reduce complication of router to simple mount points to a proc which takes
  care of the test
* Make all sub namespaces Capitalized
* Should log warning take a selector and store it in a structured way


## Future Features
* Support getting files using gopher
* Try using coroutines for server to serve multiple connections - benchmark - also maybe only resort to if load high
  so that people can check
* Support a search engine
* Be able to rate limit ip addresses and display their details on a page
* Be able to use ip addresses as primitive access control
* Have an option to run a security audit
  - Which could include whether there are user definable functions being called
  - Whether directories within /home are mounted
  - Whether tcl gopher server is within mounted directories and has safe permissions
  - Whether the executable is world readable

## cache
* Consider having a limit of the number of items in the cache and when exceeded run Cleanup
  - Could also base this on size but that might be slower can cause shimmering problems


## Titles
* List different styles of titles such as
  === This is a Title ===
  --- This is a Smaller Title ---

  THIS IS ALSO A TITLE

  This is a Smaller Version of the Title


## Testing

* Use exit [runAllTests] ??
* Test that a delay in sending the selector after connect doesn't stop other connections

### Cache
* Test Cleanup is called within fetch
* Test Cleanp reduces memory as expected
