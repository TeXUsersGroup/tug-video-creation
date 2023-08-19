#!/bin/bash
while IFS="," read  -r slug mainfile logopos timein timeout
do
	echo "SLUG=$slug, MAINFILE=$mainfile, TIMEIN=$timein, TIMEOUT=$timeout"
	if [ -n "$slug" ] && [ -n "$timein" ] && [ -n "$timeout" ] ; then
		echo '#!/bin/bash' > $slug.sh
		echo 'set -u' >> $slug.sh
		echo "SLUG=$slug" >> $slug.sh
		echo "MAINFILE=../Zoom-TUG-2021/$mainfile" >> $slug.sh
		echo "TIMEIN=$timein" >> $slug.sh
		echo "TIMEOUT=$timeout" >> $slug.sh
		echo ". scripts/doit.sh" >> $slug.sh
	fi
done < <(cut -d "," -f1,4,5,6,7 "$1" | tail -n +2)

