#!/bin/sh

. $LKP_SRC/lib/env.sh

escape_cgi_param()
{
	local uri="$1"
	# uri=${uri//%/%25} # must be the first one
	# uri=${uri//+/%2B}
	# uri=${uri//&/%26}
	# uri=${uri//\?/%3F}
	# uri=${uri//@/%40}
	# uri=${uri//:/%3A}
	# uri=${uri//;/%3D}
	echo "$uri" |
	sed	-e 's/%/%25/g' \
		-e 's/+/%2B/g' \
		-e 's/&/%26/g' \
		-e 's/\?/%3F/g'
}

reset_broken_ipmi()
{
	[ -f "$RESULT_MNT/.IPMI-reset/$HOSTNAME" ] || return
	[ -x '/usr/sbin/bmc-device' ] || return

	bmc-device --cold-reset
	mv -f $RESULT_MNT/.IPMI-reset/$HOSTNAME $RESULT_MNT/.IPMI-reset/.$HOSTNAME
}

#
# job handling at client is finished, tell server to do some
# post handling, such as delete the job file, process all
# monitors data, and so on
#
trigger_post_process()
{
	http_get_cgi "cgi-bin/lkp-post-run?job_file="$(escape_cgi_param "$job")

	reset_broken_ipmi
}

jobfile_append_var()
{
	[ -n "$job" ] || return

	# input example: "var1=value1" "var2=value2 value_with_space" ....
	[ -z "$*" ] && LOG_ERROR "no paramter specified at $FUNCTION" && return

	local query_str=job_file=$(escape_cgi_param "$job")
	for assignment in "$@"; do
		query_str="${query_str}&$(escape_cgi_param "$assignment")"
	done

	http_get_cgi "cgi-bin/lkp-jobfile-append-var?$query_str"
}

set_job_state()
{
	jobfile_append_var "job_state=$1"
}

####################################################

http_do_request()
{
	local path="$1"
	shift

	[ -n "$NO_NETWORK" ] && {
		echo skip http request: $path "$@"
		return
	}

	# $ busybox wget http://XXX:/
	# wget: bad port spec 'XXX:'
	local http_prefix="http://$LKP_SERVER:${LKP_CGI_PORT:-80}/~$LKP_USER"

	echo \
	$http_client_cmd "$http_prefix/$path" "$@"
	$http_client_cmd "$http_prefix/$path" "$@"
}

http_setup_client()
{
	[ -n "$http_client_cmd" ] && return

	. $LKP_SRC/lib/wget.sh	&& return
	. $LKP_SRC/lib/curl.sh	&& return
	. $LKP_SRC/lib/wget_busybox.sh	&& return

	echo "Cannot find wget/curl." >&2
	return 1
}

http_get_file()
{
	http_setup_client && http_get_file "$@"
}

http_get_newer()
{
	http_setup_client && http_get_newer "$@"
}

http_get_cgi()
{
	http_setup_client && http_get_cgi "$@"
}

