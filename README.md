# bossac-server
Remote Programming of Atmel ARM with BOSSA (https://github.com/shumatech/BOSSA)

Using command line tool `bossac` with a simple shell script based server using `socat`

The API is simple text consisting of 4 commands (READ, WRITE, INFO, LIST).

Example:

```sh
# start server
$ bossac-server /dev/ttyACM0 &
# get info from arm board (arduino due)
$ echo "info" | nc 127.0.0.1 2000
Device       : ATSAM3X8
Version      : v1.1 Dec 15 2010 19:25:04
Address      : 0x80000
Pages        : 2048
Page Size    : 256 bytes
Total Size   : 512KB
Planes       : 2
Lock Regions : 32
Locked       : none
Security     : false
Boot Flash   : false

# write "prod.bin" to device
$ echo "write prod.bin" | nc 127.0.0.1 2000
# ...
```


## Requirements

 - BASH (4)
 - bossac
 - socat

## Installing
Its a shell script, please download it


## Usage

```
Usage: bossac-server [OPTIONS] device
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

\not-yet-implemented
\ WRITES        - write stdin stream to device (for piping)
\ READS         - read device to stdout  (for piping)

=== EXAMPLES ===

start default server for ACM0:
bossac-server /dev/ttyACM0

start server on alt port:
bossac-server -p 2002 /dev/ttyACM0

start server with tftp as bin dir:
bossac-server --bins-dir /srv/tftp /dev/ttyACM0

environment config
SERVER_PORT=2002 BOSSAC_DEVICE=/dev/ttyACM0 bossac-server


```


## Usage Docker


Docker Container Images are available https://hub.docker.com/g/akshmakov/bossac-server

The following tags are provided

- `latest` `amd64` default image for standard arch
- `tftp` convenience image with tftp server serving the bossac bin directory
- `arm32v7` image for arm32v7 (e.g. Raspberry Pi 2/3)
- `arm32v7-tftp` convenience tftp server for arm32v7


The docker image maps the entrypoint of the container to bossac server, so you may interact with it
like the shell script

```sh
# print usage
$ docker run --rm akshmakov/bossac-server

# start server with port on localhost
$ docker run --rm --device "/dev/ttyACM0:/dev/ttyACM0"  -p "127.0.0.1:2000:2000"  akshmakov/bossac-server /dev/ttyACM0

# start daemon server on port 2002 (without changing bossac-server)
$ docker run -d --name bsrv --device "/dev/ttyACM0:/dev/ttyACM0" -p "2002:2000" akshmakov/bossac-server /dev/ttyACM0
#view logs
$ docker logs bsrv
#view device info
$ echo "info" | nc 127.0.0.1 2000 
```


## Usage docker compose

`docker-compose` can be used to orchestrate multiple different deployments

```docker-compose.yml
version: '2'
services:

  # server with precollected set of binaries
  bossac-1:
    extends: akshmakov/bossac-server
    image: akshmakov/bossac-server
    environment:
      BOSSAC_DEVICE: /dev/ttyACM0
      SERVER_BINS_DIR: /mnt/bins
    devices:
      - "/dev/ttyACM0:/dev/ttyACM0"
    volumes:
      - "/path/to/bins:/mnt/bins:ro"
    ports:
      - "2000:2000"

  # localhost only tftp but global control
  bossac-2:
    image: akshmakov/bossac-server:tftp
    environment:
      BOSSAC_DEVICE: /dev/ttyACM0
    devices:
      - "dev/ttyACM1:/dev/ttyACM0"
    ports:
      - "127.0.0.1:69:69"
      - "2000:2000"
    
```