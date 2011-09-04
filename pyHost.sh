#!/bin/bash -e
# =================================================
# pyHost version 2.1 beta
# 
# This script automates a the download, compiling, and local 
# installation of Python, Mercurial, Git in the home folder.
# It includes a number of dependencies 
# (berkeley db, bzip, curl, openssl, readline, sqlite, tcl, tk)
# and installs some additional plugins 
# (django, hg-git, pip, setuptools/easy_install, virtualenv).
# It has been tested on Dreamhost on a shared server running Debian.
# It should work with other hosts, but it hasn't been tested.
#
# Usage:
#
#   ./pyHost.sh
# 
# With default settings, this command will install 
# Python, Mercurial, and Git (with dependencies and some plugins)
# into ~/local.  It will add ~/local/bin to your PATH
# in your ~/.bashrc file. (If you use a different shell, you
# will need to add ~/local/bin to your PATH in your shell's
# init script.)
#
# You may delete the downloads directory after installation is complete.
#
# After installing, source .bashrc 
#     source ~/.bashrc
# or log out and log back in.  Then test that
#     which python
# returns "~/local/bin/python" and verify the python version
#     python --version
#
# *** Important environment setup info ***
# Make sure you source ~/.bashrc in your ~/.bash_profile
#   source ~/.bashrc
# OR
#   . .bashrc
# or else .bashrc will not be read when you log in, so your 
# PATH may not be setup correctly for your newly installed tools.
# http://wiki.dreamhost.com/Environment_Setup
#
# Uninstallation:
#
# Pass the uninstall flag
#
#   ./pyHost.sh uninstall
#
# OR run the uninstall script which the installation generated
#
#   ./pyHost_uninstall
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
# Updated and modified by Kristi Tsukida
# Thanks to Kelvin Wong's guide at
# http://www.kelvinwong.ca/2010/08/02/python-2-7-on-dreamhost/
# 
# Use this script at your own risk.
#
# =================================================
# 
# Changelog
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
# TODO: change script url in .bashrc
# TODO: add virtualenvwrapper?
# TODO: change the version vars for pip-installed stuff to be "pip" or something (since pip will find the latest version, we don't need to specity a version)
# TODO: auto-detect latest versions of stuff  (hard to do?)
# TODO: add flag/option for /opt style install  (Put python, mercurial, and git into their own install directories)
# TODO: more sophisticated argument parsing
# TODO: add silent/verbose flag
# 
# Ignore these errors:
# * Openssl
#     (I don't know why)
#     Use of uninitialized value $output in pattern match (m//) at asm/md5-x86_64.pl line 115
# * Readline 
#     (Makefile is trying to move existing libs, but there are no
#     existing files to move)
#     mv: cannot stat 'opt/local/lib/libreadline.a': No such file or directory
#     mv: cannot stat 'opt/local/lib/libhistory.a': No such file or directory
# * Berkeley DB
#     (I don't know why)
#     libtool.m4: error: problem compiling CXX test program
#
# Original script ver 1.5 tmslnz, May 2010
#
#
# =================================================
#

# Set DEBUG=true to allow running individual install functions by
# passing input arguments
# e.g. ./pyHost mercurial django
DEBUG=true
#TODO implement verbose/quiet output (use the print func below)
verbose=true

function ph_init_vars {
    # Current directory
    pH_PWD="$PWD"
    
    # Directory to install these packages
    pH_install="$HOME/local"
    
    # Directory to store the source archives
    pH_DL="$PWD/downloads"
    
    # Uninstall script
    pH_uninstall_script="$PWD/pyHost_uninstall"
    
    pH_log="log.txt"
    
    # TODO: update this; this is the old script
    pH_script_url="http://bitbucket.org/tmslnz/python-dreamhost-batch/src/tip/pyHost.sh"
    
    # Package versions
    #
    # Comment out anything you don't want to install...
    # ...if you are really sure you have all 
    # necessary libraries installed already.
    
    pH_Python="2.7.2"
    pH_setuptools="0.6c11" # for easy_install (need easy_install to install pip)
    pH_Mercurial="1.9.1" # Don't use pip to install Mercurial since it might not be updated
    pH_Git="1.7.6"
    pH_Django="(via pip)" #1.3 # installed via pip
    pH_VirtualEnv="(via pip)" #1.6.4 # installed via pip
    pH_HgGit="(via pip)" # installed via pip
    pH_NodeJS="0.4.11"
    pH_LessCSS="(github)"
    pH_Inotify="3.14"
    # === Python dependencies ===
    pH_SSL="1.0.0d" # for python
    pH_Readline="6.2" # for python
    pH_Tcl="8.5.10" # for python
    pH_Tk="8.5.10" # for python
    pH_Berkeley_47x="4.7.25" # for python 2.6
    pH_Berkeley_48x="4.8.30" # for python 2.7
    pH_Berkeley_50x="5.2.28" # for python 3
    pH_BZip="1.0.6" # for python
    pH_SQLite="3070701" #3.7.7.1  for python
    # === Git dependencies ===
    pH_cURL="7.21.7" # for git



    # Sets the correct version of Berkeley DB to use and download
    # by looking at the Python version number
    if [[ "${pH_Python:0:3}" == "2.6" ]]; then
        pH_Berkeley=$pH_Berkeley_47x
    elif [[ "${pH_Python:0:3}" == "2.7" ]]; then
        pH_Berkeley=$pH_Berkeley_48x
    elif [[ "${pH_Python:0:1}" == "3" ]]; then
        pH_Berkeley=$pH_Berkeley_50x
    fi
}

function print {
    if [[ "$verbose" == "true" ]] || [[ "$verbose" -gt 0 ]]  ; then
        echo "$@"
    fi
}

function ph_install_setup {
    # Let's see how long it takes to finish;
    start_time=$(date +%s)

    PH_OLD_PATH="$PATH"
    PH_OLD_PYTHONPATH="$PYTHONPATH"
    
    # Make a backup copy of the current $pH_install folder if it exists.
    if [[ -e "$pH_install" ]]; then
        echo "Warning: existing '$pH_install' directory found."
        if [[ ! -e $pH_install.backup ]] ; then
            #read -p "Create a backup copy at $pH_install.backup and continue? [y,n]" choice 
            #case ${choice:0:1} in  
            #  y|Y) echo "    ok" ;;
            #  *) echo "Exiting"; rm $pH_uninstall_script; exit ;;
            #esac
            echo "    Creating a backup copy at '$pH_install.backup'"
            cp --archive "$pH_install $pH_install.backup"
        else
            echo "    Existing backup copy found at $pH_install.backup.  No new backup will be created."
            #read -p "Existing backup copy found at $pH_install.backup.  No new backup will be created.  Continue installing? [y,n]" choice 
            #case ${choice:0:1} in  
            #  y|Y) echo "    ok" ;;
            #  *) echo "Exiting"; exit ;;
            #esac
        fi
    fi
    mkdir --parents "$pH_install" "$pH_DL"
    mkdir --parents --mode=775 "$pH_install/lib"
    
    # Backup and modify .bashrc
    if [[ ! -e ~/.bashrc-pHbackup ]] ; then
        cp ~/.bashrc ~/.bashrc-pHbackup
        cat >> ~/.bashrc <<DELIM


######################################################################
# The following lines were added by the script pyHost.sh from:
# $pH_script_url
# on $(date -u)
######################################################################

export PATH=$pH_install/bin:\$PATH

DELIM

    fi

    export PATH="$pH_install/bin:$PATH"

    #####################
    # Download and unpack
    #####################
    
    # GCC
    ####################################################################
    # Set temporary session paths for and variables for the GCC compiler
    # 
    # Specify the right version of Berkeley DB you want to use, see
    # below for DB install scripts.
    ####################################################################
    export LD_LIBRARY_PATH="$pH_install/lib"
    
    export LD_RUN_PATH="$LD_LIBRARY_PATH"
    
    export LDFLAGS="\
-L$pH_install/lib"
    
    export CPPFLAGS="\
-I$pH_install/include \
-I$pH_install/include/openssl \
-I$pH_install/include/readline"
    
    export CXXFLAGS="$CPPFLAGS"
    export CFLAGS="$CPPFLAGS"
    
}


##############################
# Download Compile and Install
##############################

# OpenSSL (required by haslib)
function ph_openssl {
    print "    Installing OpenSSL $pH_SSL..."
    cd "$pH_DL"
    if [[ ! -e "openssl-$pH_SSL" ]] ; then
        wget -q "http://www.openssl.org/source/openssl-$pH_SSL.tar.gz"
        rm -rf "openssl-$pH_SSL"
        tar -xzf "openssl-$pH_SSL.tar.gz"
        cd "openssl-$pH_SSL"
        # HACK: Avoid doing config again, since it's slow
        ./config --prefix="$pH_install" --openssldir="$pH_install/openssl" shared > /dev/null
    else
        cd "openssl-$pH_SSL"
    fi
    make --silent > /dev/null
    make install --silent > /dev/null
    cd "$pH_DL"
}

# Readline
function ph_readline {
    print "    Installing Readline $pH_Readline..."
    cd "$pH_DL"
    if [[ ! -e "readline-$pH_Readline" ]] ; then
        wget -q "ftp://ftp.gnu.org/gnu/readline/readline-$pH_Readline.tar.gz"
        rm -rf "readline-$pH_Readline"
        tar -xzf "readline-$pH_Readline.tar.gz"
    else
        cd "$pH_DL/readline-$pH_Readline"
        # Directory exists, clean up after old build
        rm -f "$pH_install/lib/libreadline.so.$pH_Readline"
        rm -f "$pH_install/lib/libreadline.so.6"
        rm -f "$pH_install/lib/libreadline.so"
    fi
    cd "readline-$pH_Readline"
    ./configure --prefix="$pH_install" --quiet >/dev/null
    make --silent
    make install --silent >/dev/null
    cd "$pH_DL"
}

# Tcl
function ph_tcl {
    print "    Installing Tcl $pH_Tcl..."
    cd "$pH_DL"
    if [[ ! -e "tcl$pH_Tcl-src" ]] ; then
        wget -q "http://prdownloads.sourceforge.net/tcl/tcl$pH_Tcl-src.tar.gz"
        rm -rf "tcl$pH_Tcl-src"
        tar -xzf "tcl$pH_Tcl-src.tar.gz"
    fi
    cd "tcl$pH_Tcl/unix"
    ./configure --prefix="$pH_install" --quiet
    make --silent >/dev/null
    make install --silent >/dev/null
    cd "$pH_DL"
}

# Tk
function ph_tk {
    print "    Installing Tk $pH_Tk..."
    cd "$pH_DL"
    if [[ ! -e "tk$pH_Tcl-src" ]] ; then
        wget -q "http://prdownloads.sourceforge.net/tcl/tk$pH_Tk-src.tar.gz"
        rm -rf "tk$pH_Tk-src"
        tar -xzf "tk$pH_Tk-src.tar.gz"
    fi
    cd "tk$pH_Tk/unix"
    ./configure --prefix="$pH_install" --quiet
    make --silent >/dev/null
    make install --silent >/dev/null
    cd "$pH_DL"
}

# Oracle Berkeley DB
function ph_berkeley {
    print "    Installing Berkeley DB $pH_Berkeley..."
    cd "$pH_DL"
    if [[ ! -e "db-$pH_Berkeley" ]] ; then
        wget -q "http://download.oracle.com/berkeley-db/db-$pH_Berkeley.tar.gz"
        rm -rf "db-$pH_Berkeley"
        tar -xzf "db-$pH_Berkeley.tar.gz"
    fi
    cd db-$pH_Berkeley/build_unix
    ../dist/configure  --quiet\
    --prefix="$pH_install" \
    --enable-tcl \
    --with-tcl="$pH_install/lib"
    make --silent >/dev/null
    make install --silent >/dev/null
    cd "$pH_DL"
}

# Bzip
function ph_bzip {
    print "    Installing BZip $pH_BZip..."
    cd "$pH_DL"
    if [[ ! -e "bzip2-$pH_BZip" ]] ; then
        wget -q "http://www.bzip.org/$pH_BZip/bzip2-$pH_BZip.tar.gz"
        rm -rf "bzip2-$pH_BZip"
        tar -xzf "bzip2-$pH_BZip.tar.gz"
    else
        cd "$pH_DL/bzip2-$pH_BZip"
        # Directory exists, clean up after old build
        make clean
        rm -f "$pH_install/lib/libbz2.so.$pH_BZip"
        rm -f "$pH_install/lib/libbz2.so.1.0"
    fi
    cd "$pH_DL/bzip2-$pH_BZip"
    # Shared library
    make -f Makefile-libbz2_so --silent >/dev/null
    # Static library
    make --silent >/dev/null
    make install PREFIX="$pH_install" --silent >/dev/null
    cp "libbz2.so.$pH_BZip" "$pH_install/lib"
    ln -s "$pH_install/lib/libbz2.so.$pH_BZip" "$pH_install/lib/libbz2.so.1.0"
    
    cd "$pH_DL"
}

# SQLite
function ph_sqlite {
    print "    Installing SQLite $pH_SQLite..."
    cd "$pH_DL"
    if [[ ! -e "sqlite-autoconf-$pH_SQLite" ]] ; then
        wget -q "http://www.sqlite.org/sqlite-autoconf-$pH_SQLite.tar.gz"
        rm -rf "sqlite-autoconf-$pH_SQLite"
        tar -xzf "sqlite-autoconf-$pH_SQLite.tar.gz"
    fi
    cd "sqlite-autoconf-$pH_SQLite"
    ./configure --prefix="$pH_install" --quiet
    make --silent >/dev/null
    make install --silent >/dev/null
    cd "$pH_DL"
}


# Python
function ph_python {
    print "    Installing Python $pH_Python..."
    # Append Berkeley DB to EPREFIX. Used by Python setup.py
    export EPREFIX="$pH_install/lib:$EPREFIX"
    cd "$pH_DL"
    wget -q "http://python.org/ftp/python/$pH_Python/Python-$pH_Python.tgz"
    rm -rf "Python-$pH_Python"
    tar -xzf "Python-$pH_Python.tgz"
    cd "Python-$pH_Python"
    export CXX="g++" # disable warning message about using g++
    ./configure --prefix="$pH_install" --quiet
    make --silent | tail
    make install --silent >/dev/null
    # Unset EPREFIX. Used by Python setup.py
    export EPREFIX=
    cd "$pH_DL"
}

# Python setuptools
function ph_setuptools {
    print "    Installing Python setuptools $pH_setuptools..."
    cd "$pH_DL"
    wget -q "http://pypi.python.org/packages/${pH_Python:0:3}/s/setuptools/setuptools-$pH_setuptools-py${pH_Python:0:3}.egg"
    sh "setuptools-$pH_setuptools-py${pH_Python:0:3}.egg"
    easy_install -q pip
}

# Mercurial
function ph_mercurial {
    print "    Installing Mercurial $pH_Mercurial..."
    cd "$pH_DL"
    
    # docutils required by mercurial
    pip install -q -U docutils

    wget -q "http://mercurial.selenic.com/release/mercurial-$pH_Mercurial.tar.gz"
    rm -rf "mercurial-$pH_Mercurial"
    tar -xzf "mercurial-$pH_Mercurial.tar.gz"
    cd "mercurial-$pH_Mercurial"
    make install PREFIX="$pH_install" --silent >/dev/null
    cd "$pH_DL"
    cat >> ~/.hgrc <<DELIM

# Added by pyHost.sh from:
# http://bitbucket.org/tmslnz/python-dreamhost-batch/src/tip/pyHost.sh
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
}

# VirtualEnv
function ph_virtualenv {
    print "    Installing VirtualEnv $pH_VirtualEnv..."
    cd "$pH_DL"
    #wget -q http://pypi.python.org/packages/source/v/virtualenv/virtualenv-$pH_VirtualEnv.tar.gz
    #rm -rf virtualenv-$pH_VirtualEnv
    #tar -xzf virtualenv-$pH_VirtualEnv.tar.gz
    #cd virtualenv-$pH_VirtualEnv
    ## Create a virtualenv
    #python virtualenv.py $pH_virtualenv_dir
    pip install -q -U virtualenv 

    #pip install -q -U virtualenvwrapper
    
    # Add Virtualenvwrapper settings to .bashrc
    #cat >> ~/.bashrc <<DELIM
## Virtualenv wrapper script
#export WORKON_HOME=\$HOME/.virtualenvs
#source virtualenvwrapper.sh
#DELIM
    #source ~/.bashrc
}

# Django framework
function ph_django {
    print "    Installing Django $pH_Django..."
    cd "$pH_DL"
    #wget -q http://www.djangoproject.com/download/$pH_Django/tarball/
    #rm -rf Django-$pH_Django
    #tar -xzf Django-$pH_Django.tar.gz
    #cd Django-$pH_Django
    #python setup.py install
    pip install -q -U django
    cd "$pH_DL"
}

# cURL (for Git to pull remote repos)
function ph_curl {
    print "    Installing cURL $pH_cURL..."
    cd "$pH_DL"
    wget -q "http://curl.haxx.se/download/curl-$pH_cURL.tar.gz"
    rm -rf "curl-$pH_cURL"
    tar -xzf "curl-$pH_cURL.tar.gz"
    cd "curl-$pH_cURL"
    ./configure --prefix="$pH_install" --quiet
    make --silent >/dev/null
    make install --silent >/dev/null
    cd "$pH_DL"
}

# Git
# NO_MMAP is needed to prevent Dreamhost killing git processes
function ph_git {
    print "    Installing Git $pH_Git..."
    cd "$pH_DL"
    wget -q "http://kernel.org/pub/software/scm/git/git-$pH_Git.tar.gz"
    rm -rf "git-$pH_Git"
    tar -xzf "git-$pH_Git.tar.gz"
    cd "git-$pH_Git"
    ./configure --prefix="$pH_install" NO_MMAP=1 --quiet
    make --silent >/dev/null
    make install --silent >/dev/null
    cd "$pH_DL"
}

# Hg-Git
function ph_hggit {
    print "    Installing hg-git $pH_HgGit..."
    cd "$pH_DL"

    # dulwich required by hg-git
    pip install -q -U dulwich

    #[ ! -e hg-git ] && mkdir hg-git
    #cd hg-git
    #wget -q http://github.com/schacon/hg-git/tarball/master
    #tar -xzf *
    #hg_git_dir=$(ls -dC */)
    #cd $hg_git_dir
    #python setup.py install
    pip install -q -U hg-git
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

# Node.js
function ph_nodejs {
    print "    Installing node.js $pH_NodeJS..."
    cd "$pH_DL"

    if [[ ! -e "node-v$pH_NodeJS" ]] ; then
        wget -q "http://nodejs.org/dist/node-v$pH_NodeJS.tar.gz"
        rm -rf "node-v$pH_NodeJS"
        tar -xzf "node-v$pH_NodeJS.tar.gz"
    fi
    cd "node-v$pH_NodeJS"
    ./configure --prefix="$pH_install" --quiet
    make --silent >/dev/null
    make install --silent >/dev/null
}

# lesscss
function ph_lesscss {
    print "    Installing lessc $pH_LessCSS..."
    cd "$pH_DL"

    if [[ ! -e "less.js" ]] ; then
        rm -rf "less.js"
        git clone -q "https://github.com/cloudhead/less.js.git"
        cd "less.js"
        git checkout "v$pH_LessCSS"
    fi
    cd "less.js"
    cp "bin/lessc" "$pH_install/bin"
    cp "lib/less" "$pH_install/lib"
}

# inotify
function ph_inotify {
    print "    Installing inotify $pH_Inotify..."
    cd "$pH_DL"

    if [[ ! -e "inotify-tools-$pH_Inotify" ]] ; then
        wget -q "http://github.com/downloads/rvoicilas/inotify-tools/inotify-tools-$pH_Inotify.tar.gz"
        rm -rf "inotify-tools-$pH_Inotify"
        tar -xzf "inotify-tools-$pH_Inotify.tar.gz"
    fi
    cd "inotify-tools-$pH_Inotify"
    ./configure --prefix="$pH_install" --quiet
    make --silent >/dev/null
    make install --silent >/dev/null
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
    if test "${pH_HgGit+set}" == set ; then
        ph_hggit
    fi
    if test "${pH_NodeJS+set}" == set ; then
        ph_nodejs
    fi
    if test "${pH_LessCSS+set}" == set ; then
        ph_lesscss
    fi
    if test "${pH_Inotify+set}" == set ; then
        ph_inotify
    fi
    
    cd ~
    finish_time=$(date +%s)
    echo "pyHost.sh completed the installation in $((finish_time - start_time)) seconds."
    echo ""
    echo "Log out and log back in for the changes in your .bashrc file to take affect."
    echo "If you don't use bash, setup your shel so that your PATH includes your new $pH_install/bin directory."
    echo ""
}

function ph_uninstall {
    echo "Removing $pH_install"
    rm -rf "$pH_install" 

    if [[ -e "pH_install.backup" ]] ; then
        echo "Restoring $pH_install.backup"
        mv "$pH_install.backup" "$pH_install"
    fi

    echo "Removing $pH_log"
    rm -f "$pH_log"

    echo ""
    read -n1 -p "Delete $pH_DL? [y,n]" choice 
    case $choice in  
      y|Y) echo "    ok"; echo "Removing $pH_DL"; rm -rf $pH_DL ;;
    esac
    echo ""

    if [[ -e $HOME/.bashrc-pHbackup ]] ; then
        echo "Restoring old ~/.bashrc"
        mv $HOME/.bashrc-pHbackup $HOME/.bashrc
    fi


    echo ""
    choice='n'
    [[ -e $HOME/.virtualenvs ]] && read -p "Delete $HOME/.virtualenvs? [y,n]" choice 
    case ${choice:0:1} in  
      y|Y) echo "    ok"; echo "Removing $HOME/.virtualenvs"; rm -rf $HOME/.virtualenvs ;;
    esac
    echo ""

    echo ""
    choice='n'
    [[ -e $HOME/.hgrc ]] && read -p "Delete $HOME/.hgrc? [y,n]" choice 
    case ${choice:0:1} in  
      y|Y) echo "    ok"; echo "Removing $HOME/.hgrc"; rm -rf $HOME/.hgrc ;;
    esac
    echo ""

    echo ""
    echo "There may also be entries in your ~/.bashrc and ~/.hgrc which need removing."
    echo ""
    echo "Done."
    echo ""
    echo "You should log out and log back in so that environment variables will be reset."
    echo "Make sure that $pH_install/bin is in your PATH before /usr/bin"
    echo ""
}

function ph_create_uninstall {
    echo "    Creating uninstall script at $pH_uninstall_script"
    # Copy the ph_init_vars and ph_uninstall function definitions
    declare -f ph_init_vars > $pH_uninstall_script
    declare -f ph_uninstall >> $pH_uninstall_script
    echo "" >> $pH_uninstall_script
    echo "ph_init_vars" >> $pH_uninstall_script
    echo "ph_uninstall" >> $pH_uninstall_script
    chmod +x $pH_uninstall_script
}

# Parse input arguments
if [ "$1" == "uninstall" ] ; then
    ph_init_vars
    ph_uninstall
elif [ -z "$1" ] || [ "$1" == "install" ] ; then
    echo "Start install"
    ph_init_vars
    {
        ph_create_uninstall
        ph_install_setup
        ph_install
    } 2>&1 | tee $pH_log
elif [ "$DEBUG" == "true" ] || [ "$DEBUG" -gt 0 ] ; then
    # DEBUG HACK
    # run individual install functions
    # Ex to run ph_python and ph_mercurial
    #    ./pyHost.sh python mercurial
    ph_init_vars
    ph_install_setup
    for x in "$@" ; do
        "ph_$x"
    done
else
    echo "Unrecognized option '$1'"
fi


