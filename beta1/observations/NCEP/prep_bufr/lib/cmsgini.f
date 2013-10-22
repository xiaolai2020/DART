      SUBROUTINE CMSGINI(LUN,MESG,SUBSET,IDATE,NSUB,NBYT)

C$$$  SUBPROGRAM DOCUMENTATION BLOCK
C
C SUBPROGRAM:    CMSGINI
C   PRGMMR: WOOLLEN          ORG: NP20       DATE: 2002-05-14
C
C ABSTRACT: THIS SUBROUTINE INITIALIZES A NEW BUFR MESSAGE FOR OUTPUT
C   IN COMPRESSED BUFR.  THE ACTUAL LENGTH OF SECTION 4 (CONTAINING
C   COMPRESSED DATA) IS ALREADY KNOWN.
C
C PROGRAM HISTORY LOG:
C 2002-05-14  J. WOOLLEN -- ORIGINAL AUTHOR
C 2003-11-04  S. BENDER  -- ADDED REMARKS/BUFRLIB ROUTINE
C                           INTERDEPENDENCIES
C 2003-11-04  D. KEYSER  -- UNIFIED/PORTABLE FOR WRF; ADDED
C                           DOCUMENTATION (INCLUDING HISTORY); OUTPUTS
C                           MORE COMPLETE DIAGNOSTIC INFO WHEN ROUTINE
C                           TERMINATES ABNORMALLY; LEN3 INITIALIZED AS
C                           ZERO (BEFORE WAS UNDEFINED WHEN FIRST
C                           REFERENCED)
C 2004-08-18  J. ATOR    -- ADDED COMMON /MSGSTD/ AND OTHER LOGIC TO
C                           ALLOW OPTION OF CREATING A SECTION 3 THAT IS
C                           FULLY WMO-STANDARD; IMPROVED DOCUMENTATION;
C                           MAXIMUM MESSAGE LENGTH INCREASED FROM
C                           20,000 TO 50,000 BYTES
C 2005-11-29  J. ATOR    -- CHANGED DEFAULT MASTER TABLE VERSION TO 12
C DART $Id$
C
C USAGE:    CALL CMSGINI (LUN, MESG, SUBSET, IDATE, NSUB, NBYT)
C   INPUT ARGUMENT LIST:
C     LUN      - INTEGER: I/O STREAM INDEX INTO INTERNAL MEMORY ARRAYS
C     SUBSET   - CHARACTER*8: TABLE A MNEMONIC FOR TYPE OF BUFR MESSAGE
C                BEING WRITTEN 
C     IDATE    - INTEGER: DATE-TIME STORED WITHIN SECTION 1 OF BUFR
C                MESSAGE BEING WRITTEN, IN FORMAT OF EITHER YYMMDDHH OR
C                YYYYMMDDHH, DEPENDING ON DATELEN() VALUE
C     NSUB     - INTEGER: NUMBER OF SUBSETS, STORED IN SECTION 3 OF
C                BUFR MESSAGE BEING WRITTEN
C     NBYT     - INTEGER: ACTUAL LENGTH (IN BYTES) OF "COMPRESSED DATA
C                PORTION" OF SECTION 4 (I.E. ALL OF SECTION 4 EXCEPT
C                FOR THE FIRST FOUR BYTES)
C
C   OUTPUT ARGUMENT LIST:
C     MESG     - INTEGER: *-WORD PACKED BINARY ARRAY CONTAINING BUFR
C                MESSAGE
C     NBYT     - INTEGER: ACTUAL LENGTH OF BUFR MESSAGE (IN BYTES) UP
C                TO THE POINT IN SECTION 4 WHERE COMPRESSED DATA ARE
C                TO BE WRITTEN 
C
C REMARKS:
C    THIS ROUTINE CALLS:        BORT     I4DY     ISTDESC  NEMTAB
C                               NEMTBA   PKB      PKC      RESTD
C    THIS ROUTINE IS CALLED BY: WRCMPS
C                               Normally not called by any application
C                               programs.
C
C ATTRIBUTES:
C   LANGUAGE: FORTRAN 77
C   MACHINE:  PORTABLE TO ALL PLATFORMS
C
C$$$

      INCLUDE 'bufrlib.prm'

      COMMON /MSGSTD/ CSMF

      CHARACTER*128 BORT_STR
      CHARACTER*8   SUBSET
      CHARACTER*4   BUFR
      CHARACTER*1   TAB
      CHARACTER*1   CSMF
      DIMENSION     MESG(*)
      DIMENSION ICD(MAXNC)

      DATA BUFR/'BUFR'/

C-----------------------------------------------------------------------
C-----------------------------------------------------------------------

C  GET THE MESSAGE TAG AND TYPE, AND BREAK UP THE DATE
C  ---------------------------------------------------

c  .... Given SUBSET, NEMTBA returns MTYP,MSBT,INOD
      CALL NEMTBA(LUN,SUBSET,MTYP,MSBT,INOD)
      CALL NEMTAB(LUN,SUBSET,ISUB,TAB,IRET)
      IF(IRET.EQ.0) GOTO 900

C  DATE CAN BE YYMMDDHH OR YYYYMMDDHH
C  ----------------------------------

      JDATE = I4DY(IDATE)
      MCEN = MOD(JDATE/10**8,100)+1
      MEAR = MOD(JDATE/10**6,100)
      MMON = MOD(JDATE/10**4,100)
      MDAY = MOD(JDATE/10**2,100)
      MOUR = MOD(JDATE      ,100)
      MMIN = 0

c  .... DK: Don't think this can happen, because IDATE=0 is returned
c           as 2000000000 by I4DY meaning MCEN would be 21
      IF(MCEN.EQ.1) GOTO 901

      IF(MEAR.EQ.0) MCEN = MCEN-1
      IF(MEAR.EQ.0) MEAR = 100

C  INITIALIZE THE MESSAGE
C  ----------------------

      MBIT = 0

C  SECTION 0
C  ---------

      CALL PKC(BUFR ,  4 , MESG,MBIT)

C     NOTE THAT THE ACTUAL SECTION 0 LENGTH WILL BE COMPUTED AND
C     STORED BELOW; FOR NOW, WE ARE REALLY ONLY INTERESTED IN
C     ADVANCING MBIT BY THE CORRECT AMOUNT, SO WE'LL JUST STORE
C     A DEFAULT VALUE OF 0.

      CALL PKB(   0 , 24 , MESG,MBIT)
      CALL PKB(   3 ,  8 , MESG,MBIT)

C  SECTION 1
C  ---------

      CALL PKB(  18 , 24 , MESG,MBIT)
      CALL PKB(   0 ,  8 , MESG,MBIT)
      CALL PKB(   3 ,  8 , MESG,MBIT)
      CALL PKB(   7 ,  8 , MESG,MBIT)
      CALL PKB(   0 ,  8 , MESG,MBIT)
      CALL PKB(   0 ,  8 , MESG,MBIT)
      CALL PKB(MTYP ,  8 , MESG,MBIT)
      CALL PKB(MSBT ,  8 , MESG,MBIT)
      CALL PKB(  12 ,  8 , MESG,MBIT)
      CALL PKB(   0 ,  8 , MESG,MBIT)
      CALL PKB(MEAR ,  8 , MESG,MBIT)
      CALL PKB(MMON ,  8 , MESG,MBIT)
      CALL PKB(MDAY ,  8 , MESG,MBIT)
      CALL PKB(MOUR ,  8 , MESG,MBIT)
      CALL PKB(MMIN ,  8 , MESG,MBIT)
      CALL PKB(MCEN ,  8 , MESG,MBIT)

C  SECTION 3
C  ---------

C     NOTE THAT THE ACTUAL SECTION 3 LENGTH WILL BE COMPUTED AND
C     STORED BELOW; FOR NOW, WE ARE REALLY ONLY INTERESTED IN
C     ADVANCING MBIT BY THE CORRECT AMOUNT, SO WE'LL JUST STORE
C     A DEFAULT VALUE OF 0.

      CALL PKB(   0 , 24 , MESG,MBIT)
      CALL PKB(   0 ,  8 , MESG,MBIT)
      CALL PKB(NSUB , 16 , MESG,MBIT)
      CALL PKB( 192 ,  8 , MESG,MBIT)

      IF ( ( CSMF.EQ.'N' ) .OR. ( ISTDESC(ISUB).EQ.1 ) )  THEN

C         EITHER NO WMO STANDARDIZATION OF SECTION 3 WAS REQUESTED,
C         OR ELSE ISUB ALREADY HAPPENS TO BE A WMO-STANDARD DESCRIPTOR.
C         IN EITHER CASE, JUST COPY ISUB "AS IS" INTO SECTION 3.

          CALL PKB(ISUB , 16 , MESG,MBIT)
          LEN3 = 10
      ELSE

C         ISUB IS A NON-STANDARD TABLE A DESCRIPTOR THAT NEEDS TO BE
C         EXPANDED INTO AN EQUIVALENT STANDARD SEQUENCE.

          CALL RESTD(LUN,ISUB,NCD,ICD)
          DO N=1,NCD
              CALL PKB(ICD(N), 16, MESG,MBIT)
          ENDDO
          LEN3 = 8+(NCD*2)
      ENDIF

C     ZERO OUT THE FINAL BYTE OF SECTION 3.

      CALL PKB(   0 ,  8 , MESG,MBIT)

C     STORE THE TOTAL LENGTH OF SECTION 3.

C     ASSUMING THAT THERE IS NO SECTION 2, THEN IAD3 POINTS
C     TO THE BYTE IMMEDIATELY PRECEDING THE START OF SECTION 3.

      IAD3 = 8+18
      MBIT = IAD3*8
      CALL PKB(LEN3 , 24 , MESG,MBIT)

C  SECTION 4
C  ---------

      MBIT = (IAD3+LEN3)*8

C     STORE THE TOTAL LENGTH OF SECTION 4.

C     REMEMBER THAT THE INPUT VALUE OF NBYT ONLY CONTAINS THE
C     LENGTH OF THE "COMPRESSED DATA PORTION" OF SECTION 4, SO
C     WE NEED TO ADD FOUR BYTES TO THIS NUMBER IN ORDER TO
C     ACCOUNT FOR THE TOTAL LENGTH OF SECTION 4.

      CALL PKB((NBYT+4) , 24 , MESG,MBIT)
      CALL PKB(       0 ,  8 , MESG,MBIT)

C     THE ACTUAL "COMPRESSED DATA PORTION" OF SECTION 4 WILL
C     BE FILLED IN LATER BY SUBROUTINE WRCMPS.


C  SECTION 5
C  ---------

C     THIS SECTION WILL BE FILLED IN LATER BY SUBROUTINE WRCMPS.


C  RETURN WITH THE CORRECT NEW MESSAGE BYTE COUNT
C  ----------------------------------------------

C     NOW, NOTING THAT MBIT CURRENTLY POINTS TO THE LAST BIT OF
C     THE FOURTH BYTE OF SECTION 4, THEN WE HAVE:
C     (TOTAL LENGTH OF BUFR MESSAGE (IN SECTION 0)) =
C            (LENGTH OF MESSAGE UP THROUGH FOURTH BYTE OF SECTION 4)
C         +  (LENGTH OF "COMPRESSED DATA PORTION" OF SECTION 4)
C         +  (LENGTH OF SECTION 5)
      MBYT =
     .       MBIT/8
     .    +  NBYT
     .    +  4

C     NOW, MAKE NBYT POINT TO THE CURRENT LOCATION OF MBIT
C     (I.E. THE BYTE AFTER WHICH TO ACTUALLY BEGIN WRITING THE
C     COMPRESSED DATA INTO SECTION 4).

      NBYT = MBIT/8

C     NOW, STORE THE TOTAL LENGTH OF THE BUFR MESSAGE (IN SECTION 0).

      MBIT = 32
      CALL PKB(MBYT,24,MESG,MBIT)

C  EXITS
C  -----

      RETURN
900   WRITE(BORT_STR,'("BUFRLIB: CMSGINI - TABLE A MESSAGE TYPE '//
     . 'MNEMONIC ",A," NOT FOUND IN INTERNAL TABLE D ARRAYS")') SUBSET
      CALL BORT(BORT_STR)
901   CALL BORT
     . ('BUFRLIB: CMSGINI - BUFR MESSAGE DATE (IDATE) is 0000000000')
      END
