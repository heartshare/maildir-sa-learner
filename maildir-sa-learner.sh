#!/bin/bash
#
# File: 	maildir-sa-learner.sh
# Description:	This script will help you to manage your spam e-mails. It is
#		executed periodically and learn your spam or non-spam e-mails.
#
# Author:	Marco Balmer <marco@balmer.name>
# License:	This program is free software; you can redistribute it and/
#	 	or modify it under the terms of the GNU General Public 
#		License as published by the Free Software Foundation; 
#		version 2 dated June, 1991.
#
# Usage:	1. install script to /usr/local/bin
#		2. Configure a cron job per user
#
# /etc/cron.d/maildir-sa-learner:
#  0 6-23 * * * user [ -x /usr/local/bin/maildir-sa-learner.sh ] && /usr/local/bin/maildir-sa-learner.sh
#
#		3. 1st run, it will create maildir folders sa-spam/ and sa-ham/
#		4. Move your spams/hams to this folders
#		5. Each further script execute will put mails to spamassasin learner
#		   binaries
#
# History:
# 25.01.2012  m. balmer  prepeared for opensourcing.
# 13.07.2009  m. balmer  Add var APP_VER for logger
# 12.07.2009  m. balmer  Error handling integrated. Locking session for cron.
# 29.04.2008  m. balmer  Redesign with functions. Check for sa-learn binary.
# 22.06.2007  m. balmer  Output optimization. logging() function added
# 21.09.2006  m. balmer  initial release
# ----------------------------------------------------------------------

# Constants ------------------------------------------------------------

shopt -s nullglob
APP_NAME="maildir-sa-learner"
APP_VER="13.07.2009"
SPAMDIR=$HOME/Maildir/.sa-spam
HAMDIR=$HOME/Maildir/.sa-ham
JUNKDIR=$HOME/Maildir/.Junk
BIN_SALEARN=/usr/bin/sa-learn
FLAG_DO=0
LOCKFILE="/var/lock/.lock_${LOGNAME}_${APP_NAME}"

# Functions ------------------------------------------------------------

line()
#
#  Description: print a single line.
#
{
logging -c "-----------------------------------------------------------------"
}

logging()
#
# Description:  It writes messages to logfile or standard output.
#
# Parameter  :  $1 - the level of message
#               $2 - the message
#
# Std. Output:  Logging messages.
#
{
 prefix=""

  case $1 in
  -e)     prefix="Error:   ";;
  -i)     prefix="Info:    ";;
  -s)     prefix="Success: ";;
  -w)     prefix="Warning: ";;
  -n)     prefix="Notice:  ";;
  -c)     prefix="         ";;
  esac
  shift
  echo "${prefix}" ${1}
}

checkState()
#
# Description:  Check for spamassassin binary
#
# Parameter  :  none
#
# Std. Output:  none
#
{
  retcR=0
  if [ ! -x ${BIN_SALEARN} ]; then retcR=3
  fi

  if [ -e ${LOCKFILE} ]; then retcR=3
    initInfo
    line
    logging -e "Can not execute ${APP_NAME}, because lockfile:"
    logging -c "${LOCKFILE} exists."
  else
    touch ${LOCKFILE}
  fi

return ${retcR}
}

initInfo()
#
# Description:  Init info message
#
# Parameter  :  none
#
# Std. Output:  output for cron email.
#
{
 line
 logging -i "Welcome, ${APP_NAME} will help you to manage your spam. It is"
 logging -c "executed periodically and learn your spam or non-spam emails."
 return 0
}


createDirs()
#
# Description:  Create imap dirs if necessary
#
# Parameter  :  none
#
# Std. Output:  output for cron email.
#
{

if [ ! -d $SPAMDIR ] || [ ! -d $SPAMDIR ] || [ -n  "`echo $SPAMDIR/cur/*`" ] || [ -n  "`echo $HAMDIR/cur/*`" ]
then
  initInfo
fi

#
# Create sa-spam and sa-ham directories if it does not exist

if [ ! -d $SPAMDIR ]
then 
 logging -i "--> create IMAP \"sa-spam\" learner directory"   
 mkdir -p $SPAMDIR/cur 
 mkdir -p $SPAMDIR/new 
 mkdir -p $SPAMDIR/tmp
 FLAG_DO=1
fi

if [ ! -d $HAMDIR ]
then
 logging -c "--> create IMAP \"sa-ham\"  (anti spam) learner directory"
 mkdir -p  $HAMDIR/cur 
 mkdir -p  $HAMDIR/new 
 mkdir -p  $HAMDIR/tmp
 FLAG_DO=1
fi

if [ ! -d $JUNKDIR ]
then
 logging -c "--> create IMAP \"Junk\" directory"
 mkdir -p  $JUNKDIR/cur 
 mkdir -p  $JUNKDIR/new 
 mkdir -p  $JUNKDIR/tmp
 FLAG_DO=1
fi

}

learnstuff()
#
# Description:  learn spam/ham
#
# Parameter  :  none
#
# Std. Output:  output for cron email.
#
# Learn the spam and ham
#
{
retLS=0
if [ -n  "`echo $SPAMDIR/cur/*`" ]
then
 line
 logging -i "Learn spam"
 find $SPAMDIR/cur -type f -exec $BIN_SALEARN --spam {} \; && rm -f $SPAMDIR/cur/*
 retLS=${?}
 find $SPAMDIR/new -type f -exec $BIN_SALEARN --spam {} \; && rm -f $SPAMDIR/new/*
 retLS=${?}
 FLAG_DO=1
fi

if [ -n  "`echo $HAMDIR/cur/*`" ]
then
 line
 logging -i "Learn ham"
 find $HAMDIR/cur  -type f -exec $BIN_SALEARN --ham  {} \;  && rm -f $HAMDIR/cur/*
 retLS=${?}
 find $HAMDIR/new  -type f -exec $BIN_SALEARN --ham  {} \;  && rm -f $HAMDIR/new/*
 retLS=${?}
 FLAG_DO=1
fi
return ${retLS}
}

footer()
#
# Description:  print footer
#
# Parameter  :  none
#
# Std. Output:  output for cron email.
#
{
if [ $FLAG_DO = 1 ]
then
  line
  LogMessage="${APP_NAME} (${APP_VER}) executed for ${LOGNAME}"
  logging -i "${LogMessage}"
  logger "${LogMessage}"
fi
}

# Main -----------------------------------------------------------------
retMAIN=2

if checkState
then
  createDirs
  if ! learnstuff; then retMAIN=3
  fi
  footer
  rm ${LOCKFILE}
  retMAIN=0
else
  FLAG_DO=1
  retMAIN=3
fi

if [ $FLAG_DO = 1 ]; then
  line
  logging -i "Script returnvalue = ${retMAIN}"
fi

exit ${retMAIN}
