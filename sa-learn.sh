#!/bin/sh

#
# The Spamassassin Bayes system does not activate until a certain
# number of ham (non-spam) and spam have been learned.  The default
# is 200 of each ham and spam, but you can tune these up or down with
# these two settings: bayes_min_ham_num, bayes_min_spam_num
#

SPAM_DIR=/tmp/spam
SPAM_ARC=$SPAM_DIR.7z
SPAM_HTTP=http://untroubled.org/spam/2018-01.7z

spam_usage() { echo "
	d) spam_download
	l) spam_learn
	c) spam_cleanup
	a) spam_download && spam_learn && spam_cleanup
	"
	}

spam_run() {
	case $1 in

	d) spam_download ;;
	l) spam_learn ;;
	c) spam_cleanup ;;
	a) spam_download && spam_learn && spam_cleanup ;;
	*) spam_usage ;;

	esac
	}

spam_download() {
	which 7z || apk add p7zip ncurses
	mkdir -p $SPAM_DIR
	if [ ! -e $SPAM_ARC ]; then
		wget -O $SPAM_ARC $SPAM_HTTP
		7z e -o$SPAM_DIR $SPAM_ARC
	fi
	}

spam_learn() {
	sa-learn --progress --no-sync --spam $SPAM_DIR
	}

spam_cleanup() {
	rm -rf $SPAM_DIR $SPAM_ARC
	}

#
# run
#

spam_run $@
