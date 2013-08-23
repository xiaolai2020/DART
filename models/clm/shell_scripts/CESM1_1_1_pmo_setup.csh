#!/bin/csh -f
#
# DART software - Copyright 2004 - 2013 UCAR. This open source software is
# provided by UCAR, "as is", without charge, subject to all terms of use at
# http://www.image.ucar.edu/DAReS/DART/DART_download
#
# DART $Id$

# ---------------------
# Purpose
# ---------------------
#
# This script is designed to set up, stage, and build a single-instance run of CESM
# using an I compset where only CLM is active and the ocean and land states are
# specified by data files. CESM is set up with a 'hybrid' start.
#
# CLM: The initial state is set by specifying the 'finidat' variable in
#      user_nl_clm. Under a hybrid start, CESM uses the REFCASE and REFDATE
#      information to construct the finidat value. This script makes an effort
#      to coordinate the staging of the file so it is consistent with CESM
#
# DATM: We are using an ensemble of data atmospheres. This requires modification of
#       the stream text files (and the stream files) for each CESM instance.
#
# DOCN: We are using a single data ocean.
#
# This script has a counterpart that is a multi-instance setup for either a free
# run or an assimilation experiment. To make it easy to maintain (and hopefully
# understand), the two scripts are intended to parallel each other. That means this
# script performs a lot of manipulation of the 'instance' portion of the
# filenames, which seems unnecessary initially.
#
# This script results in a viable setup for a CESM single instance experiment. You
# are STRONGLY encouraged to run the single instance CESM a few times and experiment
# with different settings BEFORE you try to generate 'perfect' observations.
# You should become comfortable using CESM's restart capability to re-stage files
# in your RUN directory.
#
# ${CASEROOT}/CESM_DART_config will augment the CESM case with the required setup
# and configuration to use DART to harvest synthetic observations. CESM_DART_config
# will insert a few dozen lines into the ${CASE}.run script after it makes a backup
# copy.  This, and the required setup, can be run at a later date. e.g. you can
# advance an ensemble from 2004-01-01 to 2004-02-01 and then run
# CESM_DART_config to augment the existing run script, modify STOP_N to 6 hours,
# and start harvesting synthetic observations when CESM stops at 2004-02-01 06Z ...
#
# This script relies heavily on the information in:
# http://www.cesm.ucar.edu/models/cesm1.1/cesm/doc/usersguide/book1.html
#
# ---------------------
# How to use this script.
# ---------------------
#
# -- You will have to read and understand the script in its entirety.
#    You will have to modify things outside this script.
#    This script sets up a CESM single instance run as we understand them and
#    it has almost nothing to do with DART. This is intentional.
#
# -- Edit and run this script in the $DART/models/CESM/shell_scripts directory
#    or copy it to somewhere that it will be preserved and run it there.
#    It will create a CESM 'CASE' directory, where the model will be built,
#    and an execution directory, where each forecast will
#    take place.  The short term archiver will use a third directory for
#    storage of model output until it can be moved to long term storage (HPSS)
#
# -- Examine the whole script to identify things to change for your experiments.
#
# -- Provide the CESM initial file needed by your run.
#
# -- Run this script.
#
# -- If you want to run DART; read, understand, and execute ${CASEROOT}/CESM_DART_config
#
# -- Submit the job using ${CASEROOT}/${CASE}.submit
#
# ---------------------
# Important features
# ---------------------
#
# If you want to change something in your case other than the runtime
# settings, it is safest to delete everything and start the run from scratch.
# For the brave, read
#
# http://www.cesm.ucar.edu/models/cesm1.1/cesm/doc/usersguide/x1142.html
#
# and you may be able to salvage something with
# ./cesm_setup -clean
# ./cesm_setup
# ./${case}.clean_build
# ./${case}.build
#
# ==============================================================================
# ====  Set case options
# ==============================================================================

# the value of "case" will be used many ways;
#    directory and file names, both locally and on HPSS, and
#    script names; so consider it's length and information content.

setenv case                 clm_pmo
setenv compset              I_2000_CN
setenv resolution           f09_f09
setenv cesmtag              cesm1_1_1

# ==============================================================================
# define machines and directories
#
# mach            Computer name
# cesmroot        Location of the cesm code base
#                 For cesm1_1 on yellowstone
# caseroot        Your (future) cesm case directory, where this CESM+DART will be built.
#                    Preferably not a frequently scrubbed location.
#                    This script will delete any existing caseroot, so this script,
#                    and other useful things should be kept elsewhere.
# rundir          (Future) Run-time directory; scrubbable, large amount of space needed.
# exeroot         (Future) directory for executables - scrubbable, large amount of space needed.
# archdir         (Future) Short-term archive directory
#                    until the long-term archiver moves it to permanent storage.
# dartroot        Location of _your_ DART installation
#                    This is passed on to the CESM_DART_config script.
# ==============================================================================

setenv mach         yellowstone
setenv cesmroot     /glade/p/cesm/cseg/collections/$cesmtag
setenv caseroot     /glade/p/work/${USER}/cases/${case}
setenv exeroot      /glade/scratch/${USER}/${case}/bld
setenv rundir       /glade/scratch/${USER}/${case}/run
setenv archdir      /glade/scratch/${USER}/archive/${case}
setenv dartroot     /glade/u/home/${USER}/svn/DART/trunk

# ==============================================================================
# configure settings
# ==============================================================================

setenv run_refcase 80_member_freerun_one_degree
setenv refyear     2004
setenv refmon      01
setenv refday      01
setenv run_reftod  00000
setenv run_refdate $refyear-$refmon-$refday

setenv stream_year_first 2004
setenv stream_year_last  2004
setenv stream_year_align 2004

# SingleInstanceRefcase: the filenames are fundamentally different for
#    a multi-instance CESM run or a single-instance CESM run. A correct setting
#    of this variable makes staging the required files easier - that's all.
#    1 means 'true' ... the restart file has a single-instance-like name.
#    0 means 'false' .. the restart file has a  multi-instance-like name.
#
# TRUTHinstance: specifies the specific instance you want to define as the TRUTH.
#                If you have an initial ensemble size of 80, 1<= instance <= 80.
#                If you only have one CLM state ... use 1. This value is also
#                used to specify _which_ DATM streamfile to use to force the
#                TRUTH run.
#
# CLM_stagedir: specifies the location of the CLM restart file you are defining as
#               the truth. As this state evolves in time, it will be used as the
#               input to the exact same forward observation operator code that
#               will be used during a subsequent assimilation.

setenv SingleInstanceRefcase 0
setenv TRUTHinstance 23
setenv CLM_stagedir /glade/scratch/afox/archive/$run_refcase/rest/$refyear-$refmon-$refday-$run_reftod

# ==============================================================================
# runtime settings
#
# resubmit      How many job steps to run on continue runs (will be 0 initially)
# stop_option   DART REQUIRES this to be 'nhours' ... DO NOT CHANGE
# stop_n        Specifies number of hours to advance the model in a single execution.
# assim_n       Specifies number of hours between desired observation files.
# clm_dtime     dynamical timestep (in seconds) ... 1800 is the default for CLM
# h1nsteps      is the number of time steps to put in a single .h1. file
#               DART needs to know this and the only time it is known is during
#               this configuration step. The run-time settings can lie.
#
# If the long-term archiver is off, you get a chance to examine the files before
# they get moved to long-term storage. You can always submit $CASE.l_archive
# whenever you want to free up space in the short-term archive directory.
#
# ==============================================================================

setenv short_term_archiver on
setenv long_term_archiver  off
setenv resubmit            0
setenv stop_option         nhours
setenv stop_n              72
setenv assim_n             24

# This specifies the number of time steps available to the forward obs. operator.

@ clm_dtime = 1800
@ h1nsteps = $assim_n * 3600 / $clm_dtime

# ==============================================================================
# job settings
#
# queue      can be changed during a series by changing the ${case}.run
# timewall   can be changed during a series by changing the ${case}.run
#
# TJH: Advancing 1 instance for 72 hours with 60 pes (4 nodes)
#      took less than 2 minutes on yellowstone.
# ==============================================================================

setenv ACCOUNT      P8685xxxx
setenv queue        economy
setenv timewall     0:10

# ==============================================================================
# set these standard commands based on the machine you are running on.
# ==============================================================================

set nonomatch       # suppress "rm" warnings if wildcard does not match anything

# The FORCE options are not optional.
# The VERBOSE options are useful for debugging though
# some systems don't like the -v option to any of the following
switch ("`hostname`")
   case be*:
      # NCAR "bluefire"
      set   MOVE = '/usr/local/bin/mv -fv'
      set   COPY = '/usr/local/bin/cp -fv --preserve=timestamps'
      set   LINK = '/usr/local/bin/ln -fvs'
      set REMOVE = '/usr/local/bin/rm -fr'

   breaksw
   default:
      # NERSC "hopper", NWSC "yellowstone"
      set   MOVE = '/bin/mv -fv'
      set   COPY = '/bin/cp -fv --preserve=timestamps'
      set   LINK = '/bin/ln -fvs'
      set REMOVE = '/bin/rm -fr'

   breaksw
endsw

# ==============================================================================
# Make sure the CESM directories exist.
# VAR is the shell variable name, DIR is the value
# ==============================================================================

foreach VAR ( cesmroot dartroot CLM_stagedir )
   set DIR = `eval echo \${$VAR}`
   if ( ! -d $DIR ) then
      echo "ERROR: directory '$DIR' not found"
      echo " In the setup script check the setting of: $VAR "
      exit -1
   endif
end

# ==============================================================================
# Create the case - this creates the CASEROOT directory.
#
# For list of the pre-defined cases: ./create_newcase -list
# To create a variant case, see the CESM documentation and carefully
# incorporate any needed changes into this script.
# ==============================================================================

# fatal idea to make caseroot the same dir as where this setup script is
# since the build process removes all files in the caseroot dir before
# populating it.  try to prevent shooting yourself in the foot.

if ( $caseroot == `dirname $0` ) then
   echo "ERROR: the setup script should not be located in the caseroot"
   echo "directory, because all files in the caseroot dir will be removed"
   echo "before creating the new case.  move the script to a safer place."
   exit -1
endif

echo "removing old files from ${caseroot}"
echo "removing old files from ${exeroot}"
echo "removing old files from ${rundir}"
${REMOVE} ${caseroot}
${REMOVE} ${exeroot}
${REMOVE} ${rundir}

${cesmroot}/scripts/create_newcase -case ${caseroot} -mach ${mach} \
                -res ${resolution} -compset ${compset}

if ( $status != 0 ) then
   echo "ERROR: Case could not be created."
   exit -1
endif

# ==============================================================================
# Record the DARTROOT directory and copy the DART setup script to CASEROOT.
# CESM_DART_config can be run at some later date if desired, but it presumes
# to be run from a CASEROOT directory. If CESM_DART_config does not exist locally,
# then it better exist in the expected part of the DARTROOT tree.
# ==============================================================================

if ( ! -e CESM_DART_config ) then
   ${COPY} ${dartroot}/models/clm/shell_scripts/CESM_DART_config .
endif

if (   -e CESM_DART_config ) then
   sed -e "s#BOGUS_DART_ROOT_STRING#$dartroot#" \
       -e "s#HISTORY_OUTPUT_INTERVAL#$assim_n#" < CESM_DART_config >! temp.$$
   ${MOVE} temp.$$ ${caseroot}/CESM_DART_config
   chmod 755       ${caseroot}/CESM_DART_config
else
   echo "WARNING: the script to configure for data assimilation is not available."
   echo "         CESM_DART_config should be present locally or in"
   echo "         ${dartroot}/models/CESM/shell_scripts/"
   echo "         You can stage this script later, but you must manually edit it"
   echo "         to reflect the location of the DART code tree."
endif

# ==============================================================================
# Configure the case.
# ==============================================================================

cd ${caseroot}

source ./Tools/ccsm_getenv || exit -2

@ ptile = $MAX_TASKS_PER_NODE / 2
@ nthreads = 1

# Save a copy for debug purposes
foreach FILE ( *xml )
   if ( ! -e        ${FILE}.original ) then
      ${COPY} $FILE ${FILE}.original
   endif
end

   # This is only for the purpose of debugging the code.
   @ atm_tasks = $ptile * 4
   @ lnd_tasks = $ptile * 4
   @ ice_tasks = $ptile
   @ ocn_tasks = $ptile
   @ cpl_tasks = $ptile
   @ glc_tasks = $ptile
   @ rof_tasks = $ptile * 4

# echo "task partitioning ... perhaps ... atm // ocn // lnd+ice+glc+rof"
# presently, all components run 'serially' - one after another.
echo ""
echo "ATM  gets $atm_tasks"
echo "LND  gets $lnd_tasks"
echo "ICE  gets $ice_tasks"
echo "OCN  gets $ocn_tasks"
echo "CPL  gets $cpl_tasks"
echo "GLC  gets $glc_tasks"
echo "ROF  gets $rof_tasks"
echo ""

./xmlchange NTHRDS_ATM=$nthreads,NTASKS_ATM=$atm_tasks,NINST_ATM=1
./xmlchange NTHRDS_LND=$nthreads,NTASKS_LND=$lnd_tasks,NINST_LND=1
./xmlchange NTHRDS_ICE=$nthreads,NTASKS_ICE=$ice_tasks,NINST_ICE=1
./xmlchange NTHRDS_OCN=$nthreads,NTASKS_OCN=$ocn_tasks,NINST_OCN=1
./xmlchange NTHRDS_CPL=$nthreads,NTASKS_CPL=$cpl_tasks
./xmlchange NTHRDS_GLC=$nthreads,NTASKS_GLC=$glc_tasks,NINST_GLC=1
./xmlchange NTHRDS_ROF=$nthreads,NTASKS_ROF=$rof_tasks,NINST_ROF=1
./xmlchange ROOTPE_ATM=0
./xmlchange ROOTPE_LND=0
./xmlchange ROOTPE_ICE=0
./xmlchange ROOTPE_OCN=0
./xmlchange ROOTPE_CPL=0
./xmlchange ROOTPE_GLC=0
./xmlchange ROOTPE_ROF=0

# http://www.cesm.ucar.edu/models/cesm1.1/cesm/doc/usersguide/c1158.html#run_start_stop
# "A hybrid run indicates that CESM is initialized more like a startup, but uses
# initialization datasets from a previous case. This is somewhat analogous to a
# branch run with relaxed restart constraints. A hybrid run allows users to bring
# together combinations of initial/restart files from a previous case (specified
# by $RUN_REFCASE) at a given model output date (specified by $RUN_REFDATE).
# Unlike a branch run, the starting date of a hybrid run (specified by $RUN_STARTDATE)
# can be modified relative to the reference case. In a hybrid run, the model does not
# continue in a bit-for-bit fashion with respect to the reference case. The resulting
# climate, however, should be continuous provided that no model source code or
# namelists are changed in the hybrid run. In a hybrid initialization, the ocean
# model does not start until the second ocean coupling (normally the second day),
# and the coupler does a "cold start" without a restart file."

# The RUN_REFCASE/REFDATE/REFTOD  are used by CLM & RTM to specify the namelist input
# filenames - BUT - their buildnml scripts do not use the INSTANCE, so they all specify
# the same (single) filename. This is remedied by using patched [clm,rtm].buildnml.csh
# scripts that exist in the SourceMods directory.

./xmlchange RUN_TYPE=hybrid
./xmlchange RUN_STARTDATE=$run_refdate
./xmlchange START_TOD=$run_reftod
./xmlchange RUN_REFCASE=$run_refcase
./xmlchange RUN_REFDATE=$run_refdate
./xmlchange RUN_REFTOD=$run_reftod
./xmlchange GET_REFCASE=FALSE
./xmlchange EXEROOT=${exeroot}

./xmlchange DATM_MODE=CPLHIST3HrWx
./xmlchange DATM_CPLHIST_CASE=$case
./xmlchange DATM_CPLHIST_YR_ALIGN=$refyear
./xmlchange DATM_CPLHIST_YR_START=$refyear
./xmlchange DATM_CPLHIST_YR_END=$refyear

./xmlchange CALENDAR=GREGORIAN
./xmlchange STOP_OPTION=$stop_option
./xmlchange STOP_N=$stop_n
./xmlchange CONTINUE_RUN=FALSE
./xmlchange RESUBMIT=$resubmit

./xmlchange PIO_TYPENAME=pnetcdf

# The river transport model ON is useful only when using an active ocean or
# land surface diagnostics. Setting ROF_GRID to 'null' turns off the RTM.
# so we are also turning on the CLM biogeochemistry.

./xmlchange ROF_GRID='null'
./xmlchange CLM_CONFIG_OPTS='-bgc cn'

if ($short_term_archiver == 'off') then
   ./xmlchange DOUT_S=FALSE
else
   ./xmlchange DOUT_S=TRUE
   ./xmlchange DOUT_S_ROOT=${archdir}
   ./xmlchange DOUT_S_SAVE_INT_REST_FILES=FALSE
endif
if ($long_term_archiver == 'off') then
   ./xmlchange DOUT_L_MS=FALSE
else
   ./xmlchange DOUT_L_MS=TRUE
   ./xmlchange DOUT_L_MSROOT="csm/${case}"
   ./xmlchange DOUT_L_HTAR=FALSE
endif

# level of debug output, 0=minimum, 1=normal, 2=more, 3=too much, valid values: 0,1,2,3 (integer)

./xmlchange DEBUG=FALSE
./xmlchange INFO_DBUG=0

# ==============================================================================
# Set up the case.
# This creates the EXEROOT and RUNDIR directories.
# ==============================================================================

./cesm_setup

if ( $status != 0 ) then
   echo "ERROR: Case could not be set up."
   exit -2
endif

# ==============================================================================
# Edit the run script to reflect queue and wallclock
# ==============================================================================

echo ''
echo 'Updating the run script to set wallclock and queue.'
echo ''

if ( ! -e  ${case}.run.original ) then
   ${COPY} ${case}.run ${case}.run.original
endif

source Tools/ccsm_getenv
set BATCH = `echo $BATCHSUBMIT | sed 's/ .*$//'`
switch ( $BATCH )
   case bsub*:
      # NCAR "bluefire", "yellowstone"
      set TIMEWALL=`grep BSUB ${case}.run | grep -e '-W' `
      set    QUEUE=`grep BSUB ${case}.run | grep -e '-q' `
      sed -e "s/$TIMEWALL[3]/$timewall/" \
          -e "s/ptile=[0-9][0-9]*/ptile=$ptile/" \
          -e "s/$QUEUE[3]/$queue/" < ${case}.run >! temp.$$
          ${MOVE} temp.$$ ${case}.run
          chmod 755       ${case}.run
   breaksw

   default:

   breaksw
endsw

# ==============================================================================
# Update source files.
#    Ideally, using DART would not require any modifications to the model source.
#    Until then, this script accesses sourcemods from a hardwired location.
#    If you have additional sourcemods, they will need to be merged into any DART
#    mods and put in the SourceMods subdirectory found in the 'case' directory.
# ==============================================================================

if (    -d     ~/${cesmtag}/SourceMods ) then
   ${COPY} -r  ~/${cesmtag}/SourceMods/* ${caseroot}/SourceMods/
else
   echo "ERROR - No SourceMods for this case."
   echo "ERROR - No SourceMods for this case."
   echo "DART requires modifications to several src files."
   echo "These files can be downloaded from:"
   echo "http://www.image.ucar.edu/pub/DART/CESM/DART_SourceMods_cesm1_1_1.tar"
   echo "untar these into your HOME directory - they will create a"
   echo "~/cesm_1_1_1  directory with the appropriate SourceMods structure."
   exit -4
endif

# The CESM multi-instance capability is relatively new and still has a few
# implementation bugs. These are known problems and will be fixed soon.
# this should be removed when the files are fixed:

echo "REPLACING BROKEN CESM FILES HERE - SHOULD BE REMOVED WHEN FIXED"
echo caseroot is ${caseroot}
if ( -d ~/${cesmtag} ) then

   # preserve the original version of the files
   if ( ! -e  ${caseroot}/Buildconf/clm.buildnml.csh.original ) then
      ${MOVE} ${caseroot}/Buildconf/clm.buildnml.csh \
              ${caseroot}/Buildconf/clm.buildnml.csh.original
   endif
   if ( ! -e  ${caseroot}/preview_namelists.original ) then
      ${MOVE} ${caseroot}/preview_namelists \
              ${caseroot}/preview_namelists.original
   endif

   # patch/replace the broken files
   ${COPY} ~/${cesmtag}/clm.buildnml.csh  ${caseroot}/Buildconf/.
   ${COPY} ~/${cesmtag}/preview_namelists ${caseroot}/.

endif

# ==============================================================================
# Modify namelist templates for each instance. This is a bit of a nuisance in
# that we are pulling in restart and initial files from 'all over the place'
# and each model component has a different strategy.
#
# In a hybrid run with CONTINUE_RUN = FALSE (i.e. just starting up):
#
# CLM builds its own 'finidat' value from the REFCASE variables but in CESM1_1_1
#     it does not use the instance string. There is a patch for clm.buildnml.csh
#
# All of these must later on be staged with these same filenames.
# OR - all these namelists can be changed to match whatever has been staged.
# MAKE SURE THE STAGING SECTION OF THIS SCRIPT MATCHES THESE VALUES.
# ==============================================================================

@ inst = 1
while ($inst <= 1)

   # following the CESM strategy for 'inst_string'
   set inst_string  = ''

   # ===========================================================================
   set fname = "user_nl_datm${inst_string}"
   # ===========================================================================

   echo "dtlimit = 1.5, 1.5, 1.5"                    >> $fname
   echo "fillalgo = 'nn', 'nn', 'nn'"                >> $fname
   echo "fillmask = 'nomask','nomask','nomask'"      >> $fname
   echo "mapalgo = 'bilinear','bilinear','bilinear'" >> $fname
   echo "mapmask = 'nomask','nomask','nomask'"       >> $fname
   echo "streams = 'datm.streams.txt.CPLHIST3HrWx.Solar$inst_string             $stream_year_align $stream_year_first $stream_year_last'," >> $fname
   echo "          'datm.streams.txt.CPLHIST3HrWx.Precip$inst_string            $stream_year_align $stream_year_first $stream_year_last'," >> $fname
   echo "          'datm.streams.txt.CPLHIST3HrWx.nonSolarNonPrecip$inst_string $stream_year_align $stream_year_first $stream_year_last'"  >> $fname
   echo "taxmode = 'cycle','cycle','cycle'"          >> $fname
   echo "tintalgo = 'coszen','nearest','linear'"     >> $fname
   echo "restfils = 'unset'"                         >> $fname
   echo "restfilm = 'unset'"                         >> $fname

   # ===========================================================================
   set fname = "user_nl_clm${inst_string}"
   # ===========================================================================

   # Customize the land namelists
   # The filename is built using the REFCASE/REFDATE/REFTOD information. i.e.
   # finidat = ${CLM_stagedir}/${case}.clm2${inst_string}.r.${run_refdate}-${run_reftod}.nc
   #
   # This is the time to consider how DART and CESM will interact.  If you intend
   # on assimilating flux tower observations (nominally at 30min intervals),
   # then it is required to create a .h1. file with the instantaneous flux
   # variables every 30 minutes. Despite being in a namelist, these values
   # HAVE NO EFFECT once CONTINUE_RUN = TRUE so now is the time to set these.
   #
   # See page 65 of:
   # http://www.cesm.ucar.edu/models/cesm1.1/clm/models/lnd/clm/doc/UsersGuide/clm_ug.pdf
   #
   # DART's forward observation operators for these fluxes just reads them
   # from the .h1. file rather than trying to create them from the subset of
   # CLM variables that are available in the DART state vector. We have a terrible
   # time trying to predict the .h1. filename given only current model time.
   # DART does not read the clm namelist input that has this information, and
   # since it is in a namelist - it can change during the course of a run - BUT
   # as discussed above, only the first settings are important. Tricky.
   #
   # For a HOP TEST ... hist_empty_htapes = .false.
   # For a HOP TEST ... use a default hist_fincl1
   #
   # Customize the land namelists:
   # The initial ensemble can be set by specifying the 'finidat' variable in the
   # user_nl_clm${inst_string}. A FULL pathname to the file is required. This is nice
   # for two reasons - one is that you don't need to copy the files and rename them
   # (tedious), the second is that the full pathname provides a means of tracking
   # the origin of the initial ensemble.

   echo "dtime             = $clm_dtime,"             >> $fname
   echo "hist_empty_htapes = .false.,"                >> $fname
   echo "hist_fincl1 = 'NEP',"                        >> $fname
   echo "hist_fincl2 = 'NEP','FSH','EFLX_LH_TOT_R',"  >> $fname
   echo "hist_nhtfrq = -$assim_n,1,"                  >> $fname
   echo "hist_mfilt  = 1,$h1nsteps,"                  >> $fname
   echo "hist_avgflag_pertape = 'A','A'"              >> $fname

   @ inst ++
end

# ==============================================================================
# to create custom streamfiles ...
# "To modify the contents of a stream txt file, first use preview_namelists to
#  obtain the contents of the stream txt files in CaseDocs, and then place a copy
#  of the modified stream txt file in $CASEROOT with the string user_ prepended."
# ==============================================================================

./preview_namelists

foreach FILE (CaseDocs/*streams*)
   set FNAME = $FILE:t

   switch ( ${FNAME} )
      case *presaero*:
         echo "Using default prescribed aerosol stream.txt file ${FNAME}"
         breaksw
      case *diatren*:
         echo "Using default runoff stream.txt file ${FNAME}"
         breaksw
      default:
         ${COPY} $FILE user_$FNAME
         chmod   644   user_$FNAME
         breaksw
   endsw

end

# Replace each default stream txt file with one that uses the CLM DATM
# conditions for a default year and modify the instance number.
# In a PMO setting, the stream text file 'instance' must refer to an
# existing instance in the set of available forcing files.
# The $TRUTHinstance specifies which DATM forcing file is used to
# drive the TRUTH.

foreach FNAME (user*streams*)
   set name_parse = `echo $FNAME | sed 's/\_/ /g'`
   @ filename_index = $#name_parse
   set streamname = $name_parse[$filename_index]
   set instance   = `printf %04d $TRUTHinstance`

   if (-e $dartroot/models/clm/shell_scripts/user_$streamname*template) then

      echo "Copying DART template for $FNAME and changing instance, refyear"

      ${COPY} $dartroot/models/clm/shell_scripts/user_$streamname*template $FNAME

      sed s/NINST/$instance/g   $FNAME >! out.$$
      sed s/REFYEAR/$refyear/g  out.$$ >! $FNAME
      \rm -f out.$$

   else
      echo "DIED Looking for a DART stream txt template for $FNAME"
      echo "DIED Looking for a DART stream txt template for $FNAME"
      exit -3
   endif

end

./preview_namelists

# ==============================================================================
# Stage the restarts now that the run directory exists
# THIS IS THE STAGING SECTION - MAKE SURE THIS MATCHES THE NAMELISTS.
# POP/CAM/CICE read from pointer files. The others use namelist values initially.
# ==============================================================================

cat << EndOfText >! stage_initial_cesm_files
#!/bin/sh

cd ${rundir}

echo ''
echo 'Copying the required restart file from the staging directory.'
echo 'With CONTINUE_RUN=FALSE, only a single file is required.'
echo ''

if (( $SingleInstanceRefcase ))
then
   ${COPY} ${CLM_stagedir}/${run_refcase}.clm2.r.${run_refdate}-${run_reftod}.nc .
else

   let inst=$TRUTHinstance

   inst_string=\`printf _%04d \$inst\`

   echo ''
   echo "Staging restart for instance \$inst"

   ${COPY} ${CLM_stagedir}/${run_refcase}.clm2\${inst_string}.r.${run_refdate}-${run_reftod}.nc \
                           ${run_refcase}.clm2.r.${run_refdate}-${run_reftod}.nc
fi

exit 0

EndOfText
chmod 0755 stage_initial_cesm_files

./stage_initial_cesm_files

# ==============================================================================
# build
# ==============================================================================

echo ''
echo 'Building the case'
echo ''

./${case}.build

if ( $status != 0 ) then
   echo "ERROR: Case could not be built."
   exit -5
endif

# ==============================================================================
# What to do next
# ==============================================================================

echo ""
echo "Time to check the case."
echo ""
echo "1) cd ${rundir}"
echo "   check the compatibility between the namelists and the files that were staged."
echo ""
echo "2) cd ${caseroot}"
echo "   (on yellowstone) If the ${case}.run script still contains:"
echo '   #BSUB -R "select[scratch_ok > 0]"'
echo "   around line 9, delete it."
echo ""
echo "3) configure and execute the ${caseroot}/CESM_DART_config script."
echo ""
echo "3) Verify the contents of env_run.xml and submit the CESM job:"
echo "   ./${case}.submit"
echo ""
echo "4) After the run finishes ... check the contents of the DART observation sequence file"
echo "   ${archdir}/dart/hist/obs_seq.YYYY-MM-DD-SSSSS"
echo "   to make sure there are good values in the file. (not -888888.)"
echo ""
echo "5) To extend the run in $assim_n '"$stop_option"' steps,"
echo "   change the env_run.xml variables:"
echo ""
echo "  ./xmlchange CONTINUE_RUN=TRUE"
echo "  ./xmlchange RESUBMIT=<number_of_cycles_to_run>"
echo "  ./xmlchange STOP_N=$assim_n"
echo ""

exit 0

# <next few lines under version control, do not edit>
# $URL$
# $Revision$
# $Date$

