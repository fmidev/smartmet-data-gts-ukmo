#!/bin/sh
#
# Finnish Meteorological Institute / Mikko Rauhala (2018)
#
# SmartMet Data Ingestion Module for UKMO Global Model
#

MODEL=ukmo

# Load Configuration 
if [ -s /smartmet/cnf/data/ukmo.cnf ]; then
    . /smartmet/cnf/data/ukmo.cnf
fi

if [ -s ukmo.cnf ]; then
    . ./ukmo.cnf
fi

# Setup defaults for the configuration

if [ -z "$AREA" ]; then
    AREA=world
fi

if [ -z "$PROJECTION" ]; then
    PROJECTION=""
else 
    PROJECTION="-P $PROJECTION"
fi

while getopts  "a:dp:" flag
do
  case "$flag" in
        a) AREA=$OPTARG;;
        d) DRYRUN=1;;
        p) PROJECTION=$OPTARG;;
  esac
done

STEP=6
# Model Reference Time
RT=`date -u +%s -d '-2 hours'`
RT="$(( $RT / ($STEP * 3600) * ($STEP * 3600) ))"
RT_HOUR=`date -u -d@$RT +%H`
RT_DATE_MMDD=`date -u -d@$RT +%Y%m%d`
RT_DATE_MMDDHH=`date -u -d@$RT +%m%d%H`
RT_DATE_DDHH=`date -u -d@$RT +%d%H00`
RT_DATE_HH=`date -u -d@$RT +%Y%m%d%H`
RT_DATE_HHMM=`date -u -d@$RT +%Y%m%d%H%M`
RT_ISO=`date -u -d@$RT +%Y-%m-%dT%H:%M:%SZ`

if [ -d /smartmet ]; then
    BASE=/smartmet
else
    BASE=$HOME/smartmet
fi

IN=$BASE/data/incoming/gts/ukmo
OUT=$BASE/data/ukmo/$AREA
CNF=$BASE/run/data/ukmo_gts/cnf
EDITOR=$BASE/editor/in
TMP=$BASE/tmp/data/ukmo_${AREA}_${RT_DATE_HHMM}
LOGFILE=$BASE/logs/data/ukmo_${AREA}_${RT_HOUR}.log

OUTNAME=${RT_DATE_HHMM}_ukmo_$AREA

OUTFILE_SFC=$OUT/surface/querydata/${OUTNAME}_surface.sqd
OUTFILE_PL=$OUT/pressure/querydata/${OUTNAME}_pressure.sqd
OUTFILE_ML=$OUT/hybrid/querydata/${OUTNAME}_hybrid.sqd

# Use log file if not run interactively
if [ $TERM = "dumb" ]; then
    exec &> $LOGFILE
fi

echo "Model Reference Time: $RT_ISO"
echo "Projection: $PROJECTION"
echo "Temporary directory: $TMP"
echo "Input directory: $IN"
echo "Output directory: $OUT"
echo "Output surface level file: $(basename $OUTFILE_SFC)"
echo "Output pressure level file: $(basename $OUTFILE_PL)"

if [ -z "$DRYRUN" ]; then
    mkdir -p $OUT/{surface,pressure}/querydata
    mkdir -p $EDITOR 
    mkdir -p $TMP
fi

if [ -n "$DRYRUN" ]; then
    exit
fi

log() {
    echo "$(date -u +%H:%M:%S) $1"
}

#
# Distribute files if valid
# Globals: $TMP
# Arguments: outputfile with path
#
distribute() {
    local OUTFILE=$1
    local TMPFILE=$TMP/$(basename $OUTFILE)

    if [ -s $TMPFILE ]; then
	log "Testing: $(basename $OUTFILE)"
	if qdstat $TMPFILE; then
	    log  "Compressing: $(basename $OUTFILE)"
	    lbzip2 -k $TMPFILE
	    log "Moving: $(basename $OUTFILE) to $OUTFILE"
	    mv -f $TMPFILE $OUTFILE
	    log "Moving: $(basename $OUTFILE).bz2 to $EDITOR/"
	    mv -f $TMPFILE.bz2 $EDITOR/
	else
	    log "File $TMPFILE is not valid qd file."
	fi
    fi
}

#
# Surface Data
#
if [ ! -s $OUTFILE_SFC ]; then
    # Convert
    log "Converting surface grib files to $(basename $OUTFILE_SFC)"
    gribtoqd -d -t -L 1 \
	-p "120,UKMO Surface" $PROJECTION \
	-o $TMP/$(basename $OUTFILE_SFC) \
	$IN/*${RT_DATE_DDHH}


    # Post Process
    if [ -s $TMP/$(basename $OUTFILE_SFC) ]; then
	log "Post processing: $(basename $OUTFILE_SFC)"
        qdscript -a 49 -i $TMP/$(basename $OUTFILE_SFC) $CNF/ukmo-surface.st > $TMP/$(basename $OUTFILE_SFC).tmp
    fi

    if [ -s $TMP/$(basename $OUTFILE_SFC).tmp ]; then
	log "Creating Wind and Weather objects: $(basename $OUTFILE_SFC)"
	qdversionchange -a -g 417 -i $TMP/$(basename $OUTFILE_SFC).tmp 7 > $TMP/$(basename $OUTFILE_SFC)
    fi

    distribute $OUTFILE_SFC

fi # surface

#
# Pressure Levels
#
if [ ! -s $OUTFILE_PL ]; then
    # Convert
    log "Converting pressure grib files to $(basename $OUTFILE_PL)"
    gribtoqd -d -t -L 100  \
	-p "120,UKMO Pressure" $PROJECTION \
	-o $TMP/$(basename $OUTFILE_PL) \
	$IN/*${RT_DATE_DDHH}

    # Post Process
    if [ -s $TMP/$(basename $OUTFILE_PL) ]; then
	log "Post processing: $(basename $OUTFILE_PL)"
	mv -f $TMP/$(basename $OUTFILE_PL) $TMP/$(basename $OUTFILE_PL).tmp
    fi

    if [ -s $TMP/$(basename $OUTFILE_PL).tmp ]; then
	log "Creating Wind and Weather objects: $(basename $OUTFILE_PL)"
	qdversionchange -w 0 -i $TMP/$(basename $OUTFILE_PL).tmp 7 > $TMP/$(basename $OUTFILE_PL)
    fi

    distribute $OUTFILE_PL

fi # pressure


log "Cleaning temporary directory $TMP"
rm -f $TMP/*_ukmo_*
rmdir $TMP

