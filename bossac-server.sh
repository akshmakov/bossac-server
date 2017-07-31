#!/bin/bash
#
# Author: Andrey Shmakov
#
# https://github.com/akshmakov/serialport-server
#
# Simple bossac-based atmel programming server using socat
#



#####################################################################
##################### Function Defs Global Vars #####################
#####################################################################

PROGNAME=$(basename $0)
INVOKE_TS=$(date +"%s")

function error_exit
{
    #----------------------------------------------------------------
    # Function for exit due to fatal program error
    # Accepts 1 argument:
    # string containing descriptive error message
    #----------------------------------------------------------------
    echo "${PROGNAME}: ${1-\"Unknown Error\"}" 1>&2
    exit ${2-1}
}

function usage
{
            cat <<EOF
    Usage: $PROGNAME [OPTIONS] device
	    options:

            {SERVER}
	    -p/--port <PORT>         : exposed TCP Port 
                                       (default = 2000)

	    -l/--logfile <FNAME>     : save output to file
	    -h/--help                : print this usage help
	    -d/--daemon              : daemonize (background)
	    -v/--verbose             : more (debug)
            -R/--server-root         : Server Root (var files)
                                       (default = /var/opt/bossac-server/)

            -b/--bins-dir <DIR>      : directory where bins are stored 
                                       (default = /var/opt/bossac-server/bins)

            {BOSSAC TUNING}
            --bossac-device <DEVICE> : alternative way to specify device 
            --bossac-bin <BOSSACEXE> : path or name of bossac executable
                                       (default = bossac)

            --bossac-usb true/false  : force usb device
                                       (default = true)

            --bossac-info <STRING>   : arguments passed to bossac under command INFO 
                                       (default = "--info")

            --bossac-write <STRING>  : arguments passed to bossac under command WRITE
                                       (default = "-i -e -R -w -v")

            --bossac-read <STRING>   : arguments passed to bossac under command READ
                                       (default = "-i -r")


	    device: local socket or device intended for programmer
                     use (e.g. defualt is /dev/ttyUSB0)

	    The following Environment Variables can be used in lieu of args
            
 
            SERVER_PORT    - -p/--p
            SERVER_BINS_DIR- -b/--bins-dir
            SERVER_VERBOSE - -v/--verbose
            SERVER_LOGFILE - -l/--logfile
            SERVER_ROOT    - -R/--server-root
            SERVER_DAEMON  - -d/--daemon
        

            BOSSAC_DEVICE  - device\--bossac-device
            BOSSAC_BIN     - --bossac-bin
            BOSSAC_USB     - --bossac-usb
            BOSSAC_INFO    - --bossac-info
            BOSSAC_READ    - --bossac-read
            BOSSAC_WRITE   - --bossac-write


            ---------------------------
            SERVER API V1 DOCUMENTATION
            ---------------------------

            (W)RITE <FILEN>  - write local file to device
            (R)EAD  <FILEN>  - read device to local file

            (L)IST           - list avaialble bins
            (I)NFO           - Connected Device Info

            \\not-yet-implemented
            \\ WRITES        - write stdin stream to device (for piping)
            \\ READS         - read device to stdout  (for piping)

            === EXAMPLES ===
            
            start default server for ACM0:
            $PROGNAME /dev/ttyACM0  

            start server on alt port:
            $PROGNAME -p 2002 /dev/ttyACM0 

            start server with tftp as bin dir: 
            $PROGNAME --bins-dir /srv/tftp /dev/ttyACM0 

            environment config
            SERVER_PORT=2002 BOSSAC_DEVICE=/dev/ttyACM0 $PROGNAME

EOF
	    exit 0

}


#####################################################################
##################### Env Configurable  Vars    #####################
#####################################################################


#Configurable Vars
SERVER_PORT=${SERVER_PORT-2000}

SERVER_DAEMON=${SERVER_DAEMON-}

SERVER_VERBOSE=${SERVER_VERBOSE-}

SERVER_LOGFILE=${SERVER_LOGFILE-}

SERVER_ROOT=${SERVER_ROOT-/var/opt/bossac-server}

## files to write/read
SERVER_BINS_DIR=${SERVER_BINS_DIR-"$SERVER_ROOT/bins"}


## Binary for bossac
BOSSAC_BIN=${BOSSAC_BIN-"bossac"}

## Device file
BOSSAC_DEVICE=${BOSSAC_DEVICE-}

## USB Force
BOSSAC_USB=${BOSSAC_USB-"true"}

## Write command flags
BOSSAC_WRITE=${BOSSAC_WRITE-"-i -d -e -R -w -v "}

## info command
BOSSAC_INFO=${BOSSAC_INFO-"--info"}

## Read command Flags
BOSSAC_READ=${BOSSAC_READ-"-i -d -r "}




#####################################################################
##################### Options Processing        #####################
#####################################################################

if [[ $# = 0 && -z $BOSSAC_DEVICE ]]; then
    usage
    error_exit "Should Not Get Here"
fi
    
   
   

while [[ $# -gt 0 ]]
do
    key="$1"


    case $key in
	-p|--port)
	    SERVER_PORT=$2
	    shift
	    shift
	    ;;
	-h|--help)
	    usage
	    error_exit "Should Not Get Here"
	    ;;
	-l|--logfile)
	    SERVER_LOGFILE=$2
	    shift
	    shift
	    ;;
	-R|--server-root)
	    SERVER_ROOT=$2
	    shift
	    shift
	    ;;
	-d|--daemon)
	    SERVER_DAEMON=TRUE
	    shift
	    ;;
	-v|--verbose)
	    SERVER_VERBOSE=TRUE
	    shift
	    ;;
	-b|--bins-dir)
	    SERVER_BINS_DIR=$2
	    shift
	    shift
	    ;;
	--bossac-bin)
	    BOSSAC_BIN=$2
	    shift
	    shift
	    ;;
	--bossac-device)
	    BOSSAC_DEVICE=$2
	    shift
	    shift
	    ;;
	--bossac-usb)
	    BOSSAC_USB=$2
	    shift
	    shift
	    ;;
	--bossac-write)
	    BOSSAC_WRITE=$2
	    shift
	    shift
	    ;;
	--bossac-info)
	    BOSSAC_INFO=$2
	    shift
	    shift
	    ;;
	--bossac-read)
	    BOSSAC_READ=$2
	    shift
	    shift
	    ;;
	-*|--*)
	    # unknown option
	    error_exit "Unknown Option $1"
	    ;;
	*)
	    break
	    ;;
    esac
done


## All options have "-" or "--"
## First string after options is our device
if [[ -n $1 ]]; then
    BOSSAC_DEVICE=$1
elif [[ -z $BOSSAC_DEVICE ]]; then
    error_exit "You need to specify a device"
fi


### setup verbose mode
# Nifty Trick found on SO
# You can write your own verbose only
# log string by repacing your
# echo "text string here"
# with
# echo "text string here" >&3
# for stdout (verbose)
# and >&4 for stderr (verbose)
###
if [ ! -z $SERVER_VERBOSE ]; then
    exec 4>&2 3>&1
else
    exec 4>/dev/null 3>/dev/null
fi



##debug msg
cat <<EOF >&3
--server--
External Port : $SERVER_PORT
Host Device   : $BOSSAC_DEVICE
Log File      : ${SERVER_LOGFILE-NONE}
Server vars   : $SERVER_ROOT
Bins Dir      : $SERVER_BINS_DIR
Daemon        : `if [ -z $SERVER_DAEMON ]; then echo "no"; else echo "yes"; fi`
--bossac--
Device        : $BOSSAC_DEVICE
USB           : $BOSSAC_USB
bossac-exe    : $BOSSAC_BIN
Write Command : $BOSSAC_WRITE
Read Command  : $BOSSAC_READ
Info Command  : $BOSSAC_INFO
EOF


#####################################################################
##################### bossac wrapper heredoc    #####################
#####################################################################

#Derived Var
BOSSAC_EXEC="$BOSSAC_BIN --port=$BOSSAC_DEVICE --usb-port=$BOSSAC_USB"

mkdir -p $SERVER_ROOT
mkdir -p $SERVER_BINS_DIR

## heredoc bossac wrapper
cat <<EOF > $SERVER_ROOT/wrapper
#!/bin/bash
# Temporary Wrapper for bossac-server

function exec_bossac_write {
    local FILE=\${1-"latestw.bin"}
    $BOSSAC_EXEC $BOSSAC_WRITE $SERVER_BINS_DIR/\$FILE    
    cp $SERVER_BINS_DIR/\$FILE $SERVER_BINS_DIR/latestw.bin
}

function exec_bossac_info {
    $BOSSAC_EXEC $BOSSAC_INFO
}

function exec_bossac_read {
    local FILE=\${1-"latestr.bin"}
    $BOSSAC_EXEC $BOSSAC_READ $SERVER_BINS_DIR/\$FILE
    cp $SERVER_BINS_DIR/\$FILE $SERVER_BINS_DIR/latestr.bin
}

function exec_list_bins {
    find $SERVER_BINS_DIR -type f -printf "%f\n"
}

function exec_usage {
    cat <<EOG
BOSSAC SERVER - command list

WRITE <FILE>  - write file to device
READ  <FILE>  - read device to file
LIST          - list avaialble bins
INFO          - Connected Device Info
EOG
}


read CMD ARGS  

case \${CMD,,} in
    w|write)
	exec_bossac_write \$ARGS
	PID=$!
	;;    
    l|list)
	exec_list_bins
	PID=$!
	;;
    i|info)
	exec_bossac_info
	PID=$!
	;;
    r|read)
	exec_bossac_read \$ARGS
	PID=$!
	;;
    h|help|*)
	exec_usage
	PID=$!
	;;
    
esac

exit 0
EOF


chmod 750 $SERVER_ROOT/wrapper

#####################################################################
##################### socat server   ################################
#####################################################################

SOCAT_BIN=socat
SOCAT_OPTS="-v"

SOCAT_1_TARGET="tcp4-listen:$SERVER_PORT"
SOCAT_1_OPTS=",reuseaddr,fork,ignoreeof"

SOCAT_2_TARGET="SYSTEM:$SERVER_ROOT/wrapper"
SOCAT_2_OPTS=""


if [ -n $VERBOSE ]; then
    SOCAT_OPTS="-d -d -v"
fi

SOCAT_INVOCATION="$SOCAT_BIN $SOCAT_OPTS \
   $SOCAT_1_TARGET$SOCAT_1_OPTS \
   $SOCAT_2_TARGET$SOCAT_2_OPTS"


echo $SOCAT_INVOCATION >&3


if [ -z $LOGFILE]; then
    $SOCAT_INVOCATION
else
    $SOCAT_INVOCATION 2>&1 > $LOGFILE
fi

#socat -d -d -v tcp4-listen:2000,reuseaddr,fork,ignoreeof SYSTEM:"$SERVER_ROOT/wrapper"



#####################################################################
##################### cleanup        ################################
#####################################################################


rm $SERVER_ROOT//wrapper
