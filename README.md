install-dreamhost
-----------------
install-dreamhost version 3.0

Installs updated versions of Python, Mercurial, Git in your home folder.

Useful for environments where you don't have sudo access (such as
on a shared server like Dreamhost)

It includes a number of dependencies 
(berkeley db, bzip, curl, openssl, readline, sqlite, tcl, tk)
and installs some additional programs
(django, pip, virtualenv, cgit, lesscss, inotify).

It has been tested on Dreamhost on a shared server running Debian.

It should work with other hosts, but it hasn't been tested.

## Usage:

    ./install-dreamhost.sh

### Installation Notes
Binaries installed into `~/local/bin`.  `~/local/bin` is added to your
bash `PATH`.
(You will need to add this to your
`PATH` if you are not using bash for your shell)

After installing, log out and log back in to setup your environment.
(You may also try running

    exec bash -login

instead of relogging)

To test if everything worked, make sure that

    which python

returns "~/local/bin/python" and verify the python version

    python --version

### Important Dreamhost setup info
Make sure you source ~/.bashrc in your ~/.bash_profile

    source ~/.bashrc

or else .bashrc will not be read when you log in, so your 
PATH may not be setup correctly for your newly installed tools.
Ref:  http://wiki.dreamhost.com/Environment_Setup

### Delete downloaded files
You may delete the downloads directory after installation is complete.

    rm -rf downloads

## Uninstallation

Run the uninstall script

    ./uninstall-dreamhost.sh

This will remove the `~/local` directory and attempt to revert
changes made by this script.

Note you can manually uninstall by deleting the `~/local` directory
and delete the entries in `~/.bashrc` and `~/.hgrc`.

Originally created by Tommaso Lanza, under the influence
of the guide published by Andrew Watts at:
http://andrew.io/weblog/2010/02/installing-python-2-6-virtualenv-and-VirtualEnvWrapper-on-dreamhost/

Also, thanks to Kelvin Wong's python installation guide at
http://www.kelvinwong.ca/2010/08/02/python-2-7-on-dreamhost/

Use this script at your own risk.

-----------------------------------------

###Changelog

April 26 2012 - Kristi Tsukida <kristi.dev@gmail.com>
* v3.0
* Add ruby and rvm

April 24 2012 - Kristi Tsukida <kristi.dev@gmail.com>
* Add verification tests
* Cleanup program output
* Rename script

April 17 2012 - Kristi Tsukida <kristi.dev@gmail.com>
* Update to latest versions
* Silence unnecessary output

Sep 4 2011 - Kristi Tsukida <kristi.dev@gmail.com>
* Add node.js, lesscss and inotify

Aug 1 2011 - Kristi Tsukida <kristi.dev@gmail.com>
* Updated version numbers and urls
* Use pip to install python packages
* Check for directories before creating them
* Pass --quiet flags and redirect to /dev/null to reduce output
* Add log files
* Download into the current directory
* Add uninstall
* Remove lesscss gem (repo old, and lesscss seems to be in js now)
* Don't install into a virtualenv
* /usr/local style install instead of /opt style install (I prefer the simplerPATH manipulations)
* Default the install into ~/local

TODO: add virtualenvwrapper?
TODO: auto-detect latest versions of stuff  (hard to do?)
TODO: add flag/option for /opt style install  (Put python, mercurial, and git into their own install directories)
TODO: more sophisticated argument parsing
