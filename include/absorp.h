      PARAMETER ( MXFREQ=10, MXSTATES=10, MXQRF=120 )
      LOGICAL ABSORP, ABS_ALPHA, ABS_BETA, ABS_GAMMA,
     &     ABS_SHG, ABS_MCD, ABS_ANALYZE, ABS_INTERVAL,
     &     ABS_REDUCE
      INTEGER NFREQ_ALPHA,IPRABS,MAX_MACRO,MAX_MICRO, 
     &     MAX_ITORB,NEXCITED_STATES,NOPER(8),KOPER,
     &     NQRF,NFREQ_BETA_B,NFREQ_BETA_C,QRFSYM(MXQRF,3),
     &     NFREQ_BATCH,NFREQ_INTERVAL
      DOUBLE PRECISION FREQ_ALPHA(MXFREQ),DAMPING,
     &     THCLR_ABSORP,THCPP_ABSORP,
     &     EXC_ENERGY(MXSTATES,8),RESID(3,MXFREQ,3,8),
     &     FREQ_BETA_B(MXFREQ),FREQ_BETA_C(MXFREQ),QRFFRQ(MXQRF,3),
     &     FREQ_INTERVAL(3),RES_BETA(MXQRF,2)
      CHARACTER*8 LABOP(3,8),QRFLAB(MXQRF,3)
C
      COMMON /ABSORP1/ ABSORP, ABS_ALPHA, ABS_BETA, ABS_GAMMA,
     &     ABS_SHG, ABS_MCD, ABS_ANALYZE, ABS_INTERVAL,
     &     ABS_REDUCE
      COMMON /ABSORP2/ NFREQ_ALPHA,IPRABS,MAX_MACRO,MAX_MICRO, 
     &     MAX_ITORB,NEXCITED_STATES,NOPER,KOPER,
     &     NQRF,NFREQ_BETA_B,NFREQ_BETA_C,QRFSYM,
     &     NFREQ_BATCH,NFREQ_INTERVAL
      COMMON /ABSORP3/ FREQ_ALPHA,DAMPING,
     &     THCLR_ABSORP,THCPP_ABSORP,
     &     EXC_ENERGY,RESID,RES_BETA,
     &     FREQ_BETA_B,FREQ_BETA_C,QRFFRQ,FREQ_INTERVAL
      COMMON /ABSORP4/ LABOP,QRFLAB
