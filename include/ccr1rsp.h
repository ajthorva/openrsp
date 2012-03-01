      INTEGER MAXTLBL
      PARAMETER ( MAXTLBL = 500 )
      LOGICAL LORXLRT(MAXTLBL), LR1OPN
      INTEGER NLRTLBL,  ISYLRT(MAXTLBL),ISYOFT(8)
      INTEGER NLRTHFLBL,ISYLRTHF(MAXTLBL)
      CHARACTER*8 LRTLBL(MAXTLBL),LRTHFLBL(MAXTLBL)

#if defined (SYS_CRAY)
      REAL FRQLRT(MAXTLBL),XLRT(MAXTLBL)
      REAL FRQLRTHF(MAXTLBL)
#else
      DOUBLE PRECISION FRQLRT(MAXTLBL),XLRT(MAXTLBL)
      DOUBLE PRECISION FRQLRTHF(MAXTLBL)
#endif

      COMMON/ILRTRSP/ NLRTLBL,   ISYLRT, LORXLRT, ISYOFT, 
     &                NLRTHFLBL, ISYLRTHF,
     &                LR1OPN
      COMMON/CLRTRSP/ LRTLBL, LRTHFLBL
      COMMON/RLRTRSP/ FRQLRT, FRQLRTHF, XLRT

