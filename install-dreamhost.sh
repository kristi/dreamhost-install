#!/bin/bash
# for debugging, use -e to stop on error
# use -x to echo each line before running
#!/bin/bash -ex
# =================================================
# install-dreamhost version 3
# 
# Installs updated versions of Python, Mercurial, Git in the home folder.
# It includes a number of dependencies 
# (berkeley db, bzip, curl, openssl, readline, sqlite, tcl, tk)
# and installs some additional programs
# (django, pip, virtualenv, cgit, lesscss, inotify).
# It has been tested on Dreamhost on a shared server running Debian.
# It should work with other hosts, but it hasn't been tested.
#
# Usage:
#
#   ./install-dreamhost.sh
# 
# Binaries are at ~/local/bin
#
# After installing, source .bashrc 
#     source ~/.bashrc
# OR simply log out and log back in.  
#
# To test if everything worked, make sure that
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
# Run the uninstall script
#
#     ./uninstall-dreamhost.sh
#
# This will remove the ~/local directory and attempt to revert
# changes made by this script.
#
# Note you can manually uninstall by deleting the ~/local directory
# and delete the entries in ~/.bashrc and ~/.hgrc.
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
# April 24 2012 - Kristi Tsukida <kristi.dev@gmail.com>
# * Add verification tests
# * Cleanup program output
# * Rename script
#
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
quiet=true

function init_vars {
    # Directory to install these packages
    prefix="$HOME/local"
    
    # Directory to store the source archives
    download_dir="$PWD/downloads"
    
    # Uninstall script
    uninstall_script="$PWD/uninstall-dreamhost.sh"
    
    log_file="log.txt"
    
    script_url="https://github.com/kristi/dreamhost-install/blob/master/install-dreamhost.sh"
    
    # Package versions
    #
    # Comment out anything you don't want to install...
    
    ruby_ver="1.9.3"
    rvm_ver="(via rvm-installer script)"
    python_ver="2.7.3"
    pip_ver="(via get-pip.py script)"
    mercurial_ver="2.1.2" # Don't use pip to install Mercurial since it might not be updated
    git_ver="1.7.10"
    cgit_ver="0.9.0.3"
    django_ver="(via pip)" # installed via pip
    virtualenv_ver="(via pip)" # installed via pip
    #hggit_ver="(via pip)" # installed via pip
    nodejs_ver="0.6.15"
    lesscss_ver="(github)"
    inotify_ver="3.14"
    # === Python dependencies ===
    ssl_ver="1.0.1a" # for python
    readline_ver="6.2" # for python
    tcl_ver="8.5.11" # for python
    tk_ver="8.5.11" # for python
    berkeley_47x_ver="4.7.25" # for python 2.6
    berkeley_48x_ver="4.8.30" # for python 2.7
    berkeley_50x_ver="5.3.15" # for python 3
    bzip_ver="1.0.6" # for python
    sqlite_ver="3071100" # 3.7.11 for python
    # === Git dependencies ===
    curl_ver="7.25.0" # for git
    # === Inotify dependencies ===
    m4_ver="1.4.16" # for inotify
    autoconf_ver="2.68" # for inotify



    # Sets the correct version of Berkeley DB to use and download
    # by looking at the Python version number
    if [[ "${python_ver:0:3}" == "2.6" ]]; then
        berkeley_ver=$berkeley_47x_ver
    elif [[ "${python_ver:0:3}" == "2.7" ]]; then
        berkeley_ver=$berkeley_48x_ver
    elif [[ "${python_ver:0:1}" == "3" ]]; then
        berkeley_ver=$berkeley_50x_ver
    fi

    # Quietly download files
    CURL="curl -O -s --show-error --fail --location --retry 1"

    # Use local versions
    PYTHON="$prefix/bin/python"
    PIP="$prefix/bin/pip"

    export PATH="$prefix/bin:$PATH"
    export PKG_CONFIG_PATH="$prefix/lib/pkgconfig:$PKG_CONFIG_PATH"
    export LD_LIBRARY_PATH="$prefix/lib"
    export LD_RUN_PATH="$LD_LIBRARY_PATH"
    export rvm_path="$prefix"

    # Save stdout as fd #3
    exec 3>&1
    # Save stderr as fd #4
    exec 4>&2

    MAKE="make"
    QUIET=""
    if [[ "$quiet" == "true" ]] ; then
        # Reduce console output
        # redirect stdout and stderr to log file
        exec >$log_file 
        #exec 2>&1

        MAKE="make --silent"
        QUIET="--quiet"
    fi
}

function status {
    # Print to stdout and to log file

    echo "$@" >&3

    echo "====================================" >> $log_file
    echo "$@" >> $log_file
    echo "====================================" >> $log_file
}

function err {
    # Print in red to stderr and exit

    echo -en '\e[1;31m' >&4
    echo -en "ERROR: $@" >&4
    echo -e '\e[0m' >&4

    exit
}

function install_setup {
    # Let's see how long it takes to finish;
    start_time=$(date +%s)

    PH_OLD_PATH="$PATH"
    PH_OLD_PYTHONPATH="$PYTHONPATH"
    
    # Make a backup copy of the current $prefix folder if it exists.
    if [[ -e "$prefix" ]]; then
        #echo "Warning: existing '$prefix' directory found."
        if [[ ! -e $prefix.backup ]] ; then
            #read -p "Create a backup copy at $prefix.backup and continue? [y,n] " choice 
            #case ${choice:0:1} in  
            #  y|Y) echo "    ok" ;;
            #  *) echo "Exiting"; rm $uninstall_script; exit ;;
            #esac
            echo "    Creating a backup of '$prefix' at '$prefix.backup'"
            cp --archive "$prefix" "$prefix.backup"
        else
            echo "    Existing backup of '$prefix' found at '$prefix.backup'.  No new backup will be created."
            #read -p "Existing backup copy found at $prefix.backup.  No new backup will be created.  Continue installing? [y,n] " choice 
            #case ${choice:0:1} in  
            #  y|Y) echo "    ok" ;;
            #  *) echo "Exiting"; exit ;;
            #esac
        fi
    fi
    mkdir --parents "$prefix" "$download_dir"
    mkdir --parents --mode=775 "$prefix/lib"
    
    # Backup and modify .bashrc
    cd
    if [[ ! -e .bashrc.dreamhost-install.backup ]] ; then
        cp .bashrc .bashrc.dreamhost-install.backup
        cat >> .bashrc <<DELIM

########   BEGIN DREAMHOST-INSTALL.SH SECTION   ########
# The following lines were added by the script dreamhost-install.sh from:
# $script_url
# on $(date -u)

export PATH=$prefix/bin:\$PATH
export rvm_path="$prefix"

########   END DREAMHOST-INSTALL.SH SECTION   ########
DELIM
        
        # Create a patch so we can undo our changes if we uninstall
        # (Undo by doing "patch .bashrc < .bashrc.dreamhost-install.undo.patch" )
        diff -u .bashrc.dreamhost-install.backup .bashrc > .bashrc.dreamhost-install.undo.patch

    fi

    # Make sure .bashrc is called by .bash_profile
    if ! grep -q "\.bashrc" ~/.bash_profile then
        echo "source ~/.bashrc" >> ~/.bash_profile
    fi

}


##############################
# Download Compile and Install
##############################

# OpenSSL
function install_openssl {
    status "    Installing OpenSSL $ssl_ver..."
    cd "$download_dir"
    if [[ ! -e "openssl-$ssl_ver" ]] ; then
        $CURL "http://www.openssl.org/source/openssl-$ssl_ver.tar.gz"
        rm -rf "openssl-$ssl_ver"
        tar -xzf "openssl-$ssl_ver.tar.gz"
        cd "openssl-$ssl_ver"
    else
        cd "openssl-$ssl_ver"
        $MAKE clean
    fi
    
    # Fix warning messages
    sed -i '/^AR=/s/ r/ rc/' Makefile.org
    sed -i 's/size_t tkeylen;$/size_t tkeylen = 0;/' crypto/cms/cms_enc.c
    sed -i 's/^my \$output  = shift;/my $output  = shift || "";/' crypto/md5/asm/md5-x86_64.pl

    ./config --prefix="$prefix" --openssldir="$prefix/openssl" shared
    $MAKE
    $MAKE install
    cd "$download_dir"

    # Verify
    [[ -e "$prefix/lib/libssl.so" ]] || err "OpenSSL install failed"
    [[ -e "$prefix/lib/libcrypto.so" ]] || err "OpenSSL install failed"
    $prefix/bin/openssl version | grep -q "$ssl_ver" || err "OpenSSL install failed"
}

function install_err {
    err "Test err function"
}

# Readline
function install_readline {
    status "    Installing Readline $readline_ver..."
    cd "$download_dir"
    if [[ ! -e "readline-$readline_ver" ]] ; then
        $CURL "ftp://ftp.gnu.org/gnu/readline/readline-$readline_ver.tar.gz"
        rm -rf "readline-$readline_ver"
        tar -xzf "readline-$readline_ver.tar.gz"
    else
        cd "$download_dir/readline-$readline_ver"
        $MAKE clean
        # Directory exists, clean up after old build
        rm -f "$prefix/lib/libreadline.so.$readline_ver"
        rm -f "$prefix/lib/libreadline.so.6"
        rm -f "$prefix/lib/libreadline.so"
    fi
    cd "$download_dir/readline-$readline_ver"
    ./configure --prefix="$prefix" $QUIET
    $MAKE
    # Remove install error message:
    # mv: cannot stat `/home/enoki/local/lib/libreadline.a': No such file or directory
    # mv: cannot stat `/home/enoki/local/lib/libhistory.a': No such file or directory
    touch "$prefix/lib/libreadline.a"
    touch "$prefix/lib/libhistory.a"
    $MAKE install
    rm -f "$prefix/lib/libreadline.old"
    rm -f "$prefix/lib/libhistory.old"

    # Verify
    [[ -e "$prefix/lib/libreadline.so" ]] || err "Readline install failed"
    [[ -e "$prefix/lib/libreadline.a" ]] || err "Readline install failed"
}

# Tcl
function install_tcl {
    status "    Installing Tcl $tcl_ver..."
    cd "$download_dir"
    if [[ ! -e "tcl$tcl_ver-src" ]] ; then
        $CURL "http://prdownloads.sourceforge.net/tcl/tcl$tcl_ver-src.tar.gz"
        rm -rf "tcl$tcl_ver-src"
        tar -xzf "tcl$tcl_ver-src.tar.gz"
    fi
    cd "tcl$tcl_ver/unix"

    ./configure --prefix="$prefix" $QUIET
    $MAKE
    $MAKE install

    # Verify
    [[ -e "$prefix/lib/libtcl${tcl_ver:0:3}.so" ]] || err "TCL install failed"
}

# Tk
function install_tk {
    status "    Installing Tk $tk_ver..."
    cd "$download_dir"
    if [[ ! -e "tk$tcl_ver-src" ]] ; then
        $CURL "http://prdownloads.sourceforge.net/tcl/tk$tk_ver-src.tar.gz"
        rm -rf "tk$tk_ver-src"
        tar -xzf "tk$tk_ver-src.tar.gz"
    fi
    cd "tk$tk_ver/unix"

    ./configure --prefix="$prefix" $QUIET
    $MAKE
    $MAKE install

    # Verify
    [[ -e "$prefix/lib/libtk${tk_ver:0:3}.so" ]] || err "Tk install failed"
}

# Oracle Berkeley DB
function install_berkeley {
    status "    Installing Berkeley DB $berkeley_ver..."
    cd "$download_dir"
    if [[ ! -e "db-$berkeley_ver" ]] ; then
        $CURL "http://download.oracle.com/berkeley-db/db-$berkeley_ver.tar.gz"
        rm -rf "db-$berkeley_ver"
        tar -xzf "db-$berkeley_ver.tar.gz"
    fi
    cd db-$berkeley_ver/build_unix
    ../dist/configure  --prefix="$prefix" $QUIET \
        --enable-cxx \
        --enable-tcl \
        --with-tcl="$prefix/lib"
    $MAKE
    $MAKE install

    # Verify
    [[ -e "$prefix/lib/libdb.so" ]] || err "Berkeley DB install failed"
}

# Bzip
function install_bzip {
    status "    Installing BZip $bzip_ver..."
    cd "$download_dir"
    if [[ ! -e "bzip2-$bzip_ver" ]] ; then
        $CURL "http://www.bzip.org/$bzip_ver/bzip2-$bzip_ver.tar.gz"
        rm -rf "bzip2-$bzip_ver"
        tar -xzf "bzip2-$bzip_ver.tar.gz"
    else
        cd "$download_dir/bzip2-$bzip_ver"
        # Directory exists, clean up after old build
        $MAKE clean
        rm -f "$prefix/lib/libbz2.so.$bzip_ver"
        rm -f "$prefix/lib/libbz2.so.1.0"
    fi
    cd "$download_dir/bzip2-$bzip_ver"

    # Shared library
    # Hide "Warning: inlining failed" messages
    sed -i '/^CFLAGS=/s/-Winline //' Makefile-libbz2_so
    $MAKE -f Makefile-libbz2_so
    # Static library
    $MAKE
    $MAKE install PREFIX="$prefix"
    cp "libbz2.so.$bzip_ver" "$prefix/lib"
    ln -s "$prefix/lib/libbz2.so.$bzip_ver" "$prefix/lib/libbz2.so.1.0"

    # Verify
    [[ -e "$prefix/lib/libbz2.so.$bzip_ver" ]] || err "BZip install failed"
    $prefix/bin/bzip2 --help 2>&1 | grep -q $bzip_ver || err "BZip install failed"
}

# SQLite
function install_sqlite {
    status "    Installing SQLite $sqlite_ver..."
    cd "$download_dir"
    if [[ ! -e "sqlite-autoconf-$sqlite_ver" ]] ; then
        $CURL "http://www.sqlite.org/sqlite-autoconf-$sqlite_ver.tar.gz"
        rm -rf "sqlite-autoconf-$sqlite_ver"
        tar -xzf "sqlite-autoconf-$sqlite_ver.tar.gz"
    fi
    cd "sqlite-autoconf-$sqlite_ver"

    ./configure --prefix="$prefix" $QUIET
    $MAKE
    $MAKE install

    # Verify
    [[ -e "$prefix/lib/libsqlite3.so" ]] || err "SQLite install failed"
    $prefix/bin/sqlite3 --version >/dev/null || err "SQLite install failed"
}


# Python
function install_python {
    status "    Installing Python $python_ver..."
    # Append Berkeley DB to EPREFIX. Used by Python setup.py
    export EPREFIX="$prefix/lib:$EPREFIX"
    cd "$download_dir"
    $CURL "http://python.org/ftp/python/$python_ver/Python-$python_ver.tgz"
    rm -rf "Python-$python_ver"
    tar -xzf "Python-$python_ver.tgz"
    cd "Python-$python_ver"
    export LD_LIBRARY_PATH="$prefix/lib"
    export LD_RUN_PATH="$LD_LIBRARY_PATH"
    export LDFLAGS="\
-L$prefix/lib \
-lpthread"
    
    export CPPFLAGS="\
-I$prefix/include \
-I$prefix/include/openssl \
-I$prefix/include/readline"
    
    export CXXFLAGS="$CPPFLAGS"
    export CFLAGS="$CPPFLAGS"
    
    export CXX="g++" # disable warning message about using g++
    # Don't use Dreamhost's super-old hg
    # Old hg version causes error message:
    # abort: repository . not found!
    export HAS_HG="false"

    ./configure --prefix="$prefix" $QUIET
    $MAKE
    $MAKE install

    # Unset EPREFIX. Used by Python setup.py
    unset EPREFIX
    cd "$download_dir"

    # Verify
    [[ -e "$prefix/lib/libpython${python_ver:0:3}.a" ]] || err "Python install failed"
    $prefix/bin/python --version 2>&1 | grep -q $python_ver || err "Python install failed"
}

# DEPRECATED
# Pip is now installed using Distribute, instead of setuptools,
# making setuptools obsolete.  This is here for reference only.
## Python setuptools
#function install_setuptools {
#    status "    Installing Python setuptools $setuptools_ver..."
#    cd "$download_dir"
#    $CURL "http://pypi.python.org/packages/${python_ver:0:3}/s/setuptools/setuptools-$setuptools_ver-py${python_ver:0:3}.egg"
#    sh "setuptools-$setuptools_ver-py${python_ver:0:3}.egg" -q
#    easy_install -q pip
#}

# PIP (package manager)
function install_pip {
    status "    Installing Pip $pip_ver..."
    cd "$download_dir"

    # Install Distribute first
    # http://www.pip-installer.org/en/latest/installing.html
    $CURL http://python-distribute.org/distribute_setup.py
    sed -i 's/log\.warn/log.debug/g' distribute_setup.py
    $PYTHON distribute_setup.py

    # Install PIP
    $CURL https://raw.github.com/pypa/pip/master/contrib/get-pip.py
    $PYTHON get-pip.py

    # Verify
    $prefix/bin/pip --version >/dev/null || err "Pip install failed"
}

# Mercurial
function install_mercurial {
    status "    Installing Mercurial $mercurial_ver..."
    cd "$download_dir"
    
    # docutils required by mercurial
    $PIP install -q -U docutils

    $CURL "http://mercurial.selenic.com/release/mercurial-$mercurial_ver.tar.gz"
    rm -rf "mercurial-$mercurial_ver"
    tar -xzf "mercurial-$mercurial_ver.tar.gz"
    cd "mercurial-$mercurial_ver"
    # Remove translation messages from error output
    sed -i "/^\s*cmd = \['msgfmt'/s/'-v', //" setup.py
    $MAKE install PREFIX="$prefix"
    cd "$download_dir"
    cat >> ~/.hgrc <<DELIM

# Added by install-dreamhost.sh from:
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
# End added by install-dreamhost.sh

DELIM

    # Verify
    [[ -e "$prefix/lib/libpython${python_ver:0:3}.a" ]] || err "Python install failed"
    $prefix/bin/python --version 2>&1 | grep -q $python_ver || err "Python install failed"
}

# VirtualEnv
function install_virtualenv {
    status "    Installing VirtualEnv $virtualenv_ver..."
    cd "$download_dir"

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
    $prefix/bin/virtualenv --version >/dev/null || err "VirtualEnv install failed"
}

# Django framework
function install_django {
    status "    Installing Django $django_ver..."

    $PIP install -q -U django

    # Verify
    $prefix/bin/django-admin.py --version || err "Django install failed"
    $prefix/bin/python -c "import django" 2>/dev/null || err "Django install failed"
}

# cURL (for Git to pull remote repos)
function install_curl {
    status "    Installing cURL $curl_ver..."
    cd "$download_dir"
    $CURL "http://curl.haxx.se/download/curl-$curl_ver.tar.gz"
    rm -rf "curl-$curl_ver"
    tar -xzf "curl-$curl_ver.tar.gz"
    cd "curl-$curl_ver"
    ./configure --prefix="$prefix" $QUIET \
        --with-ssl=${prefix} \
        --enable-ipv6 --enable-cookies --enable-crypto-auth
    $MAKE
    $MAKE install

    # Verify
    $prefix/bin/curl --version | grep $curl_ver || err "Curl install failed"
    [[ -e "$prefix/lib/libcurl.so" ]] || err "Curl install failed"
}

# Git
# NO_MMAP is needed to prevent Dreamhost killing git processes
function install_git {
    status "    Installing Git $git_ver..."
    cd "$download_dir"
    $CURL "http://git-core.googlecode.com/files/git-$git_ver.tar.gz" 
    rm -rf "git-$git_ver"
    tar -xzf "git-$git_ver.tar.gz"
    cd "git-$git_ver"
    ./configure --prefix="$prefix" NO_MMAP=1 $QUIET
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
    $prefix/bin/git --version | grep $git_ver || err "Git install failed"
}


# Hg-Git
function install_hggit {
    status "    Installing hg-git $hggit_ver..."
    cd "$download_dir"

    # dulwich required by hg-git
    $PIP install -q -U dulwich

    $PIP install -q -U hg-git
    cd "$download_dir"
    # Virtualenv to .bashrc
    cat >> ~/.hgrc <<DELIM
    
# Added by install-dreamhost.sh from:
# $script_url
# on $(date -u)
[extensions]
hggit =
# End added by install-dreamhost.sh

DELIM
}

# Cgit (git web interface)
function install_cgit {
    status "    Installing cgit $cgit_ver..."
    cd "$download_dir"

    $CURL "http://hjemli.net/git/cgit/snapshot/cgit-$cgit_ver.tar.gz"
    rm -rf "cgit-$cgit_ver"
    tar xzf "cgit-$cgit_ver.tar.gz"
    cd "cgit-$cgit_ver"

    cat >> cgit.conf <<DELIM
    CGIT_CONFIG = $prefix/cgit/cgitrc
    CGIT_SCRIPT_PATH = $prefix/cgit
    CACHE_ROOT = $prefix/var/cache/cgit
    prefix = $prefix
DELIM

    $MAKE get-git
    $MAKE
    $MAKE install

    # cgitrc file
    cat >> $prefix/cgit/cgitrc <<DELIM
# Global project settings

remove-suffix=1

clone-prefix=ssh://user@example.com:git_repos

enable-commit-graph=1
enable-index-links=1
enable-log-filecount=1
enable-log-linecount=1

snapshots=zip  tar.gz

readme=README

# CGIT settings

# scan-path needs to come after the global project settings!
# Put your git repos in this folder
scan-path=$HOME/git_repos

logo=cgit.png
css=cgit.css

virtual-root=/

DELIM

    # .htaccess file
    cat >> $prefix/cgit/htaccess <<DELIM
Options +ExecCGI

DirectoryIndex cgit.cgi

SetEnv CGIT_CONFIG ./cgitrc
DELIM
    chmod 644 $prefix/cgit/htaccess

    cat >> $prefix/cgit/README <<DELIM
To get cgit working

    cp $prefix/cgit/* ~/git.example.com
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
    [[ -e "$prefix/cgit/cgit.cgi" ]] || err "CGit install failed"
}

# Node.js
function install_nodejs {
    status "    Installing node.js $nodejs_ver..."
    cd "$download_dir"

    if [[ ! -e "node-v$nodejs_ver" ]] ; then
        $CURL "http://nodejs.org/dist/v$nodejs_ver/node-v$nodejs_ver.tar.gz"
        tar -xzf "node-v$nodejs_ver.tar.gz"
    fi
    cd "node-v$nodejs_ver"
    ./configure --prefix="$prefix"
    $MAKE
    $MAKE install

    # Verify
    $prefix/bin/node --version | grep $nodejs_ver || err "NodeJS install failed"
}

# lesscss
function install_lesscss {
    status "    Installing lessc $lesscss_ver..."
    cd "$download_dir"

    if [[ ! -e "less.js" ]] ; then
        rm -rf "less.js"
        git clone -q "https://github.com/cloudhead/less.js.git"
        cd "less.js"
        #git checkout "v$lesscss_ver"
        cd "$download_dir"
    fi
    cd "less.js"
    cp "bin/lessc" "$prefix/bin"
    cp -a "lib/less" "$prefix/lesscss"

    # Verify
    [[ -e "$prefix/bin/lessc" ]] || err "LessCSS install failed"
}

# m4
function install_m4 {
    status "    Installing m4 $m4_ver..."
    cd "$download_dir"

    if [[ ! -e "m4-$m4_ver" ]] ; then
        $CURL "http://ftp.gnu.org/gnu/m4/m4-$m4_ver.tar.gz"
        rm -rf "m4-$m4_ver"
        tar -xzf "m4-$m4_ver.tar.gz"
    fi
    cd "m4-$m4_ver"
    ./configure --prefix="$prefix" $QUIET
    $MAKE
    $MAKE install

    # Verify
    $prefix/bin/m4 --version | grep $m4_ver || err "M4 install failed"
}

# autoconf
function install_autoconf {
    status "    Installing autoconf $autoconf_ver..."
    cd "$download_dir"

    if [[ ! -e "autoconf-$autoconf_ver" ]] ; then
        $CURL "http://ftp.gnu.org/gnu/autoconf/autoconf-$autoconf_ver.tar.gz"
        rm -rf "autoconf-$autoconf_ver"
        tar -xzf "autoconf-$autoconf_ver.tar.gz"
    fi
    cd "autoconf-$autoconf_ver"
    ./configure --prefix="$prefix" $QUIET
    $MAKE
    $MAKE install

    # Verify
    $prefix/bin/autoconf --version | grep $autoconf_ver || err "Autoconf install failed"
}

# inotify
function install_inotify {
    status "    Installing inotify $inotify_ver..."
    cd "$download_dir"

    if [[ ! -e "inotify-tools-$inotify_ver" ]] ; then
        $CURL "http://github.com/downloads/rvoicilas/inotify-tools/inotify-tools-$inotify_ver.tar.gz"
        rm -rf "inotify-tools-$inotify_ver"
        tar -xzf "inotify-tools-$inotify_ver.tar.gz"
    fi
    cd "inotify-tools-$inotify_ver"
    ./configure --prefix="$prefix" $QUIET
    $MAKE
    $MAKE install

    # Verify
    $prefix/bin/inotifywait --help | grep -q $inotify_ver || err "Inotify install failed"
    $prefix/bin/inotifywatch --help | grep -q $inotify_ver || err "Inotify install failed"
}

# rvm
function install_rvm {
    status "    Installing RVM $rvm_ver..."
    cd "$download_dir"

    $CURL "https://raw.github.com/wayneeseguin/rvm/master/binscripts/rvm-installer"
    chmod +x rvm-installer
    ./rvm-installer --path $prefix stable

    # Verify
    $prefix/bin/rvm --version >/dev/null || err "RVM install failed"
}

# ruby
function install_ruby {
    status "    Installing Ruby $ruby_ver..."
    cd "$download_dir"

    $prefix/bin/rvm install "$ruby_ver"

    # Verify
    $prefix/bin/ruby --version | grep -q "$ruby_ver" || err "Ruby install failed"
}

function install_programs {

    # Download and install
    if test "${ssl_ver+set}" == set ; then
        install_openssl
    fi
    if test "${readline_ver+set}" == set ; then
        install_readline
    fi
    if test "${tcl_ver+set}" == set ; then
        install_tcl
    fi
    if test "${tk_ver+set}" == set ; then
        install_tk
    fi
    if test "${berkeley_ver+set}" == set ; then
        install_berkeley
    fi
    if test "${bzip_ver+set}" == set ; then
        install_bzip
    fi
    if test "${sqlite_ver+set}" == set ; then
        install_sqlite
    fi
    if test "${python_ver+set}" == set ; then
        install_python
    fi
    #if test "${setuptools_ver+set}" == set ; then
    #    install_setuptools
    #fi
    if test "${pip_ver+set}" == set ; then
        install_pip
    fi
    if test "${mercurial_ver+set}" == set ; then
        install_mercurial
    fi
    if test "${virtualenv_ver+set}" == set ; then
        install_virtualenv
    fi
    if test "${django_ver+set}" == set ; then
        install_django
    fi
    if test "${curl_ver+set}" == set ; then
        install_curl
    fi
    if test "${git_ver+set}" == set ; then
        install_git
    fi
    if test "${cgit_ver+set}" == set ; then
        install_cgit
    fi
    if test "${hggit_ver+set}" == set ; then
        install_hggit
    fi
    if test "${rvm_ver+set}" == set ; then
        install_rvm
    fi
    if test "${ruby_ver+set}" == set ; then
        install_ruby
    fi
    if test "${nodejs_ver+set}" == set ; then
        install_nodejs
    fi
    if test "${lesscss_ver+set}" == set ; then
        install_lesscss
    fi
    if test "${m4_ver+set}" == set ; then
        install_m4
    fi
    if test "${autoconf_ver+set}" == set ; then
        install_autoconf
    fi
    if test "${inotify_ver+set}" == set ; then
        install_inotify
    fi
    
    cd ~
    finish_time=$(date +%s)
    status ""
    status "install-dreamhost.sh completed the installation in $((finish_time - start_time)) seconds."
    status ""
    status "Log out and log back in for the changes in your environment variables to take affect."
    status "(If you don't use bash, setup your shell so that your PATH includes your new $prefix/bin directory.)"
    status ""
}

function uninstall_programs {
    status "Removing $prefix"
    rm -rf "$prefix" 

    if [[ -e "prefix.backup" ]] ; then
        status "Restoring $prefix.backup"
        mv "$prefix.backup" "$prefix"
    fi

    status "Removing $log_file"
    rm -f "$log_file"

    status ""
    read -p "Delete downloads at $download_dir? [y,n] " choice 
    case ${choice:0:1} in  
      y|Y) echo "    Ok, removing $download_dir"; rm -rf $download_dir ;;
    esac
    echo ""

    if [[ -e $HOME/.bashrc.dreamhost-install.backup ]] ; then
        echo "Restoring old ~/.bashrc"
        mv $HOME/.bashrc $HOME/.bashrc.bak
        mv $HOME/.bashrc.dreamhost-install.backup $HOME/.bashrc
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

function create_uninstall {
    status "    Creating uninstall script at $uninstall_script"
    # Copy function definitions
    declare -f init_vars >  $uninstall_script
    declare -f status       >> $uninstall_script
    declare -f err          >> $uninstall_script
    declare -f uninstall_programs >> $uninstall_script
    echo "" >> $uninstall_script
    echo "init_vars" >> $uninstall_script
    echo "uninstall_programs" >> $uninstall_script
    chmod +x $uninstall_script
}

init_vars

# Parse input arguments
if [ "$1" == "uninstall" ] ; then
    uninstall_programs
elif [ -z "$1" ] || [ "$1" == "install" ] ; then
    status "Installing programs into $prefix"
    {
        create_uninstall
        install_setup
        install_programs
    }
else
    # Run individual install functions
    # Ex to run install_python and install_mercurial
    #    ./install-dreamhost.sh python mercurial
    install_setup
    for x in "$@" ; do
        "install_$x"
    done
fi

