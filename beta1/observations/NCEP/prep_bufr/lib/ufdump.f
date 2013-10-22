      SUBROUTINE UFDUMP(LUNIT,LUPRT)

C$$$  SUBPROGRAM DOCUMENTATION BLOCK
C
C SUBPROGRAM:    UFDUMP
C   PRGMMR: WOOLLEN          ORG: NP20       DATE: 2002-05-14
C
C ABSTRACT: THIS SUBROUTINE DUMPS A DETAILED PRINT LISTING OF THE
C   CONTENTS OF THE UNPACKED DATA SUBSET CURRENTLY RESIDING IN THE
C   INTERNAL ARRAYS ASSOCIATED WITH THE BUFR FILE IN LOGICAL UNIT LUNIT.
C   LUNIT MUST HAVE BEEN OPENED FOR INPUT VIA A PREVIOUS CALL TO BUFR
C   ARCHIVE LIBRARY SUBROUTINE OPENBF.  THE DATA SUBSET MUST HAVE BEEN
C   SUBSEQUENTLY READ INTO THE INTERNAL BUFR ARCHIVE LIBRARY ARRAYS VIA
C   A CALL TO BUFR ARCHIVE LIBRARY SUBROUTINE READMG OR READERME,
C   FOLLOWED BY A CALL TO BUFR ARCHIVE LIBRARY SUBROUTINE READSB (OR VIA
C   A SINGLE CALL TO BUFR ARCHIVE LIBRARY SUBROUTINE READNS!).  FOR A
C   PARTICULAR SUBSET, THE PRINT LISTING CONTAINS EACH MNEMONIC
C   ACCOMPANIED BY ITS CORRESPONDING DATA VALUE (INCLUDING THE ACTUAL
C   BITS THAT WERE SET FOR FLAG TABLE VALUES!) AS WELL AS OTHER USEFUL
C   IDENTIFICATION INFORMATION.  THIS SUBROUTINE IS SIMILAR TO BUFR
C   ARCHIVE LIBRARY SUBROUTINE UFBDMP EXCEPT THAT IT DOES NOT PRINT
C   POINTERS, COUNTERS AND OTHER MORE ESOTERIC INFORMATION DESCRIBING
C   THE INTERNAL SUBSET STRUCTURES.  EACH SUBROUTINE, UFBDMP AND UFDUMP,
C   IS USEFUL FOR DIFFERENT DIAGNOSTIC PURPOSES, BUT IN GENERAL UFDUMP
C   IS MORE USEFUL FOR JUST LOOKING AT THE DATA ELEMENTS.
C
C PROGRAM HISTORY LOG:
C 2002-05-14  J. WOOLLEN -- ORIGINAL AUTHOR
C 2003-11-04  J. WOOLLEN -- MODIFIED TO HANDLE PRINT OF CHARACTER
C                           VALUES GREATER THAN EIGHT BYTES
C 2003-11-04  S. BENDER  -- ADDED REMARKS/BUFRLIB ROUTINE
C                           INTERDEPENDENCIES
C 2003-11-04  D. KEYSER  -- MAXJL (MAXIMUM NUMBER OF JUMP/LINK ENTRIES)
C                           INCREASED FROM 15000 TO 16000 (WAS IN
C                           VERIFICATION VERSION); UNIFIED/PORTABLE FOR
C                           WRF; ADDED DOCUMENTATION (INCLUDING
C                           HISTORY); OUTPUTS MORE COMPLETE DIAGNOSTIC
C                           INFO WHEN ROUTINE TERMINATES ABNORMALLY
C 2004-08-18  J. ATOR    -- ADDED FUZZINESS TEST AND THRESHOLD FOR
C                           MISSING VALUE; ADDED INTERACTIVE AND
C                           SCROLLING CAPABILITY SIMILAR TO UFBDMP
C 2006-04-14  J. ATOR    -- ADD CALL TO UPFTBV FOR FLAG TABLES TO GET
C                           ACTUAL BITS THAT WERE SET TO GENERATE VALUE
C DART $Id$
C
C USAGE:    CALL UFDUMP (LUNIT, LUPRT)
C   INPUT ARGUMENT LIST:
C     LUNIT    - INTEGER: FORTRAN LOGICAL UNIT NUMBER FOR BUFR FILE
C     LUPRT    - INTEGER: FORTRAN LOGICAL UNIT NUMBER FOR PRINT OUTPUT
C                FILE
C                       0 = LUPRT is set to 06
C
C   OUTPUT FILES:
C     IF LUPRT > 0: UNIT "LUPRT" - PRINT (IF LUPRT=6, STANDARD OUTPUT)
C     IF LUPRT = 0: UNIT 06      - STANDARD OUTPUT PRINT
C
C REMARKS:
C    THIS ROUTINE WILL SCROLL THROUGH THE DATA SUBSET, TWENTY ELEMENTS
C    AT A TIME WHEN LUPRT IS INPUT AS "0".  IN THIS CASE, THE EXECUTING
C    SHELL SCRIPT SHOULD USE THE TERMINAL AS BOTH STANDARD INPUT AND
C    STANDARD OUTPUT.  INITIALLY, THE FIRST TWENTY ELEMENTS OF THE
C    CURRENT UNPACKED SUBSET WILL BE DISPLAYED ON THE TERMIMAL,
C    FOLLOWED BY THE PROMPT "(<enter> for MORE, q <enter> to QUIT)".
C    IF THE TERMINAL ENTERS ANYTHING OTHER THAN "q" FOLLOWED BY
C    "<enter>" (e.g., "<enter>"), THE NEXT TWENTY ELEMENTS WILL BE
C    DISPLAYED, AGAIN FOLLOWED BY THE SAME PROMPT.  THIS CONTINUES
C    UNTIL EITHER THE ENTIRE SUBSET HAS BEEN DISPLAYED, OR THE TERMINAL
C    ENTERS "q" FOLLOWED BY "<enter>" AFTER THE PROMPT, IN WHICH CASE
C    THIS SUBROUTINE STOPS THE SCROLL AND RETURNS TO THE CALLING
C    PROGRAM (PRESUMABLY TO READ IN THE NEXT SUBSET IN THE BUFR FILE).
C
C    THIS ROUTINE CALLS:        BORT     NEMTAB   READLC   RJUST
C                               STATUS   UPFTBV
C    THIS ROUTINE IS CALLED BY: None
C                               Normally called only by application
C                               programs.
C
C ATTRIBUTES:
C   LANGUAGE: FORTRAN 77
C   MACHINE:  PORTABLE TO ALL PLATFORMS
C
C$$$

      INCLUDE 'bufrlib.prm'

      COMMON /MSGCWD/ NMSG(NFILES),NSUB(NFILES),MSUB(NFILES),
     .                INODE(NFILES),IDATE(NFILES)
      COMMON /TABLES/ MAXTAB,NTAB,TAG(MAXJL),TYP(MAXJL),KNT(MAXJL),
     .                JUMP(MAXJL),LINK(MAXJL),JMPB(MAXJL),
     .                IBT(MAXJL),IRF(MAXJL),ISC(MAXJL),
     .                ITP(MAXJL),VALI(MAXJL),KNTI(MAXJL),
     .                ISEQ(MAXJL,2),JSEQ(MAXJL)
      COMMON /USRINT/ NVAL(NFILES),INV(MAXJL,NFILES),VAL(MAXJL,NFILES)
      COMMON /TABABD/ NTBA(0:NFILES),NTBB(0:NFILES),NTBD(0:NFILES),
     .                MTAB(MAXTBA,NFILES),IDNA(MAXTBA,NFILES,2),
     .                IDNB(MAXTBB,NFILES),IDND(MAXTBD,NFILES),
     .                TABA(MAXTBA,NFILES),TABB(MAXTBB,NFILES),
     .                TABD(MAXTBD,NFILES)

      CHARACTER*600 TABD
      CHARACTER*128 TABB
      CHARACTER*128 TABA

      CHARACTER*80 FMT
      CHARACTER*64 DESC
      CHARACTER*24 UNIT
      CHARACTER*20 LCHR
      CHARACTER*10 TAG,NEMO
      CHARACTER*6  NUMB
      CHARACTER*7  FMTF
      CHARACTER*8  CVAL,PMISS
      CHARACTER*3  TYP
      CHARACTER*1  TAB,YOU
      EQUIVALENCE  (RVAL,CVAL)
      REAL*8       VAL,RVAL,BMISS,BDIFD

      PARAMETER (MXFV=31)
      INTEGER	IFV(MXFV)

      DATA BMISS /   10E10  /
      DATA BDIFD /   5000.  /
      DATA PMISS /' MISSING'/
      DATA YOU /'Y'/

C----------------------------------------------------------------------
C----------------------------------------------------------------------

      IF(LUPRT.EQ.0) THEN
         LUOUT = 6
      ELSE
         LUOUT = LUPRT
      ENDIF

C  CHECK THE FILE STATUS AND I-NODE
C  --------------------------------

      CALL STATUS(LUNIT,LUN,IL,IM)
      IF(IL.EQ.0) GOTO 900
      IF(IL.GT.0) GOTO 901
      IF(IM.EQ.0) GOTO 902
      IF(INODE(LUN).NE.INV(1,LUN)) GOTO 903

      WRITE(LUOUT,*)
      WRITE(LUOUT,*) 'MESSAGE TYPE ',TAG(INODE(LUN))
      WRITE(LUOUT,*)

C  DUMP THE CONTENTS OF COMMON /USRINT/ FOR UNIT LUNIT
C  ---------------------------------------------------

      DO NV=1,NVAL(LUN)
      IF(LUPRT.EQ.0 .AND. MOD(NV,20).EQ.0) THEN

C  When LUPRT=0, the output will be scrolled, 20 elements at a time
C  ----------------------------------------------------------------

         PRINT*,'(<enter> for MORE, q <enter> to QUIT)'
         READ(5,'(A1)') YOU

C  If the terminal enters "q" followed by "<enter>" after the prompt
C  "(<enter> for MORE, q <enter> to QUIT)", scrolling will end and the
C  subroutine will return to the calling program
C  -------------------------------------------------------------------

         IF(YOU.EQ.'q') THEN
         PRINT*
         PRINT*,'==> You have chosen to stop the dumping of this subset'
         PRINT*
            GOTO 100
         ENDIF
      ENDIF

      NODE = INV (NV,LUN)
      NEMO = TAG (NODE)
      ITYP = ITP (NODE)
      IF(ITYP.GE.1.AND.ITYP.LE.3) THEN
         CALL NEMTAB(LUN,NEMO,IDN,TAB,N)
         NUMB = TABB(N,LUN)(1:6)
         DESC = TABB(N,LUN)(16:70)
         UNIT = TABB(N,LUN)(71:94)
         RVAL = VAL(NV,LUN)
      ENDIF
      IF(ITYP.EQ.1) THEN

C        Delayed descriptor replication factor

         FMT = '(7X,A10,2X,I6,1X,A)'
         WRITE(LUOUT,FMT) NEMO,NINT(RVAL),'REPLICATIONS'
      ELSEIF(ITYP.EQ.2) THEN

C        Other numeric value

         IF(ABS(RVAL-BMISS).LT.BDIFD) THEN

C           The value is "missing".

            FMT = '(A6,2X,A10,2X,A20,2X,A24,6X,A48)'
            WRITE(LUOUT,FMT) NUMB,NEMO,PMISS,UNIT,DESC
         ELSE
            FMT = '(A6,2X,A10,2X,F20.00,2X,A24,6X,A48)'

C           Based upon the corresponding scale factor, select an
C           appropriate format for the printing of this value. 

            WRITE(FMT(19:20),'(I2)') MAX(1,ISC(NODE))
            IF(UNIT(1:4).EQ.'FLAG') THEN

C              Print a listing of the bits corresponding to
C              this value.

               CALL UPFTBV(LUNIT,NEMO,RVAL,MXFV,IFV,NIFV)
               IF(NIFV.GT.0) THEN
                  UNIT(11:11) = '('
                  IPT = 12
                  DO II=1,NIFV
                    IF(IFV(II).LT.10) THEN
                       ISZ = 1
                    ELSE
                       ISZ = 2
                    ENDIF
                    WRITE(FMTF,'(A2,I1,A4)') '(I', ISZ, ',A1)'
                    IF((IPT+ISZ).LE.24) THEN
                       WRITE(UNIT(IPT:IPT+ISZ),FMTF) IFV(II), ','
                       IPT = IPT + ISZ + 1
                    ENDIF
                  ENDDO
                  UNIT(IPT-1:IPT-1) = ')'
               ENDIF
            ENDIF         
            WRITE(LUOUT,FMT) NUMB,NEMO,RVAL,UNIT,DESC
         ENDIF
      ELSEIF(ITYP.EQ.3) THEN

C        Character (CCITT IA5) value

         NCHR = IBT(NODE)/8
         IF(NCHR.GT.8) THEN
            CALL READLC(LUNIT,LCHR,NEMO)
         ELSE
            LCHR = CVAL
         ENDIF
         IF(ABS(RVAL-BMISS).LT.BDIFD) LCHR = PMISS
         IRET = RJUST(LCHR)
         FMT = '(A6,2X,A10,2X,A20,2X,"(",I2,")",A24,2X,A48)'
         WRITE(LUOUT,FMT) NUMB,NEMO,LCHR,NCHR,UNIT,DESC
      ENDIF
      ENDDO

      WRITE(LUOUT,3)
3     FORMAT(/' >>> END OF SUBSET <<< '/)

C  EXITS
C  -----

100   RETURN
900   CALL BORT('BUFRLIB: UFDUMP - INPUT BUFR FILE IS CLOSED, IT '//
     . 'MUST BE OPEN FOR INPUT')
901   CALL BORT('BUFRLIB: UFDUMP - INPUT BUFR FILE IS OPEN FOR '//
     . 'OUTPUT, IT MUST BE OPEN FOR INPUT')
902   CALL BORT('BUFRLIB: UFDUMP - A MESSAGE MUST BE OPEN IN INPUT '//
     . 'BUFR FILE, NONE ARE')
903   CALL BORT('BUFRLIB: UFDUMP - LOCATION OF INTERNAL TABLE FOR '//
     . 'INPUT BUFR FILE DOES NOT AGREE WITH EXPECTED LOCATION IN '//
     . 'INTERNAL SUBSET ARRAY')
      END
