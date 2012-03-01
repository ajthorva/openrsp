      INTEGER MAXX2LBL
      PARAMETER ( MAXX2LBL = 120 )

      LOGICAL LX2OPN
      INTEGER NX2LBL, ISYOFX2

      INTEGER ISYAX2(MAXX2LBL),ISYBX2(MAXX2LBL)
      INTEGER ISYX2(MAXX2LBL,2)
      EQUIVALENCE ( ISYAX2(1),ISYX2(1,1) )
      EQUIVALENCE ( ISYBX2(1),ISYX2(1,2) )

      CHARACTER*8 LBLAX2(MAXX2LBL), LBLBX2(MAXX2LBL)
      CHARACTER*8 LBLX2(MAXX2LBL,2)
      EQUIVALENCE ( LBLAX2(1),LBLX2(1,1) )
      EQUIVALENCE ( LBLBX2(1),LBLX2(1,2) )

      LOGICAL LORXAX2(MAXX2LBL), LORXBX2(MAXX2LBL)
      LOGICAL LORXX2(MAXX2LBL,2)
      EQUIVALENCE ( LORXAX2(1),LORXX2(1,1) )
      EQUIVALENCE ( LORXBX2(1),LORXX2(1,2) )

#if defined (SYS_CRAY)
      REAL FRQAX2(MAXX2LBL), FRQBX2(MAXX2LBL)
      REAL FRQX2(MAXX2LBL,2)
#else
      DOUBLE PRECISION FRQAX2(MAXX2LBL), FRQBX2(MAXX2LBL)
      DOUBLE PRECISION FRQX2(MAXX2LBL,2)
#endif
      EQUIVALENCE ( FRQAX2(1),FRQX2(1,1) )
      EQUIVALENCE ( FRQBX2(1),FRQX2(1,2) )

      COMMON/IX2RSP/ ISYX2, NX2LBL, ISYOFX2(8), LX2OPN, LORXX2
      COMMON/CX2RSP/ LBLX2
      COMMON/RX2RSP/ FRQX2

