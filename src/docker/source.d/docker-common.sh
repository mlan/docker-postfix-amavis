#!/bin/sh
#
# docker-common.inc
#
# Define variables and functions used during container initialization here
# and source this file in docker-entry.d and docker-exit.d files.
#
HOSTNAME=${HOSTNAME-$(hostname)}
DOMAIN=${HOSTNAME#*.}
TLS_KEYBITS=${TLS_KEYBITS-2048}
TLS_CERTDAYS=${TLS_CERTDAYS-30}

#
# general file manipulation commands, used both during build and run time
#

_escape() { echo "$@" | sed 's|/|\\\/|g' | sed 's|;|\\\;|g'  | sed 's|\$|\\\$|g' | sed "s/""'""/\\\x27/g" ;}

dc_modify() {
	local cfg_file=$1
	shift
	local lhs="$1"
	shift
	local eq=
	local rhs=
	if [ "$1" = "=" ]; then
		eq="$1"
		shift
		rhs="$(_escape $@)"
	else
		rhs="$(_escape $@)"
	fi
	dc_log 7 's/.*('"$lhs"'\s*'"$eq"'\s*)[^#]+(.*)/\1'"$rhs"' \2/g' $cfg_file
	sed -ri 's/.*('"$lhs"'\s*'"$eq"'\s*)[^#]+(.*)/\1'"$rhs"' \2/g' $cfg_file
}

dc_replace() {
	local cfg_file=$1
	local old="$(_escape $2)"
	local new="$(_escape $3)"
	dc_log 7 's/'"$old"'/'"$new"'/g' $cfg_file
	sed -i 's/'"$old"'/'"$new"'/g' $cfg_file
}

dc_addafter() {
	local cfg_file=$1
	local startline="$(_escape $2)"
	local new="$(_escape $3)"
	dc_log 7 '/'"$startline"'/!{p;d;}; $!N;s/\n\s*$/\n'"$new"'\n/g' $cfg_file
	sed -i '/'"$startline"'/!{p;d;}; $!N;s/\n\s*$/\n'"$new"'\n/g' $cfg_file
#	sed -ri '$!N;s/('"$startline"'.*\n)\s*$/\1\n'"$new"'\n/g;x;x' $cfg_file
#	sed -ri 'N;s/('"$startline"'.*)\n\s*$/\1\n'"$new"'\n/g' $cfg_file
#	sed -i '/'"$startline"'/a '"$new" $cfg_file
}

dc_comment() {
	local cfg_file=$1
	local string="$2"
	dc_log 7 '/^'"$string"'/s/^/#/g' $cfg_file
	sed -i '/^'"$string"'/s/^/#/g' $cfg_file
}

dc_uncommentsection() {
	local cfg_file=$1
	local startline="$(_escape $2)"
	dc_log 7 '/^'"$startline"'$/,/^\s*$/s/^#*//g' $cfg_file
	sed -i '/^'"$startline"'$/,/^\s*$/s/^#*//g' $cfg_file
}

dc_removeline() {
	local cfg_file=$1
	local string="$2"
	dc_log 7 '/'"$string"'.*/d' $cfg_file
	sed -i '/'"$string"'.*/d' $cfg_file
}

dc_uniquelines() {
	local cfg_file=$1
	dc_log 7 '$!N; /^(.*)\n\1$/!P; D' $cfg_file
	sed -ri '$!N; /^(.*)\n\1$/!P; D' $cfg_file
}


#
# Persist dirs
#

#
# Make sure that we have the required directory structure in place under
# DOCKER_PERSIST_DIR. It will be missing if we mount an empty volume there.
#
dc_persist_mkdirs() {
	local dirs=$@
	for dir in $dirs; do
		mkdir -p ${DOCKER_PERSIST_DIR}${dir}
	done
}

#
# mv dir to persist location and leave a link to it
#
dc_persist_mvdirs() {
	local srcdirs="$@"
	if [ -n "$DOCKER_PERSIST_DIR" ]; then
		for srcdir in $srcdirs; do
			if [ -e "$srcdir" ]; then
				local dstdir="${DOCKER_PERSIST_DIR}${srcdir}"
				local dsthome="$(dirname $dstdir)"
				if [ ! -d "$dstdir" ]; then
					dc_log 5 "Moving $srcdir to $dstdir"
					mkdir -p "$dsthome"
					mv "$srcdir" "$dsthome"
					ln -sf "$dstdir" "$srcdir"
				else
					dc_log 4 "$srcdir already moved to $dstdir"
				fi
			else
				dc_log 4 "Cannot find $srcdir"
			fi
		done
	fi
}

#
#
#

dc_chowncond() {
	local user=$1
	local dir=$2
	if id $user > /dev/null 2>&1; then
		if [ -n "$(find $dir ! -user $user -print -exec chown -h $user: {} \;)" ]; then
			dc_log 5 "Changed owner to $user for some files in $dir"
		fi
	fi
}

dc_cpfile() {
	local suffix=$1
	shift
	local cfs=$@
	for cf in $cfs; do
		cp "$cf" "$cf.$suffix"
	done
}

dc_mvfile() {
	local suffix=$1
	shift
	local cfs=$@
	for cf in $cfs; do
		mv "$cf" "$cf.$suffix"
	done
}

#
# TLS/SSL Certificates [openssl]
#

dc_tls_setup_selfsigned_cert() {
	local cert=$1
	local key=$2
	if ([ ! -s $cert ] || [ ! -s $key ]); then
		dc_log 5 "Setup self-signed TLS certificate for host $HOSTNAME"
		openssl genrsa -out $key $TLS_KEYBITS
		openssl req -x509 -utf8 -new -batch -subj "/CN=$HOSTNAME" \
			-days $TLS_CERTDAYS -key $key -out $cert
	fi
}
