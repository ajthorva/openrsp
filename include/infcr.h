      PARAMETER ( MXCROP = MAXLBL, MBCRFR = MAXLBL, MCCRFR = MAXLBL,
     *            MDCRFR = MAXLBL)
      LOGICAL CRSPEC,CRTHG,CRSHG,CRKERR,CRIDRI,INVEXP,CRCAL
      LOGICAL ACROP,BCROP,CCROP,DCROP,GAMALL
      CHARACTER*8 ACRLB,BCRLB,CCRLB,DCRLB
      COMMON /INFCR/ BCRFR(MBCRFR),CCRFR(MCCRFR),DCRFR(MDCRFR),
     *               NACROP(8),NBCROP(8),NCCROP(8),NDCROP(8),
     *               ACROP(MXCROP),BCROP(MXCROP),CCROP(MXCROP),
     *               DCROP(MXCROP),
     *               CRSPEC,CRTHG,CRSHG,CRKERR,CRIDRI,INVEXP,CRCAL,
     *               IPRCR,NBCRFR,NCCRFR,NDCRFR,GAMALL
      COMMON /CHRCR/ ACRLB(8,MXCROP), BCRLB(8,MXCROP),
     *               CCRLB(8,MXCROP), DCRLB(8,MXCROP)
