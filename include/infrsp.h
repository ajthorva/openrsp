      LOGICAL OPTORB, INPTES, ANTTES ,AVDIA  ,TDHF,   RSPCI,  NOITRA
      LOGICAL ORBSPC, ABOCHK, TRPLET ,OLSEN  ,PHPRES, E3TEST, TRPFLG
      LOGICAL A2TEST, X2TEST, DIROIT, RSPSUP, SOPPA,  HIRPA,  SOPW4
CSPAS : 06/11-2009 AO-SOPPA included
C      LOGICAL CCPPA , AOSOP, DFT_SO, RSPECD, RSPOCD
      LOGICAL CCPPA , DFT_SO, RSPECD, RSPOCD
CKeinSPASmehr
      INTEGER MFREQ, MCFREQ
      PARAMETER ( MFREQ = 30 , MCFREQ = 30 )
#if defined (SYS_CRAY)
      REAL             THCRSP, FREQ, CFREQ, ORBSFT
#else
      DOUBLE PRECISION THCRSP, FREQ, CFREQ, ORBSFT
#endif
      INTEGER         IREFSY, IPRRSP, MAXIT,  MAXITO,
     *                NFREQ,  NCFREQ, NCREF , ISTOCK, MAXOCK, 
     *                MAXRM, LPVMAT, NACTT, NACT, IACT, JACT
      COMMON /INFRSP/ THCRSP, FREQ(MFREQ), CFREQ(MCFREQ), ORBSFT,
     *                OPTORB, INPTES, ANTTES, AVDIA,  TDHF,   RSPCI,
     *                ORBSPC, ABOCHK, TRPLET, OLSEN,  PHPRES,
     *                E3TEST, TRPFLG, A2TEST, X2TEST, DIROIT, RSPSUP,
     *                SOPPA,  IREFSY, IPRRSP, MAXIT,  MAXITO,
     *                NFREQ,  NCFREQ, NOITRA, NCREF , ISTOCK, MAXOCK, 
     *                MAXRM,  LPVMAT, NACTT,  NACT(8),IACT(8),JACT(8),
CSPAS : 06/11-2009 AO-SOPPA included
C     *                HIRPA,  SOPW4,  CCPPA , AOSOP,  DFT_SO, RSPECD,
     *                HIRPA,  SOPW4,  CCPPA , DFT_SO, RSPECD,
CKeinSPASmehr
     *                RSPOCD
