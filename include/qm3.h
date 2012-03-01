C --- FILE: qm3.h ---
      LOGICAL QM3LO1, QM3LO2, LOCLAS 
      LOGICAL CCMM, FIXMOM, OLDTG, ONLYOV
      LOGICAL LONUPO, LOELFD, LOSPC, LOEC3
      LOGICAL LOSHAW,REPTST,RELMOM,SLOTH
      LOGICAL LONEPAR, LTWOPAR, LEPSADD, LSIGADD
      LOGICAL SKIPNC, VDWSKP, MYITE, MYMAT, EXPON
      LOGICAL PRFQM3, INTDIR, FORQM3, REDCNT, LGSPOL, RUNQM3
      LOGICAL QMDAMP, NYQMMM, HFFLD, CCFIXF, FFIRST
C 
C ---------------------------------------------------------
C In the present implementation the MXQM3 parameter follows 
C the MXCENT_QM parameter in the mxcent.h include file. This is
C crucial for this implementation to work properly!!
C ---------------------------------------------------------
C 
      INTEGER ISUBSY,ISUBSI,MXTYP1,NSYSBG,NSYSED
      INTEGER NSISY, ISYTP, NTOTQM3, IQM3PR, ICHRGS
      INTEGER MXDIIT, NUSITE, MXQM3, MXTYPE, NCOMS
      INTEGER NTOTIN, NUALIS, NQMBAS,NMMBA1, NREPMT
      INTEGER ISIGEPS, NSIGEPS
C
      PARAMETER(NMMBA1 = 5000)
      PARAMETER(MXQM3  = 120) ! should be equal to MXCENT_QM in include/mxcent.h
      PARAMETER(MXTYPE = 20)
C
      CHARACTER MDLWRD*7
C
      LOGICAL SHAWFC(0:MXTYPE)
      LOGICAL RDFILE(0:MXTYPE), DISMOD(0:MXTYPE)
C
C     ----------------------------------------------
C     IQM3PR takes the role of the IPREAD print flag
C     used in herrdn.F!
C     ----------------------------------------------
C
#if defined (SYS_CRAY)
      REAL QM3CHG,QM3LJA,QM3LJB,ALPIMM
      REAL ALTXX,ALTXY,ALTXZ,ALTYY,ALTYZ
      REAL ALTZZ,ECLPOL,ECLVDW,ECLQM3
      REAL THDISC,ENUQM3,CHAOLD
      REAL EMMPOL,EMMVDW,EMMELC,EMM_MM,EVDWSH,PEDIP1
      REAL QMCOM, ADAMP
#else
      DOUBLE PRECISION QM3CHG,QM3LJA,QM3LJB
      DOUBLE PRECISION ALPIMM,ALTXX,ALTXY
      DOUBLE PRECISION ALTXZ,ALTYY,ALTYZ,ALTZZ
      DOUBLE PRECISION ECLPOL,ECLVDW,THDISC
      DOUBLE PRECISION ECLQM3,ENUQM3,CHAOLD
      DOUBLE PRECISION EMMPOL,EMMVDW,EMMELC,EMM_MM
      DOUBLE PRECISION EVDWSH,PEDIP1
      DOUBLE PRECISION ENSQM3,EPOQM3
      DOUBLE PRECISION QMCOM, ADAMP
#endif

      COMMON /REAQM3/ THDISC,ECLPOL,ECLVDW,ECLQM3,ENUQM3,
     *                EMMPOL,EMMVDW,EMMELC,EMM_MM,EVDWSH,
     *                PEDIP1,ENSQM3,EPOQM3,QMCOM(3),ADAMP

      COMMON /LOGQM3/ RDFILE,DISMOD,QM3LO1,QM3LO2,CCMM,FIXMOM,
     *                OLDTG,ONLYOV,LONUPO,LOELFD,LOSPC,LOEC3,NYQMMM,
     *                SHAWFC,LOSHAW,REPTST,RELMOM,SLOTH,HFFLD,CCFIXF,
     *                LONEPAR,LTWOPAR,LEPSADD,LSIGADD,LOCLAS,
     *                SKIPNC,VDWSKP,MYITE,MYMAT,EXPON,PRFQM3,FFIRST,
     *                INTDIR, FORQM3, REDCNT, RUNQM3, LGSPOL,QMDAMP

      COMMON /INTQM3/ IQM3PR,ISYTP,NTOTQM3,NUSITE,NCOMS,NTOTIN,
     *                MXDIIT, NQMBAS, NREPMT, NSIGEPS

      COMMON /QM3WRD/ MDLWRD(0:MXTYPE)

      COMMON /QM3GNR/ ISUBSY(MXQM3),ISUBSI(MXQM3),
     *                NSYSBG(0:MXTYPE),NSYSED(0:MXTYPE),
     *                NSISY(0:MXTYPE),
     *                ICHRGS(0:MXTYPE),NUALIS(0:MXTYPE),
     *                ISIGEPS(0:MXTYPE)

      COMMON /QM3SYS/ QM3CHG(0:MXTYPE,MXQM3),
     *                QM3LJA(0:MXTYPE,0:MXTYPE),
     *                QM3LJB(0:MXTYPE,0:MXTYPE),
     *                ALPIMM(0:MXTYPE,MXQM3),CHAOLD(MXQM3),
     *                ALTXX(0:MXTYPE),ALTXY(0:MXTYPE),
     *                ALTXZ(0:MXTYPE),ALTYY(0:MXTYPE),
     *                ALTYZ(0:MXTYPE),ALTZZ(0:MXTYPE)
C --- end of qm3.h ---
