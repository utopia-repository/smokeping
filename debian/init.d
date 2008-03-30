#! /bin/sh
#
#	This is the smokeping /etc/init.d script. Modified to run with
#	smokeping by Jose Carlos Garcia Sogo <jsogo@debian.org>.
#
#		Written by Miquel van Smoorenburg <miquels@cistron.nl>.
#		Modified for Debian GNU/Linux
#		by Ian Murdock <imurdock@gnu.ai.mit.edu>.
#
# Version:	@(#)skeleton  1.8  03-Mar-1998  miquels@cistron.nl
#

PATH=/sbin:/bin:/usr/sbin:/usr/bin
DAEMON=/usr/sbin/smokeping
NAME=smokeping
DESC=smokeping

test -f $DAEMON || exit 0

set -e

case "$1" in
  start)
	echo -n "Starting $DESC: "
	start-stop-daemon --start --quiet --pidfile /var/run/smokeping/$NAME.pid \
		--name smokeping --exec $DAEMON
	echo "$NAME."
	;;
  stop)
	echo -n "Stopping $DESC: "
	start-stop-daemon --oknodo --stop --quiet --pidfile /var/run/smokeping/$NAME.pid \
	  --signal 15

	echo "$NAME."
	;;
  restart|force-reload)
	echo -n "Restarting $DESC: "
	start-stop-daemon --start --quiet --pidfile \
		/var/run/smokeping/$NAME.pid --exec $DAEMON -- --restart
	echo "$NAME."
	;;
  *)
	N=/etc/init.d/$NAME
	echo "Usage: $N {start|stop|restart|force-reload}" >&2
	exit 1
	;;
esac

exit 0
