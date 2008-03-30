#!/bin/sh
#
# /etc/init.d/smokeping
#
### BEGIN INIT INFO
# Provides:          smokeping
# Required-Start:    $syslog $network
# Should-Start:      sshd apache
# Required-Stop:     $syslog $network
# Default-Start:     2 3 4 5
# Default-Stop:      0 1 6
# Short-Description: Start or stop the smokeping latency logging system daemon
# Description:       SmokePing is a latency logging and graphing system
#                    that consists of a daemon process which organizes 
#                    the latency measurements and a CGI which presents 
#                    the graphs. This script is used to start or stop
#                    the daemon.
### END INIT INFO
# 

set -e

# Source LSB init functions
. /lib/lsb/init-functions

DAEMON=/usr/sbin/smokeping
NAME=smokeping
DESC="latency logger daemon"
CONFIG=/etc/smokeping/config
PIDFILE=/var/run/smokeping/$NAME.pid
DAEMON_USER=smokeping

# Check whether the binary is still present:
test -f "$DAEMON" || exit 0

check_config () {
    # Check whether the configuration file is available
    if [ ! -r "$CONFIG" ]
    then
        log_progress_msg "($CONFIG does not exist)"
        log_end_msg 6 
        exit 6
    fi
}

case "$1" in
    start)
    log_daemon_msg "Starting $DESC" $NAME
    check_config
    set +e
    pidofproc "$DAEMON" > /dev/null
    STATUS=$?
    set -e
    if [ "$STATUS" = 0 ]
    then
        log_progress_msg "already running"
        log_end_msg $STATUS
        exit $STATUS
    fi

    set +e
    start-stop-daemon --start --quiet --exec $DAEMON --oknodo \
                            --chuid $DAEMON_USER --pidfile $PIDFILE \
                            | logger -p daemon.notice -t $NAME
    STATUS=$?
    set -e

    log_end_msg $STATUS
    exit $STATUS
    ;;


    stop)
    log_daemon_msg "Shutting down $DESC" $NAME

    set +e
    start-stop-daemon --oknodo --stop --quiet --pidfile /var/run/smokeping/$NAME.pid --signal 15
    STATUS=$?
    set -e

    if [ "$STATUS" = 0 ]
    then
        rm -f $PIDFILE
    fi

    log_end_msg $STATUS
    exit $STATUS
    ;;


    restart)
    # Restart service (if running) or start service
    $0 stop
    $0 start
    ;;


    reload|force-reload)
    log_action_begin_msg "Reloading $DESC configuration" 

    check_config
    set +e
    $DAEMON --reload | logger -p daemon.notice -t smokeping
    STATUS=$?
    set -e

    if [ "$STATUS" = 0 ]
    then
        log_action_end_msg 0 "If the CGI has problems reloading, see README.Debian."
    else
        log_action_end_msg $STATUS
    fi
    exit $STATUS
    ;;


    status)
    log_daemon_msg "Checking $DESC status" $NAME
    # Use pidofproc to check the status of the service,
    # pidofproc returns the exit status code of 0 when it the process is
    # running.

    # LSB defined exit status codes for status:
    # 0    program is running or service is OK
    # 1    program is dead and /var/run pid file exists
    # 2    program is dead and /var/lock lock file exists
    # 3    program is not running
    # 4    program or service status is unknown
    # 5-199    reserved (5-99 LSB, 100-149 distribution, 150-199 applications)
    
    set +e
    pidofproc "$DAEMON" > /dev/null
    STATUS=$?
    log_progress_msg "(status $STATUS)"
    log_end_msg 0
    set -e
    exit $STATUS
    ;;


    *)
    echo "Usage: $0 {start|stop|status|restart|force-reload|reload}"
    exit 1
    ;;
esac
