#!/bin/sh
#
# docker-func.sh
#
# Allow functions to be accessed via the CLI.
#

#
# source common functions
#
source docker-common.sh

#
# df_docker_call_func "$@"
#
df_docker_call_func() {
	calledformcli=true
	local cmd=$1
	shift
	dc_log 7 "CMD:$cmd ARG:$@"
	$cmd "$@"
	exit 0
}

#
# df_docker_run_parts dir name
# Read and execute commands from files in the _current_ shell environment
#
df_docker_run_parts() {
	for file in $(find $1 -type f -name "$2" -executable 2>/dev/null|sort); do
		dc_log 7 run_parts: executing $file
		. $file
	done
}

#
# source files with function definitions
#
df_docker_run_parts "$DOCKER_ENTRY_DIR" "1*"

#
# call function
#
df_docker_call_func "$@"
