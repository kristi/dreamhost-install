#!/bin/bash
# for debugging, use -e to stop on error
#!/bin/bash #-e
# =================================================
# pyHost version 2.2 beta
# 
# This script automates a the download, compiling, and local 
# installation of Python, Mercurial, Git in the home folder.
# It includes a number of dependencies 
# (berkeley db, bzip, curl, openssl, readline, sqlite, tcl, tk)
# and installs some additional plugins 
# (django, pip, virtualenv).
# It has been tested on Dreamhost on a shared server running Debian.
# It should work with other hosts, but it hasn't been tested.
#
# Usage:
#
#   ./pyHost.sh
# 
# With default settings, this command will install 
# Python, Mercurial, and Git (with dependencies and specified plugins)
# into ~/local.  It will add ~/local/bin to your PATH
# in your ~/.bashrc file. (If you use a different shell, you
# will need to add ~/local/bin to your PATH in your shell's
# init script.)
#
# After installing, source .bashrc 
#     source ~/.bashrc
# OR simply log out and log back in.  Then test that
#     which python
# returns "~/local/bin/python" and verify the python version
#     python --version
#
# *** Important environment setup info ***
# Make sure you source ~/.bashrc in your ~/.bash_profile
#     source ~/.bashrc
# or else .bashrc will not be read when you log in, so your 
# PATH may not be setup correctly for your newly installed tools.
# http://wiki.dreamhost.com/Environment_Setup
#
# You may delete the downloads directory after installation is complete.
#     rm -r downloads
#
# Uninstallation:
#
# Pass the uninstall parameter
#
#     ./pyHost.sh uninstall
#
# OR run the uninstall script which the installation generated
#
#     ./uninstall_pyHost
#
# This will remove the ~/local directory and attempt to revert
# changes made by this script.
#
# Note you can manually uninstall by deleting the ~/local directory
# and delete the pyHost generated entries in ~/.bashrc and ~/.hgrc.
#
# Originally created by Tommaso Lanza, under the influence
# of the guide published by Andrew Watts at:
# http://andrew.io/weblog/2010/02/installing-python-2-6-virtualenv-and-VirtualEnvWrapper-on-dreamhost/
#
# Also, thanks to Kelvin Wong's python installation guide at
# http://www.kelvinwong.ca/2010/08/02/python-2-7-on-dreamhost/
# 
# Use this script at your own risk.
#
# =================================================
# 
# Changelog
# April 17 2012 - Kristi Tsukida <kristi.dev@gmail.com>
# * Update to latest versions
# * Silence unnecessary output
#
# Sep 4 2011 - Kristi Tsukida <kristi.dev@gmail.com>
# * Add node.js, lesscss and inotify
#
# Aug 1 2011 - Kristi Tsukida <kristi.dev@gmail.com>
# * Updated version numbers and urls
# * Use pip to install python packages
# * Check for directories before creating them
# * Pass --quiet flags and redirect to /dev/null to reduce output
# * Add log files
# * Download into the current directory
# * Add uninstall
# * Remove lesscss gem (repo old, and lesscss seems to be in js now)
# * Don't install into a virtualenv
# * /usr/local style install instead of /opt style install (I prefer the simplerPATH manipulations)
# * Default the install into ~/local
#
# TODO: add virtualenvwrapper?
# TODO: auto-detect latest versions of stuff  (hard to do?)
# TODO: add flag/option for /opt style install  (Put python, mercurial, and git into their own install directories)
# TODO: more sophisticated argument parsing
# 
# Ignore these errors:
# * Openssl
#     Use of uninitialized value $output in pattern match (m//) at asm/md5-x86_64.pl line 115
# * Readline 
#     (Makefile is trying to move existing libs, but there are no
#     existing files to move)
#     mv: cannot stat 'opt/local/lib/libreadline.a': No such file or directory
#     mv: cannot stat 'opt/local/lib/libhistory.a': No such file or directory
# * Berkeley DB
#     libtool.m4: error: problem compiling CXX test program
#
# May 2010 - tmslnz
# Original script ver 1.5
#
# =================================================
#

# Try to reduce console output
quiet=false

function ph_init_vars {
    # Current directory
    pH_PWD="$PWD"
    
    # Directory to install these packages
    pH_install="$HOME/local"
    
    # Directory to store the source archives
    pH_DL="$PWD/downloads"
    
    # Uninstall script
    pH_uninstall_script="$PWD/uninstall_pyHost"
    
    pH_log="log.txt"
    
    pH_script_url="https://github.com/kristi/dreamhost-install/blob/master/pyHost.sh"
    
    # Package versions
    #
    # Comment out anything you don't want to install...
    
    pH_Python="2.7.2"
    pH_pip="(via get-pip.py script)"
    pH_Mercurial="2.1.1" # Don't use pip to install Mercurial since it might not be updated
    pH_Git="1.7.10"
    pH_Cgit="0.9.0.3"
    pH_Django="(via pip)" # installed via pip
    pH_VirtualEnv="(via pip)" # installed via pip
    #pH_HgGit="(via pip)" # installed via pip
    pH_NodeJS="0.6.15"
    pH_LessCSS="(github)"
    pH_Inotify="3.14"
    # === Python dependencies ===
    pH_SSL="1.0.1" # for python
    pH_Readline="6.2" # for python
    pH_Tcl="8.5.11" # for python
    pH_Tk="8.5.11" # for python
    pH_Berkeley_47x="4.7.25" # for python 2.6
    pH_Berkeley_48x="4.8.30" # for python 2.7
    pH_Berkeley_50x="5.3.15" # for python 3
    pH_BZip="1.0.6" # for python
    pH_SQLite="3071100" # 3.7.11 for python
    # === Git dependencies ===
    pH_cURL="7.25.0" # for git
    # === Inotify dependencies ===
    pH_M4="1.4.16" # for inotify
    pH_Autoconf="2.68" # for inotify



    # Sets the correct version of Berkeley DB to use and download
    # by looking at the Python version number
    if [[ "${pH_Python:0:3}" == "2.6" ]]; then
        pH_Berkeley=$pH_Berkeley_47x
    elif [[ "${pH_Python:0:3}" == "2.7" ]]; then
        pH_Berkeley=$pH_Berkeley_48x
    elif [[ "${pH_Python:0:1}" == "3" ]]; then
        pH_Berkeley=$pH_Berkeley_50x
    fi

    # Quietly download files
    CURL="curl -O -s --show-error --fail --location --retry 1"

    # Use local versions
    PYTHON="$pH_install/bin/python"
    PIP="$pH_install/bin/pip"

    export PATH="$pH_install/bin:$PATH"
    export PKG_CONFIG_PATH="$pH_install/lib/pkgconfig:$PKG_CONFIG_PATH"
    export LD_LIBRARY_PATH="$pH_install/lib"
    export LD_RUN_PATH="$LD_LIBRARY_PATH"

    # Save stdout as fd #3
    exec 3>&1
    # Save stderr as fd #4
    exec 4>&2

    MAKE="make"
    QUIET=""
    if [[ "$quiet" == "true" ]] ; then
        # Reduce console output
        # redirect stdout and stderr to log file
        exec &>$pH_log 
        #exec 2>&1

        MAKE="make --silent"
        QUIET="--quiet"
    fi
}

function status {
    # Print to stdout and to log file

    echo "$@" >&3

    echo "====================================" >> $pH_log
    echo "$@" >> $pH_log
    echo "====================================" >> $pH_log
}

function err {
    # Print in red to stderr and exit

    echo -en '\e[1;31m' >&4
    echo -en "ERROR: $@" >&4
    echo -e '\e[0m' >&4

    exit
}

function ph_install_setup {
    # Let's see how long it takes to finish;
    start_time=$(date +%s)

    PH_OLD_PATH="$PATH"
    PH_OLD_PYTHONPATH="$PYTHONPATH"
    
    # Make a backup copy of the current $pH_install folder if it exists.
    if [[ -e "$pH_install" ]]; then
        #echo "Warning: existing '$pH_install' directory found."
        if [[ ! -e $pH_install.backup ]] ; then
            #read -p "Create a backup copy at $pH_install.backup and continue? [y,n] " choice 
            #case ${choice:0:1} in  
            #  y|Y) echo "    ok" ;;
            #  *) echo "Exiting"; rm $pH_uninstall_script; exit ;;
            #esac
            echo "    Creating a backup of '$pH_install' at '$pH_install.backup'"
            cp --archive "$pH_install" "$pH_install.backup"
        else
            echo "    Existing backup of '$pH_install' found at '$pH_install.backup'.  No new backup will be created."
            #read -p "Existing backup copy found at $pH_install.backup.  No new backup will be created.  Continue installing? [y,n] " choice 
            #case ${choice:0:1} in  
            #  y|Y) echo "    ok" ;;
            #  *) echo "Exiting"; exit ;;
            #esac
        fi
    fi
    mkdir --parents "$pH_install" "$pH_DL"
    mkdir --parents --mode=775 "$pH_install/lib"
    
    # Backup and modify .bashrc
    cd
    if [[ ! -e .bashrc.dreamhost-install.sh.backup ]] ; then
        cp .bashrc .bashrc.dreamhost-install.backup
        cat >> .bashrc <<DELIM

########   BEGIN DREAMHOST-INSTALL.SH SECTION   ########
# The following lines were added by the script dreamhost-install.sh from:
# $pH_script_url
# on $(date -u)

export PATH=$pH_install/bin:\$PATH

########   END DREAMHOST-INSTALL.SH SECTION   ########
DELIM
        
        # Create a patch so we can undo our changes if we uninstall
        # (Undo by doing "patch .bashrc < .bashrc.dreamhost-install.undo.patch" )
        diff -u .bashrc.dreamhost-install.backup .bashrc > .bashrc.dreamhost-install.undo.patch

    fi

    # TODO: Make sure .bashrc is called by .bash_profile

}


##############################
# Download Compile and Install
##############################

# OpenSSL
function ph_openssl {
    status "    Installing OpenSSL $pH_SSL..."
    cd "$pH_DL"
    if [[ ! -e "openssl-$pH_SSL" ]] ; then
        $CURL "http://www.openssl.org/source/openssl-$pH_SSL.tar.gz"
        rm -rf "openssl-$pH_SSL"
        tar -xzf "openssl-$pH_SSL.tar.gz"
        cd "openssl-$pH_SSL"
    else
        cd "openssl-$pH_SSL"
        $MAKE clean
    fi
    
    # Fix warning messages
    sed -i '/^AR=/s/ r/ rc/' Makefile.org
    sed -i 's/size_t tkeylen;$/size_t tkeylen = 0;/' crypto/cms/cms_enc.c
    sed -i 's/^my \$output  = shift;/my $output  = shift || "";/' crypto/md5/asm/md5-x86_64.pl

    ./config --prefix="$pH_install" --openssldir="$pH_install/openssl" shared
    $MAKE
    $MAKE install
    cd "$pH_DL"

    # Verify
    [[ -e "$pH_install/lib/libssl.so" ]] || err "OpenSSL install failed"
    [[ -e "$pH_install/lib/libcrypto.so" ]] || err "OpenSSL install failed"
    $pH_install/bin/openssl version | grep -q "$pH_SSL" || err "OpenSSL install failed"
}

function ph_err {
    err "Test err function"
}

# Readline
function ph_readline {
    status "    Installing Readline $pH_Readline..."
    cd "$pH_DL"
    if [[ ! -e "readline-$pH_Readline" ]] ; then
        $CURL "ftp://ftp.gnu.org/gnu/readline/readline-$pH_Readline.tar.gz"
        rm -rf "readline-$pH_Readline"
        tar -xzf "readline-$pH_Readline.tar.gz"
    else
        cd "$pH_DL/readline-$pH_Readline"
        $MAKE clean
        # Directory exists, clean up after old build
        rm -f "$pH_install/lib/libreadline.so.$pH_Readline"
        rm -f "$pH_install/lib/libreadline.so.6"
        rm -f "$pH_install/lib/libreadline.so"
    fi
    cd "$pH_DL/readline-$pH_Readline"
    ./configure --prefix="$pH_install" $QUIET
    $MAKE
    # Remove install error message:
    # mv: cannot stat `/home/enoki/local/lib/libreadline.a': No such file or directory
    # mv: cannot stat `/home/enoki/local/lib/libhistory.a': No such file or directory
    touch "$pH_install/lib/libreadline.a"
    touch "$pH_install/lib/libhistory.a"
    $MAKE install
    rm -f "$pH_install/lib/libreadline.old"
    rm -f "$pH_install/lib/libhistory.old"

    # Verify
    [[ -e "$pH_install/lib/libreadline.so" ]] || err "Readline install failed"
    [[ -e "$pH_install/lib/libreadline.a" ]] || err "Readline install failed"
}

# Tcl
function ph_tcl {
    status "    Installing Tcl $pH_Tcl..."
    cd "$pH_DL"
    if [[ ! -e "tcl$pH_Tcl-src" ]] ; then
        $CURL "http://prdownloads.sourceforge.net/tcl/tcl$pH_Tcl-src.tar.gz"
        rm -rf "tcl$pH_Tcl-src"
        tar -xzf "tcl$pH_Tcl-src.tar.gz"
    fi
    cd "tcl$pH_Tcl/unix"

    ./configure --prefix="$pH_install" $QUIET
    $MAKE
    $MAKE install

    # Verify
    [[ -e "$pH_install/lib/libtcl${pH_Tcl:0:3}.so" ]] || err "TCL install failed"
}

# Tk
function ph_tk {
    status "    Installing Tk $pH_Tk..."
    cd "$pH_DL"
    if [[ ! -e "tk$pH_Tcl-src" ]] ; then
        $CURL "http://prdownloads.sourceforge.net/tcl/tk$pH_Tk-src.tar.gz"
        rm -rf "tk$pH_Tk-src"
        tar -xzf "tk$pH_Tk-src.tar.gz"
    fi
    cd "tk$pH_Tk/unix"

    ./configure --prefix="$pH_install" $QUIET
    $MAKE
    $MAKE install

    # Verify
    [[ -e "$pH_install/lib/libtk${pH_Tk:0:3}.so" ]] || err "Tk install failed"
}

# Oracle Berkeley DB
function ph_berkeley {
    status "    Installing Berkeley DB $pH_Berkeley..."
    cd "$pH_DL"
    if [[ ! -e "db-$pH_Berkeley" ]] ; then
        $CURL "http://download.oracle.com/berkeley-db/db-$pH_Berkeley.tar.gz"
        rm -rf "db-$pH_Berkeley"
        tar -xzf "db-$pH_Berkeley.tar.gz"
    fi
    cd db-$pH_Berkeley/build_unix
    ../dist/configure  --prefix="$pH_install" $QUIET \
        --enable-cxx \
        --enable-tcl \
        --with-tcl="$pH_install/lib"
    $MAKE
    $MAKE install

    # Verify
    [[ -e "$pH_install/lib/libdb.so" ]] || err "Berkeley DB install failed"
}

# Bzip
function ph_bzip {
    status "    Installing BZip $pH_BZip..."
    cd "$pH_DL"
    if [[ ! -e "bzip2-$pH_BZip" ]] ; then
        $CURL "http://www.bzip.org/$pH_BZip/bzip2-$pH_BZip.tar.gz"
        rm -rf "bzip2-$pH_BZip"
        tar -xzf "bzip2-$pH_BZip.tar.gz"
    else
        cd "$pH_DL/bzip2-$pH_BZip"
        # Directory exists, clean up after old build
        $MAKE clean
        rm -f "$pH_install/lib/libbz2.so.$pH_BZip"
        rm -f "$pH_install/lib/libbz2.so.1.0"
    fi
    cd "$pH_DL/bzip2-$pH_BZip"

    # Shared library
    # Hide "Warning: inlining failed" messages
    sed -i '/^CFLAGS=/s/-Winline //' Makefile-libbz2_so
    $MAKE -f Makefile-libbz2_so
    # Static library
    $MAKE
    $MAKE install PREFIX="$pH_install"
    cp "libbz2.so.$pH_BZip" "$pH_install/lib"
    ln -s "$pH_install/lib/libbz2.so.$pH_BZip" "$pH_install/lib/libbz2.so.1.0"

    # Verify
    [[ -e "$pH_install/lib/libbz2.so.$pH_BZip" ]] || err "BZip install failed"
    $pH_install/bin/bzip2 --help 2>&1 | grep -q $pH_BZip || err "BZip install failed"
}

# SQLite
function ph_sqlite {
    status "    Installing SQLite $pH_SQLite..."
    cd "$pH_DL"
    if [[ ! -e "sqlite-autoconf-$pH_SQLite" ]] ; then
        $CURL "http://www.sqlite.org/sqlite-autoconf-$pH_SQLite.tar.gz"
        rm -rf "sqlite-autoconf-$pH_SQLite"
        tar -xzf "sqlite-autoconf-$pH_SQLite.tar.gz"
    fi
    cd "sqlite-autoconf-$pH_SQLite"

    ./configure --prefix="$pH_install" $QUIET
    $MAKE
    $MAKE install

    # Verify
    [[ -e "$pH_install/lib/libsqlite3.so" ]] || err "SQLite install failed"
    $pH_install/bin/sqlite3 --version >/dev/null || err "SQLite install failed"
}


# Python
function ph_python {
    status "    Installing Python $pH_Python..."
    # Append Berkeley DB to EPREFIX. Used by Python setup.py
    export EPREFIX="$pH_install/lib:$EPREFIX"
    cd "$pH_DL"
    $CURL "http://python.org/ftp/python/$pH_Python/Python-$pH_Python.tgz"
    rm -rf "Python-$pH_Python"
    tar -xzf "Python-$pH_Python.tgz"
    cd "Python-$pH_Python"
    export LD_LIBRARY_PATH="$pH_install/lib"
    export LD_RUN_PATH="$LD_LIBRARY_PATH"
    export LDFLAGS="\
-L$pH_install/lib \
-lpthread"
    
    export CPPFLAGS="\
-I$pH_install/include \
-I$pH_install/include/openssl \
-I$pH_install/include/readline"
    
    export CXXFLAGS="$CPPFLAGS"
    export CFLAGS="$CPPFLAGS"
    
    export CXX="g++" # disable warning message about using g++
    # Don't use Dreamhost's super-old hg
    # Old hg version causes error message:
    # abort: repository . not found!
    export HAS_HG="false"

    ./configure --prefix="$pH_install" $QUIET
    $MAKE
    $MAKE install

    # Unset EPREFIX. Used by Python setup.py
    unset EPREFIX
    cd "$pH_DL"

    # Verify
    [[ -e "$pH_install/lib/libpython${pH_Python:0:3}.a" ]] || err "Python install failed"
    $pH_install/bin/python --version 2>&1 | grep -q $pH_Python || err "Python install failed"
}

# DEPRECATED
# Pip is now installed using Distribute, instead of setuptools,
# making setuptools obsolete.  This is here for reference only.
## Python setuptools
#function ph_setuptools {
#    status "    Installing Python setuptools $pH_setuptools..."
#    cd "$pH_DL"
#    $CURL "http://pypi.python.org/packages/${pH_Python:0:3}/s/setuptools/setuptools-$pH_setuptools-py${pH_Python:0:3}.egg"
#    sh "setuptools-$pH_setuptools-py${pH_Python:0:3}.egg" -q
#    easy_install -q pip
#}

# Python PIP (package manager)
function ph_pip {
    status "    Installing Python PIP $pH_pip..."
    cd "$pH_DL"

    # Install Distribute first
    # http://www.pip-installer.org/en/latest/installing.html
    $CURL http://python-distribute.org/distribute_setup.py
    sed -i 's/log\.warn/log.debug/g' distribute_setup.py
    $PYTHON distribute_setup.py

    # Install PIP
    $CURL https://raw.github.com/pypa/pip/master/contrib/get-pip.py
    $PYTHON get-pip.py

    # Verify
    $pH_install/bin/pip --version >/dev/null || err "Python install failed"
}

# Mercurial
function ph_mercurial {
    status "    Installing Mercurial $pH_Mercurial..."
    cd "$pH_DL"
    
    # docutils required by mercurial
    $PIP install -q -U docutils

    $CURL "http://mercurial.selenic.com/release/mercurial-$pH_Mercurial.tar.gz"
    rm -rf "mercurial-$pH_Mercurial"
    tar -xzf "mercurial-$pH_Mercurial.tar.gz"
    cd "mercurial-$pH_Mercurial"
    # Remove translation messages from error output
    sed -i "/^\s*cmd = \['msgfmt'/s/'-v', //" setup.py
    $MAKE install PREFIX="$pH_install"
    cd "$pH_DL"
    cat >> ~/.hgrc <<DELIM

# Added by pyHost.sh from:
# https://github.com/kristi/dreamhost-install 
# on $(date -u)
[ui]
editor = vim
ssh = ssh -C

[extensions]
rebase =
color =
bookmarks =
convert=
# nullifies Dreamhost's shitty system-wide .hgrc
hgext.imerge = !

[color]
status.modified = magenta bold
status.added = green bold
status.removed = red bold
status.deleted = cyan bold
status.unknown = blue bold
status.ignored = black bold

[hooks]
# Prevent "hg pull" if MQ patches are applied.
prechangegroup.mq-no-pull = ! hg qtop > /dev/null 2>&1
# Prevent "hg push" if MQ patches are applied.
preoutgoing.mq-no-push = ! hg qtop > /dev/null 2>&1
# End added by pyHost.sh

DELIM

    # Verify
    [[ -e "$pH_install/lib/libpython${pH_Python:0:3}.a" ]] || err "Python install failed"
    $pH_install/bin/python --version 2>&1 | grep -q $pH_Python || err "Python install failed"
}

# VirtualEnv
function ph_virtualenv {
    status "    Installing VirtualEnv $pH_VirtualEnv..."
    cd "$pH_DL"

    $PIP install -q -U virtualenv 

    #$PIP install -q -U virtualenvwrapper
    
    # Add Virtualenvwrapper settings to .bashrc
    #cat >> ~/.bashrc <<DELIM
## Virtualenv wrapper script
#export WORKON_HOME=\$HOME/.virtualenvs
#source virtualenvwrapper.sh
#DELIM
    #source ~/.bashrc

    # Verify
    $pH_install/bin/virtualenv --version >/dev/null || err "VirtualEnv install failed"
}

# Django framework
function ph_django {
    status "    Installing Django $pH_Django..."

    $PIP install -q -U django

    # Verify
    $pH_install/bin/django-admin.py --version || err "Django install failed"
    $pH_install/bin/python -c "import django" 2>/dev/null || err "Django install failed"
}

# cURL (for Git to pull remote repos)
function ph_curl {
    status "    Installing cURL $pH_cURL..."
    cd "$pH_DL"
    $CURL "http://curl.haxx.se/download/curl-$pH_cURL.tar.gz"
    rm -rf "curl-$pH_cURL"
    tar -xzf "curl-$pH_cURL.tar.gz"
    cd "curl-$pH_cURL"
    ./configure --prefix="$pH_install" $QUIET \
        --with-ssl=${pH_install} \
        --enable-ipv6 --enable-cookies --enable-crypto-auth
    $MAKE
    $MAKE install

    # Verify
    $pH_install/bin/curl --version | grep $pH_cURL || err "Curl install failed"
    [[ -e "$pH_install/lib/libcurl.so" ]] || err "Curl install failed"
}

# Git
# NO_MMAP is needed to prevent Dreamhost killing git processes
function ph_git {
    status "    Installing Git $pH_Git..."
    cd "$pH_DL"
    $CURL "http://git-core.googlecode.com/files/git-$pH_Git.tar.gz" 
    rm -rf "git-$pH_Git"
    tar -xzf "git-$pH_Git.tar.gz"
    cd "git-$pH_Git"
    ./configure --prefix="$pH_install" NO_MMAP=1 $QUIET
    # Remove translation messages from error output
    sed -i "/MSGFMT/s/--statistics//" Makefile
    sed -i "/new build flags or prefix/s/1>&2//" Makefile
    sed -i "/new link flags/s/1>&2//" Makefile
    sed -i "/new locations or Tcl\/Tk interpreter/s/1>&2//" git-gui/Makefile
    sed -i "/MSGFMT/s/--statistics//" git-gui/Makefile
    sed -i "/MSGFMT/s/--statistics//" gitk-git/Makefile
    $MAKE
    $MAKE install

    # Verify
    $pH_install/bin/git --version | grep $pH_Git || err "Git install failed"
}


# Hg-Git
function ph_hggit {
    status "    Installing hg-git $pH_HgGit..."
    cd "$pH_DL"

    # dulwich required by hg-git
    $PIP install -q -U dulwich

    $PIP install -q -U hg-git
    cd "$pH_DL"
    # Virtualenv to .bashrc
    cat >> ~/.hgrc <<DELIM
    
# Added by pyHost.sh from:
# $pH_script_url
# on $(date -u)
[extensions]
hggit =
# End added by pyHost.sh

DELIM
}

# Cgit (git web interface)
function ph_cgit {
    status "    Installing cgit $pH_Cgit..."
    cd "$pH_DL"

    $CURL "http://hjemli.net/git/cgit/snapshot/cgit-$pH_Cgit.tar.gz"
    rm -rf "cgit-$pH_Cgit"
    tar xzf "cgit-$pH_Cgit.tar.gz"
    cd "cgit-$pH_Cgit"

    cat >> cgit.conf <<DELIM
    CGIT_CONFIG = $pH_install/cgit/cgitrc
    CGIT_SCRIPT_PATH = $pH_install/cgit
    CACHE_ROOT = $pH_install/var/cache/cgit
    prefix = $pH_install
DELIM

    $MAKE get-git
    $MAKE
    $MAKE install

    # cgitrc file
    cat >> $pH_install/cgit/cgitrc <<DELIM
# Global project settings

remove-suffix=1

clone-prefix=http://git.tsumego.me/git

enable-commit-graph=1
enable-index-links=1
enable-log-filecount=1
enable-log-linecount=1

snapshots=zip  tar.gz

readme=README

# CGIT settings

# scan-path needs to come after the global project settings!
scan-path=$HOME/git_repos

logo=cgit.png
css=cgit.css

virtual-root=/

DELIM

    # .htaccess file
    cat >> $pH_install/cgit/htaccess <<DELIM
Options +ExecCGI

DirectoryIndex cgit.cgi

SetEnv CGIT_CONFIG ./cgitrc
DELIM
    chmod 644 $pH_install/cgit/htaccess

    cat >> $pH_install/cgit/README <<DELIM
To get cgit working

    cp $pH_install/cgit/* ~/git.example.com
    cd ~/git.example.com
    mv htaccess .htaccess
    chmod 644 .htaccess

To create a repo

    cd
    mkdir git_repos && cd git_repos
    git init --bare repo.git

Edit ~/git.example.com/cgitrc with your preferred settings
DELIM

    # Verify
    [[ -e "$pH_install/cgit/cgit.cgi" ]] || err "CGit install failed"
}

# Node.js
function ph_nodejs {
    status "    Installing node.js $pH_NodeJS..."
    cd "$pH_DL"

    if [[ ! -e "node-v$pH_NodeJS" ]] ; then
        $CURL "http://nodejs.org/dist/v$pH_NodeJS/node-v$pH_NodeJS.tar.gz"
        tar -xzf "node-v$pH_NodeJS.tar.gz"
    fi
    cd "node-v$pH_NodeJS"
    ./configure --prefix="$pH_install"
    $MAKE
    $MAKE install

    # Verify
    $pH_install/bin/node --version | grep $pH_NodeJS || err "NodeJS install failed"
}

# lesscss
function ph_lesscss {
    status "    Installing lessc $pH_LessCSS..."
    cd "$pH_DL"

    if [[ ! -e "less.js" ]] ; then
        rm -rf "less.js"
        git clone -q "https://github.com/cloudhead/less.js.git"
        cd "less.js"
        #git checkout "v$pH_LessCSS"
        cd "$pH_DL"
    fi
    cd "less.js"
    cp "bin/lessc" "$pH_install/bin"
    cp -a "lib/less" "$pH_install/lesscss"

    # Verify
    [[ -e "$pH_install/bin/lessc" ]] || err "LessCSS install failed"
}

# m4
function ph_m4 {
    status "    Installing m4 $pH_M4..."
    cd "$pH_DL"

    if [[ ! -e "m4-$pH_M4" ]] ; then
        $CURL "http://ftp.gnu.org/gnu/m4/m4-$pH_M4.tar.gz"
        rm -rf "m4-$pH_M4"
        tar -xzf "m4-$pH_M4.tar.gz"
    fi
    cd "m4-$pH_M4"
    ./configure --prefix="$pH_install" $QUIET
    $MAKE
    $MAKE install

    # Verify
    $pH_install/bin/m4 --version | grep $pH_M4 || err "M4 install failed"
}

# autoconf
function ph_autoconf {
    status "    Installing autoconf $pH_Autoconf..."
    cd "$pH_DL"

    if [[ ! -e "autoconf-$pH_Autoconf" ]] ; then
        $CURL "http://ftp.gnu.org/gnu/autoconf/autoconf-$pH_Autoconf.tar.gz"
        rm -rf "autoconf-$pH_Autoconf"
        tar -xzf "autoconf-$pH_Autoconf.tar.gz"
    fi
    cd "autoconf-$pH_Autoconf"
    ./configure --prefix="$pH_install" $QUIET
    $MAKE
    $MAKE install

    # Verify
    $pH_install/bin/autoconf --version | grep $pH_Autoconf || err "Autoconf install failed"
}

# inotify
function ph_inotify {
    status "    Installing inotify $pH_Inotify..."
    cd "$pH_DL"

    if [[ ! -e "inotify-tools-$pH_Inotify" ]] ; then
        $CURL "http://github.com/downloads/rvoicilas/inotify-tools/inotify-tools-$pH_Inotify.tar.gz"
        rm -rf "inotify-tools-$pH_Inotify"
        tar -xzf "inotify-tools-$pH_Inotify.tar.gz"
    fi
    cd "inotify-tools-$pH_Inotify"
    ./configure --prefix="$pH_install" $QUIET
    $MAKE
    $MAKE install

    # Verify
    $pH_install/bin/inotifywait --help | grep -q $pH_Inotify || err "Inotify install failed"
    $pH_install/bin/inotifywatch --help | grep -q $pH_Inotify || err "Inotify install failed"
}

function ph_install {

    # Download and install
    if test "${pH_SSL+set}" == set ; then
        ph_openssl
    fi
    if test "${pH_Readline+set}" == set ; then
        ph_readline
    fi
    if test "${pH_Tcl+set}" == set ; then
        ph_tcl
    fi
    if test "${pH_Tk+set}" == set ; then
        ph_tk
    fi
    if test "${pH_Berkeley+set}" == set ; then
        ph_berkeley
    fi
    if test "${pH_BZip+set}" == set ; then
        ph_bzip
    fi
    if test "${pH_SQLite+set}" == set ; then
        ph_sqlite
    fi
    if test "${pH_Python+set}" == set ; then
        ph_python
    fi
    if test "${pH_setuptools+set}" == set ; then
        ph_setuptools
    fi
    if test "${pH_pip+set}" == set ; then
        ph_pip
    fi
    if test "${pH_Mercurial+set}" == set ; then
        ph_mercurial
    fi
    if test "${pH_VirtualEnv+set}" == set ; then
        ph_virtualenv
    fi
    if test "${pH_Django+set}" == set ; then
        ph_django
    fi
    if test "${pH_cURL+set}" == set ; then
        ph_curl
    fi
    if test "${pH_Git+set}" == set ; then
        ph_git
    fi
    if test "${pH_Cgit+set}" == set ; then
        ph_cgit
    fi
    if test "${pH_HgGit+set}" == set ; then
        ph_hggit
    fi
    if test "${pH_NodeJS+set}" == set ; then
        ph_nodejs
    fi
    if test "${pH_LessCSS+set}" == set ; then
        ph_lesscss
    fi
    if test "${pH_M4+set}" == set ; then
        ph_m4
    fi
    if test "${pH_Autoconf+set}" == set ; then
        ph_autoconf
    fi
    if test "${pH_Inotify+set}" == set ; then
        ph_inotify
    fi
    
    cd ~
    finish_time=$(date +%s)
    status ""
    status "pyHost.sh completed the installation in $((finish_time - start_time)) seconds."
    status ""
    status "Log out and log back in for the changes in your environment variables to take affect."
    status "(If you don't use bash, setup your shell so that your PATH includes your new $pH_install/bin directory.)"
    status ""
}

function ph_uninstall {
    status "Removing $pH_install"
    rm -rf "$pH_install" 

    if [[ -e "pH_install.backup" ]] ; then
        status "Restoring $pH_install.backup"
        mv "$pH_install.backup" "$pH_install"
    fi

    status "Removing $pH_log"
    rm -f "$pH_log"

    status ""
    read -p "Delete downloads at $pH_DL? [y,n] " choice 
    case ${choice:0:1} in  
      y|Y) echo "    Ok, removing $pH_DL"; rm -rf $pH_DL ;;
    esac
    echo ""

    if [[ -e $HOME/.bashrc-pHbackup ]] ; then
        echo "Restoring old ~/.bashrc"
        mv $HOME/.bashrc-pHbackup $HOME/.bashrc
    fi


    choice='n'
    [[ -e $HOME/.virtualenvs ]] && echo "" && read -p "Delete $HOME/.virtualenvs? [y,n] " choice 
    case ${choice:0:1} in  
      y|Y) echo "    Ok, removing $HOME/.virtualenvs"; rm -rf $HOME/.virtualenvs ;;
    esac

    choice='n'
    [[ -e $HOME/.hgrc ]] && echo "" && read -p "Delete $HOME/.hgrc? [y,n] " choice 
    case ${choice:0:1} in  
      y|Y) echo "    Ok, removing $HOME/.hgrc"; rm -rf $HOME/.hgrc ;;
    esac

    status ""
    status "Done."
    status ""
    status "Please log out and log back in so that environment variables will be reset."
    status ""
}

function ph_create_uninstall {
    status "    Creating uninstall script at $pH_uninstall_script"
    # Copy function definitions
    declare -f ph_init_vars >  $pH_uninstall_script
    declare -f status       >> $pH_uninstall_script
    declare -f err          >> $pH_uninstall_script
    declare -f ph_uninstall >> $pH_uninstall_script
    echo "" >> $pH_uninstall_script
    echo "ph_init_vars" >> $pH_uninstall_script
    echo "ph_uninstall" >> $pH_uninstall_script
    chmod +x $pH_uninstall_script
}

ph_init_vars

# Parse input arguments
if [ "$1" == "uninstall" ] ; then
    ph_uninstall
elif [ -z "$1" ] || [ "$1" == "install" ] ; then
    status "Installing programs into $pH_install"
    {
        ph_create_uninstall
        ph_install_setup
        ph_install
    }
else
    # Run individual install functions
    # Ex to run ph_python and ph_mercurial
    #    ./pyHost.sh python mercurial
    ph_install_setup
    for x in "$@" ; do
        "ph_$x"
    done
fi

