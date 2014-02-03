#!/bin/sh

# Converts an OpenLDAP schema to ldif useful when importing to a cn=config
# based slapd.
# 
# usage: schema2ldif.sh sudo.schema

# TODO:
# * automatically find dependencies

: ${ldapschemadir=/usr/local/etc/openldap/schema}


set -o errexit

progname=`basename "$0"`

errx(){
	rv=$1; shift
	echo "${progname}: error: $@" >&2
	exit "$rv"
}

[ $# -eq 1 ] || errx 1 "usage: $progname file.schema"

name=`echo "$1" | sed 's|.*/||; s/\.schema$//'`
outldif="${name}.ldif"
conf=`mktemp /tmp/slap.conf.XXXXXX`
outdir=`mktemp -d /tmp/slap.d.XXXXXX`

cat <<EOF > "$conf"
include ${ldapschemadir}/core.schema
include ${ldapschemadir}/cosine.schema
include ${ldapschemadir}/inetorgperson.schema
include $1
EOF
index=`(grep '^include' "$conf" | wc -l; echo 1-f) | dc`

if ! ( slaptest -f "$conf" -F "$outdir" ); then
	rm -rf "$conf" "$outdir"
	errx 1 "slaptest" 
fi
rm "$conf"
inldif=`echo "${outdir}/cn=config/cn=schema/cn={${index}}"*".ldif"`

awk 'BEGIN{
	ignore["structuralObjectClass:"]++
	ignore["entryUUID:"]++
	ignore["creatorsName:"]++
	ignore["createTimestamp:"]++
	ignore["entryCSN:"]++
	ignore["modifiersName:"]++
	ignore["modifyTimestamp:"]++
}
/^#/{next}
ignore[$1]{next}
/^dn:/{
	sub(/{[0-9]+}/, "", $0)
	$0 = $0 ",cn=schema,cn=config"
}
/^cn:/{sub(/{[0-9]+}/, "", $0)}
{print}' "$inldif" > "$outldif" \
|| {
	rm -rf "$outdir" "$outldif"
	errx 1 "awk"
}
rm -r "$outdir"

echo "schema ldif written to: ./${outldif}"

