#!/bin/sh

# use /etc/service if $docker_build_runit_root not already defined
docker_build_runit_root=${docker_build_runit_root-/etc/service}
#docker_build_svlog_root=${docker_build_svlog_root-/var/log/sv}

#
# Define helpers
#

init_service() {
	local cmd="$1"
	shift
	local runit_dir=$docker_build_runit_root/${cmd##*/}
	local svlog_dir=$docker_build_svlog_root/${cmd##*/}
	cmd=$(which $cmd)
	if [ ! -z "$cmd" ]; then
		mkdir -p $runit_dir
		cat <<-! > $runit_dir/run
			#!/bin/sh -e
			exec 2>&1
			exec $cmd $@
		!
		chmod +x $runit_dir/run
		if [ -n "$docker_build_svlog_root" ]; then
			mkdir -p $runit_dir/log $svlog_dir
			cat <<-! > $runit_dir/log/run
				#!/bin/sh
				exec svlogd -tt $svlog_dir
			!
			chmod +x $runit_dir/log/run
		fi
	fi
	}

down_service() {
	local cmd=$1
	touch $docker_build_runit_root/$cmd/down
	}

#
# run
#

for cmd in "$@" ; do
	init_service $cmd
done
