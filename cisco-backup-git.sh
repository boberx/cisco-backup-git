#!/bin/bash

RS=0;

R1="^([0-9]{1,2})@([a-z]+)@([a-z]+)@([a-z]+)@([0-9a-zA-Z\.|]+)@([0-9a-zA-Z\.|#]+)@([0-9A-Za-z\.\-]+)@([0-9]+)(@([0-9A-Za-z]+))?$";

DEVFILE="";
GITDIR="";
DLST="";
CMNT="";

NC="/bin/nc";
EXPECT="/usr/bin/expect";

knock_knock_std()
{
	for p in 4895 5895 6895 7895; do
		"${NC}" -z -q 1 -i 1 -w 1 "${1}" "${p}";
	done;
}

while getopts ":d:f:n:c:" opt; do
	case $opt in
		f) DEVFILE="${OPTARG}";;
		d) GITDIR="${OPTARG}";;
		n) DLST="${OPTARG}";;
		c) CMNT="${OPTARG}";;
		:) echo "Option -$OPTARG requires an argument." >&2;;
		\?) echo "Invalid option: -$OPTARG" >&2;;
	esac;
done;

GITDIR=`sed 's/\/$//' <<<"${GITDIR}"`;
GITDIR=`realpath "${GITDIR}"`;

if [ ! -x "${EXPECT}" ] || [ ! -x "${NC}" ]; then
	echo "expect or nc not found";
else if [ ! -d "${GITDIR}" ]; then
	echo "GIT folder does not exit";
else if [ ! -f "${DEVFILE}" ]; then
	echo "File not found: "${DEVFILE}"";
else
CHANGES=0;
git -C "${GITDIR}" pull;
if [ ${?} -eq 0 ]; then while read L; do if [[ ${L} =~ ${R1} ]]; then
	HNUM="${BASH_REMATCH[1]}";
	HTYP="${BASH_REMATCH[2]}";
	STYP="${BASH_REMATCH[3]}";
	USER="${BASH_REMATCH[4]}";
	PASS="${BASH_REMATCH[5]}";
	ENBL="${BASH_REMATCH[6]}";
	HOST="${BASH_REMATCH[7]}";
	PORT="${BASH_REMATCH[8]}";
	ADON="${BASH_REMATCH[10]}";

	if [ -n "${DLST}" ]; then
		if ! [[ " ${DLST} " =~ " ${HNUM} " ]]; then
			continue;
		fi;
	fi;

	FILE=""${GITDIR}"/"${HOST}".cfg";

	SSHC="/usr/bin/ssh -4 -p ";
	SSHC+=""${PORT}" ";
	SSHC+="-oStrictHostKeyChecking=no -oPreferredAuthentications=password ";
	SSHC+="-oNumberOfPasswordPrompts=1 -oPubkeyAuthentication=no -oConnectTimeout=5 ";
	SSHC+="-oKexAlgorithms=+diffie-hellman-group1-sha1";

	# копирует файлы по симлинкам и это, похоже, никак не исправить (rsync?)
	SCPC="/usr/bin/scp -4 -r -P ";
	SCPC+=""${PORT}" ";
	SCPC+="-oStrictHostKeyChecking=no -oPreferredAuthentications=password ";
	SCPC+="-oNumberOfPasswordPrompts=1 -oPubkeyAuthentication=no -oConnectTimeout=5";

	RSYNCC="/usr/bin/rsync --delete-excluded -r -a -p -e \"ssh -p ";
	RSYNCC+=""${PORT}" ";
	RSYNCC+="-oStrictHostKeyChecking=no ";
	RSYNCC+="-oPreferredAuthentications=password,keyboard-interactive -oNumberOfPasswordPrompts=1 ";
	RSYNCC+="-oPubkeyAuthentication=no -oConnectTimeout=5\"";

	case "${HTYP}" in
		"linux")
			case "${STYP}" in
				"rsync")
					mkdir -p "${GITDIR}"/"${HOST}"/ || exit 1;
					expc="set timeout 120\n";
					expc+="log_user 0\n";
					expc+="spawn "${RSYNCC}" "${USER}"@"${HOST}":/etc/ "${GITDIR}"/"${HOST}"/etc/\n";
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
				"scp")
					mkdir -p "${GITDIR}"/"${HOST}"/ || exit 1;

					expc="set timeout 120\n";
					expc+="log_user 0\n";
					expc+="spawn "${SCPC}" -P "${PORT}" "${USER}"@"${HOST}":/etc/ "${GITDIR}"/"${HOST}"/\n";
					expc+="while 1 {\n";
					expc+="expect {\n";
					expc+="\"*Could not resolve*\" { send_user 'Temporary\ failure\ in\ nameresolution'; exit 1 }\n";
					expc+="\"*assword:\" { send -- ""${PASS}""\\\r\\\n }\n";
					expc+="\"*refused*\" { send_user 'refused'; exit 1 }\n";
					expc+="\"*not known*\" { send_user 'notknown'; exit 1 }\n";
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
		"cisco")
			case "${STYP}" in
				"ssh")
					expc="set timeout 6\n";
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

	if [ "${ADON}" == "knock" ]; then
		knock_knock_std "${HOST}";
	fi;

	size=0;
	outex=$(echo -e "${expc}" | /usr/bin/expect -nN -f -);

	if [ ${?} -eq 0 ]; then
		case "${HTYP}" in
			"linux")
				case "${STYP}" in
					"scp" | "rsync")
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
done < <(egrep -v "^( +)?#.*$|^$" "${DEVFILE}" | sort -u);
if [ ${CHANGES} -eq 1 ]; then
	git -C "${GITDIR}" commit -m "$(hostname).$(dnsdomainname) $(date +%Y-%m-%d_%H.%M.%S) ${CMNT}" && git -C "${GITDIR}" push;
fi;
fi;
fi;
fi;
fi;

exit ${RS};
