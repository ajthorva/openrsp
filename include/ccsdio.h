      INTEGER MAXSIM
      PARAMETER(MAXSIM = 540)
      LOGICAL DUMPCD
      INTEGER IT2DEL, IT2DLR
      COMMON /CCSDIO/ IT2DEL(MXCORB),
     &                DUMPCD,IT2DLR(MXCORB,MAXSIM)
