#!/bin/sh

aliasuser="${aliasuser:-alias}"
aliasdir="${aliasdir:-/var/qmail/alias}"
identity="${identity:-${aliasdir}/.ssh/id_qmail_ssh_relay}"
receiveuser="${receiveuser:-ssh-mail-relay}"

if [ X"$1" = X"" ] ; then
    echo "please specify mail receive host."
    exit 1
fi
receivehost="$1"

if ! pw usershow ${aliasuser} ; then
    echo "user ${aliasuser} not found, install qmail."
    exit 1
fi

if [ ! -d "${aliasdir}" ] ; then
    echo "no ${aliasdir}, install qmail."
    exit 1
fi

if [ ! -d "${aliasdir}/.ssh" ] ; then
    mkdir -m 700 "${aliasdir}/.ssh"
    chown "${aliasuser}" "${aliasdir}/.ssh"
else
    if [ `stat -f "%Su" "${aliasdir}/.ssh"` != "${aliasuser}" ] ; then
	echo "${aliasdir}/.ssh owner is not ${aliasuser}"
	exit 1
    fi
fi

if [ ! -f "${identity}" ] ; then
    su -m ${aliasuser} -c "ssh-keygen -f \"${identity}\" -N '' -C qmail-ssh-relay"
else
    echo "${identity} already exists."
fi

echo "adding known_hosts..."
su -m ${aliasuser} -c "/usr/bin/ssh -i \"${identity}\" -o \"UserKnownHostsFile=${aliasdir}/.ssh/known_hosts\" -o StrictHostKeyChecking=no \"${receiveuser}@${receivehost}\" true"
cat "${aliasdir}/.ssh/known_hosts"

echo "|/usr/bin/ssh -i \"${identity}\" -o \"UserKnownHostsFile=${aliasdir}/.ssh/known_hosts\" \"${receiveuser}@${receivehost}\" || exit 111" >> ${aliasdir}/.qmail-root
echo ""
echo "${aliasdir}/.qmail-root is now,"
cat "${aliasdir}/.qmail-root"

echo ""
echo "append below to ~${receiveuser}/.ssh/authorized_keys on ${receivehost}"
echo ""
echo -n 'from="'`hostname`'",command="/usr/sbin/sendmail root" '
cat "${identity}.pub"
