#!/bin/bash

RS=0;

R1="^([0-9]{1,3})@"
R1+="([a-z]+)@"
R1+="([a-z]+)@"
R1+="([A-Z]{3,4})?@"
R1+="([a-z]+)?@"
R1+="([0-9a-zA-Z\.|<#]+)?@"
R1+="([0-9a-zA-Z\.|#]+)?@"
R1+="([0-9A-Za-z\.\-]+)@"
R1+="([0-9]+)?"
R1+="(@(([a-z0-9]+)=\"([0-9A-Za-z: -./]+)\"))?$";

DEVFILE="";
DEVFILEPASS="";
GITDIR="";
DLST="";
CMNT="";
DOLS=0;
VERB=0;
GITPP=1;

EXPECT="/usr/bin/expect";
OPENSSL="/usr/bin/openssl";
EXPECTAGR="-nN -f -";

OPENSSL_OPT="-pbkdf2 -iter 1000 -aes-256-cbc -md SHA256";

while getopts ":d:f:n:c:plvLr" opt; do
	case $opt in
		f) DEVFILE="${OPTARG}";;
		d) GITDIR="${OPTARG}";;
		n) DLST="${OPTARG}";;
		c) CMNT="${OPTARG}";;
		l) DOLS=1;;
		L) DOLS=2;;
		v) VERB=1;;
		r) GITPP=0;;
		p) read -s -p "DEVFILE Password: " DEVFILEPASS;;
		:) echo "Option -$OPTARG requires an argument." >&2;exit 1;;
		\?) echo "Invalid option: -$OPTARG" >&2;exit 1;;
	esac;
done;

GITDIR=`sed 's/\/$//' <<<"${GITDIR}"`;

if [ -z "${GITDIR}" ] && [ ! -z "${MY_GIT_BACKUP_DIR}" ]; then
	GITDIR="${MY_GIT_BACKUP_DIR}";
fi;

GITDIR=`realpath "${GITDIR}" 2>/dev/null `;

echo "";

if [ "${DOLS}" -eq 0 ] && [ ! -d "${GITDIR}" ]; then
	echo "GIT folder does not exit";
else if [ ! -f "${DEVFILE}" ]; then
	echo "File not found: "${DEVFILE}"";
else
CHANGES=0;
if [ "${DOLS}" -eq 0 ] && [ "${GITPP}" -eq 1 ]; then git -C "${GITDIR}" pull; fi;

if [ "${VERB}" -eq 1 ]; then
	EXPECTAGR="-dnN -f -";
fi;

if [ ${?} -eq 0 ]; then while read L; do if [[ ${L} =~ ${R1} ]]; then
	HNUM="${BASH_REMATCH[1]}";
	HTYP="${BASH_REMATCH[2]}";
	STYP="${BASH_REMATCH[3]}";
	ATYP="${BASH_REMATCH[4]}";
	USER="${BASH_REMATCH[5]}";
	PASS="${BASH_REMATCH[6]}";
	ENBL="${BASH_REMATCH[7]}";
	HOST="${BASH_REMATCH[8]}";
	PORT="${BASH_REMATCH[9]}";
	ADTP="${BASH_REMATCH[12]}"; # additional parameter type
	ADVU="${BASH_REMATCH[13]}"; # additional parameter value

	if [ -n "${DLST}" ]; then
		if ! [[ " ${DLST} " =~ " ${HNUM} " ]]; then
			continue;
		fi;
	fi;

	if [ "${VERB}" -eq 1 ]; then
		echo -ne "\n\nHNUM: ""${HNUM}""\nHTYP: ""${HTYP}""\nSTYP: ""${STYP}""\nATYP: ""${ATYP}""\nUSER: ""${USER}""\nPASS: ""${PASS}""\nENBL: ""${ENBL}""\nHOST: ""${HOST}""\nPORT: ""${PORT}""\nADTP: ""${ADTP}""\nADVU: ""${ADVU}""\n";
	fi;

	if [ "${DOLS}" -eq 1 ]; then
		echo "${HNUM}"	"${HOST}";
		continue;
	fi;

	if [ "${DOLS}" -eq 2 ]; then
		echo "${L}";
		continue;
	fi;

	FILE=""${GITDIR}"/"${HOST}".cfg";

	SSHC="ssh ";

	RSYNCDIRS="/etc";

	RSYNCC="rsync --delete-excluded -r -a -p ";

	RSYNCSUDOC="rsync --delete-excluded --relative --rsync-path \"sudo rsync\" -r -a -p ";

	case "${ADTP}" in
		"rsyncdirs")
			RSYNCDIRS=${ADVU};
		;;
	esac;

	case "${HTYP}" in
		"linux")
			case "${STYP}" in
				"rsynclocal")
					mkdir -p "${GITDIR}"/"${HOST}"/ || exit 1;
					expc="set timeout 120\n";
					expc+="log_user 0\n";
					expc+="spawn "${RSYNCC}" -R "${RSYNCDIRS}" "${GITDIR}"/"${HOST}"/\n";
					expc+="while 1 {\n";
					expc+="expect {\n";
					expc+="\"*Could not resolve*\" { send_user 'Temporary\ failure\ in\ nameresolution'; exit 1 }\n";
					expc+="\"*assword:\" { send -- ""${PASS}""\\\r\\\n }\n";
					expc+="\"*refused*\" { send_user 'refused'; exit 1 }\n";
					expc+="\"*not known*\" { send_user 'notknown'; exit 1 }\n";
					expc+="\"*command not found*\" { send_user 'rsync\ not\ found'; exit 1 }\n";
					expc+="timeout { send_user 'timeout'; exit 1 }\n";
					expc+="eof { exit 0 }\n";
					expc+="}\n";
					expc+="}\n";
					expc+="exit 1\n";
				;;
				"rsync")
					mkdir -p "${GITDIR}"/"${HOST}"/ || exit 1;
					expc="set timeout 120\n";
					expc+="log_user 0\n";
					expc+="spawn "${RSYNCC}" "${USER}"@"${HOST}":"${RSYNCDIRS}" "${GITDIR}"/"${HOST}"/\n";
					expc+="while 1 {\n";
					expc+="expect {\n";
					expc+="\"*Could not resolve*\" { send_user 'Temporary\ failure\ in\ nameresolution'; exit 1 }\n";
					expc+="\"*assword:\" { send -- ""${PASS}""\\\r\\\n }\n";
					expc+="\"*refused*\" { send_user 'refused'; exit 1 }\n";
					expc+="\"*not known*\" { send_user 'notknown'; exit 1 }\n";
					expc+="\"*command not found*\" { send_user 'rsync\ not\ found'; exit 1 }\n";
					expc+="timeout { send_user 'timeout'; exit 1 }\n";
					expc+="eof { exit 0 }\n";
					expc+="}\n";
					expc+="}\n";
					expc+="exit 1\n";
					;;
				"rsyncsudo")
					mkdir -p "${GITDIR}"/"${HOST}"/ || exit 1;
					expc="set timeout 120\n";
					expc+="log_user 0\n";
					expc+="spawn "${RSYNCSUDOC}" "${USER}"@"${HOST}":"${RSYNCDIRS}" "${GITDIR}"/"${HOST}"/\n";
					expc+="while 1 {\n";
					expc+="expect {\n";
					expc+="\"*Could not resolve*\" { send_user 'Temporary\ failure\ in\ nameresolution'; exit 1 }\n";
					expc+="\"*assword:\" { send -- ""${PASS}""\\\r\\\n }\n";
					expc+="\"*nexpected local arg*\" { send_user 'sudo\ unexpected\ local\ arg'; exit 1 }\n";
					expc+="\"\[sudo\] *:\" { send_user 'sudo\ requires\ password'; exit 1 }\n";
					expc+="\"*refused*\" { send_user 'refused'; exit 1 }\n";
					expc+="\"*not known*\" { send_user 'notknown'; exit 1 }\n";
					expc+="\"*command not found*\" { send_user 'rsync\ not\ found'; exit 1 }\n";
					expc+="timeout { send_user 'timeout'; exit 1 }\n";
					expc+="eof { exit 0 }\n";
					expc+="}\n";
					expc+="}\n";
					expc+="exit 1\n";
					;;
				*)
					expc="send_user 'unknown'\nexit 1\n";
					;;
			esac;
			;;
		"ibmbnt")
			case "${STYP}" in
				"tel")
					expc="set timeout 3\n";
					expc+="log_user 0\n";
					expc+="spawn telnet "${HOST}" "${PORT}"\n";

					expc+="while 1 {\n";
					expc+="expect {\n";
					expc+="\"*Could not resolve*\" { send_user 'Temporary\ failure\ in\ nameresolution'; exit 1 }\n";
					expc+="\"*Enter  password:\" { send -- ""${PASS}""\\\r\\\n }\n";
					expc+="\"*refused*\" { send_user 'refused'; exit 1 }\n";
					expc+="\"*not known*\" { send_user 'notknown'; exit 1 }\n";
					expc+="\"*Password incorrect.\" { send_user 'password\ incorrect'; exit 1 }\n";
					expc+="\"*Main#\" { send -- \"cfg\\\r\\\n\"; sleep 1; break }\n";
					expc+="timeout { send_user 'timeout'; exit 1 }\n";
					expc+="eof { send_user 'eof'; exit 1 }\n";
					expc+="}\n";
					expc+="}\n";

					expc+="expect \"*Configuration#\" { send -- \"lines 0\\\r\\\n\"; sleep 1 }\n";

					expc+="expect \"*Configuration#\" { send -- \"dump\\\r\\\n\" }\n";

					expc+="log_user 1\n";

					expc+="expect \"*Configuration#\" { log_user 0; send -- \"exit\\\r\\\n\"; exit 0 }\n";

					expc+="log_user 0\n";
					expc+="exit 1\n";
					;;
				*)
					expc="send_user 'unknown'\nexit 1\n";
					;;
			esac;
			;;
		"cisco")
			case "${STYP}" in
				"ssh")
					expc="set timeout 12\n";
					expc+="log_user 0\n";
					expc+="spawn "${SSHC}" "${USER}"@"${HOST}"\n";
					expc+="while 1 {\n";
					expc+="expect {\n";
					expc+="\"*assword:\" { send -- \"""${PASS}""\\\r\\\n\" }\n";
					expc+="\"*>\" { send -- \"enable\n\";\sleep 1;\n";
					expc+="while 1 {\n";
					expc+="expect \"*assword:\" { send -- \"""${ENBL}""\n\"; sleep 1;break }\n";
					expc+="expect \"*denied*\" { send_user 'denied'; exit 1 }\n";
					expc+="}\n";
					expc+="}\n";
					expc+="\"*#\" { send -- \"terminal length 0\\\r\\\n\"; sleep 1; break }\n";
					expc+="\"*denied*\" { send_user 'denied'; exit 1 }\n";
					expc+="\"*refused*\" { send_user 'refused'; exit 1 }\n";
					expc+="\"*not known*\" { send_user 'notknown'; exit 1 }\n";
					expc+="timeout { send_user 'timeout'; exit 1 }\n";
					expc+="eof { send_user 'eof'; exit 1 }\n";
					expc+="}\n";
					expc+="}\n";
					expc+="log_user 1\n";
					expc+="expect \"*#\" { send -- \"show running-config view full\\\r\\\n\"; sleep 1;\n";
					expc+="expect \"*nvalid input*\" { send -- \"show running-config\\\r\\\n\" }\n";
					expc+="expect # { send -- \"exit\\\r\\\n\"; exit 0 }\n";
					expc+="}\n";
					expc+="log_user 0\n";
					expc+="exit 1\n";
					;;
				"tel")
					expc="set timeout 3\n";
					expc+="log_user 0\n";
					expc+="spawn telnet "${HOST}"\n";
					expc+="while 1 {\n";
					expc+="expect {\n";
					expc+="\"*sername:\" { send -- ""${USER}""\\\r }\n";
					expc+="\"*assword:\" { send -- ""${PASS}""\\\r }\n";
					expc+="\"*denied*\" { send_user 'denied'; exit 1 }\n";
					expc+="\"*failed*\" { send_user 'denied'; exit 1 }\n";
					expc+="\"*refused*\" { send_user 'refused'; exit 1 }\n";
					expc+="\"*not known*\" { send_user 'notknown'; exit 1 }\n";
					expc+="\"*>\" { send_user 'permission'; exit 1 }\n";
					expc+="\"*#\" { send -- \"terminal length 0\\\r\"; break }\n";
					expc+="timeout { send_user 'timeout'; exit 1 }\n";
					expc+="}\n";
					expc+="}\n";
					expc+="log_user 1\n";
					expc+="expect \"*#\" { send -- \"show running-config view full\\\r\" }\n";
					expc+="expect \"*nvalid input*\" { send -- \"show running-config\\\r\" }\n";
					expc+="expect # { send -- \"exit\\\r\"; exit 0 }\n";
					expc+="log_user 0\n";
					expc+="exit 1\n";
					;;
				*)
					expc="send_user 'unknown'\nexit 1\n";
					;;
			esac;
			;;
		*)
			expc="send_user 'unknown'\nexit 1\n";
			;;
	esac;

	size=0;
	outex=$(echo -e "${expc}" | ${EXPECT} ${EXPECTAGR});

	if [ ${?} -eq 0 ]; then
		case "${HTYP}" in
			"linux")
				case "${STYP}" in
					"rsync" | "rsyncsudo" | "rsynclocal")
						size=$(du -bs "${GITDIR}"/"${HOST}" | cut -f 1);
						if [ ${size} -ge 5000 ]; then
							echo "OK: "${HOST}"";
							git -C "${GITDIR}" add "${HOST}";
							CHANGES=1;
						else
							echo "ERROR: "${HOST}" status: size: "${size}"";
							RS=1;
						fi;
						;;
				esac;
				;;
			*)
				echo  "${outex}" | sed -n '/!/,/^end/p' | egrep -v "ntp clock-period" > "${FILE}";
				size=$(wc -c <"${FILE}");
				if [ ${size} -ge 3100 ]; then
					echo "OK: "${HOST}"";
					git -C "${GITDIR}" add "${FILE}";
					CHANGES=1;
				else
					echo "ERROR: "${HOST}" status: size: "${size}"";
					RS=1;
				fi;
				;;
		esac;
	else
		echo "ERROR: "${HOST}" status: "${outex}"";
		RS=1;
	fi;
else
	echo "ERROR: Wrong device's string: "${L}""
	RS=1;
fi;
done < <((\
if [ -z "${DEVFILEPASS}" ]; then \
	cat "${DEVFILE}"; \
else \
	"${OPENSSL}" enc -in "${DEVFILE}" ${OPENSSL_OPT} -d -pass pass:"${DEVFILEPASS}"; \
fi;) | egrep -v "^( +)?#.*$|^$" | sort -u | sort -t@ -n);
if [ ${CHANGES} -eq 1 ]; then
	git -C "${GITDIR}" commit -m "$(hostname).$(dnsdomainname) $(date +%Y-%m-%d_%H.%M.%S) ${CMNT}" && \
		if [ "${GITPP}" -eq 1 ]; then git -C "${GITDIR}" push; fi;
fi;
fi;
fi;
fi;

exit ${RS};
