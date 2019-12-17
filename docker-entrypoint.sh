#!/bin/sh

set -e

style="padding: 20px;"
src=""
alt=""

# If the COLOR env has been set, check it has a valid value. If unset, set to
# the default value - black
if [ ! -z ${COLOR+x} ]; then
    case "$COLOR" in
        [Rr][Ee][Dd]|[Bb][Ll][Uu][Ee]|[Bb][Ll][Aa][Cc][Kk])
            COLOR=$(echo "$COLOR" | tr '[:upper:]' '[:lower:]')
            ;;
        *)
            echo Invalid value for COLOR variable: \""$COLOR"\", terminating.
            exit 0
            ;;
    esac
else
    COLOR=black
fi

# Cater for legacy version of image that required a bind mount of the host's
# /etc/hostname onto /etc/docker-hostname inside the container
if [ -s /etc/docker-hostname ]; then 
    NODE_NAME=$(cat /etc/docker-hostname)
fi

# Add 'Node Name' to static HTML page if NODE_NAME has been set
if [ ! -z ${NODE_NAME+x} ]; then
    sed -i '/<h2>Version/ i <h2>Node Name: '"$NODE_NAME"'<\/h2>' ./index.html
fi

# Create a temporary file for holding the entire image tag, which may cotain a
# base64 encoded image embedded in the src attribute
tmpfile=$(mktemp -p .)

# Construct the src and alt attributes of the img tag, and write the tag to the
# temporary file
src=$(echo "data:image/png;base64,$(base64 ./images/shipping_container_${COLOR}.png)")
alt="$(echo $COLOR)  container"
echo "<img style=\""$style"\" src=\""$src"\" alt=\""$alt"\">" > $tmpfile

# Insert the image tag into the index.html file and remove the temporary file
sed -i '/^.\+<\/title>/r '"$tmpfile"'' ./index.html
rm -rf ./${tmpfile}

# Add 'database status'-script to add the status to the static HTML page 
if [ ! -z ${DB_ENDPOINT+x} ] && [ ! -z ${DB_USER+x} ] &&  [ ! -z ${DB_PASSWORD+x} ] &&  [ ! -z ${DB_BASE+x} ] &&  [ ! -z ${DB_PORT+x} ]; then
	echo "Starting db connection script"
	# create shell script to check the db connection
	while true; do mysql -h $DB_ENDPOINT -u $DB_USER -p$DB_PASSWORD -D $DB_BASE  -P $DB_PORT -e 'quit' ; if [[ $? -eq 0 ]]; then sed -i "/<h2>Version/ i <h5>DB Connections status: `date` OK<\/h5>" /usr/local/nginx/html/index.html; sleep 30; else sed -i "/<h2>Version/ i <h5>DB Connections status: `date` FAIL<\/h5>" /usr/local/nginx/html/index.html; sleep 30; fi; done &
	sed -i "/<h2>Version/ i <h5>DB Connections status: `date` START<\/h5>" /usr/local/nginx/html/index.html;
else
	echo "Skipping db connection script because not all env variables have been set"
	env
fi

# 
# Exec what has been supplied as arguments for the container/pod
# (default: "/usr/local/nginx/sbin/nginx", "-g", "daemon off;")
exec "$@"
