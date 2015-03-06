;********************************************************************
FUNCTION percentile,image,pcts,srt=srt,hist=hist,time=time,prt=prt, $
			verbose=verbose,stp=stp,helpme=helpme
IF N_ELEMENTS(image) LT 4 THEN helpme=1

IF keyword_set(helpme) THEN BEGIN
	print,' '
	print,'* function PERCENTILE  -  returns percentile values OF image'
	print,'* calling sequence: Z=PERCENTILE(IMAGE,PCTS)'
	print,'*	 IMAGE: name OF image array'
	print,'*	 PCTS:	percentiles, def pcts(0)=0.01,pcts(1)=1.-pcts(0)'
	print,'*	 Z:	  output data values corresponding to percentiles'
	print,'* ' 
	print,'*	KEYWORDS:' 
	print,'*		 HIST: use histogram sorting (default). Fast, but potentially inaccurate' 
	print,'*		 SRT:  use SORT. Much slower'	
	print,'*		 TIME: print elapsed time FOR operation' 
	print,'*		 PRT: print output values' 
	print,'*		 VERBOSE: equivalent to /TIME, /PRT'	
	print,' '
	return,0 
ENDIF

IF N_ELEMENTS(pcts) EQ 0 THEN pcts=0.01
IF N_ELEMENTS(pcts) EQ 1 THEN pcts=[pcts,1.-pcts(0)]  ;make symmetric
npct=N_ELEMENTS(pcts)

nim=N_ELEMENTS(image)
t=systime(0)
IF keyword_set(verbose) THEN BEGIN 
	time=1
	prt=1
ENDIF

z=fltarr(npct)
IF keyword_set(verbose) THEN print,' Percentiles:',pcts
CASE 1 OF
	keyword_set(srt): BEGIN 
		IF keyword_set(verbose) THEN print,' Sort chosen' 
		k=sort(image)		
		FOR i=0,npct-1 DO BEGIN
			index = nim*pcts(i)
			IF index GE nim THEN index = nim - 1
			IF index LT 0 THEN index = 0
			z(i)=image(k(index))
		ENDFOR
	END
	ELSE: BEGIN
		IF keyword_set(verbose) THEN print,' Histogram chosen'
		k=histogram(image,min=min(image),bin=1)
		k=cumdist(k)
		FOR i=0,npct-1 DO BEGIN
			kk=WHERE(k ge nim*pcts(i),nk)
			IF nk gt 0 THEN z(i)=kk(0)+min(image) ELSE z(i)=max(image)
			ENDFOR
	END
ENDCASE

IF keyword_set(time) THEN t_elapsed,t,/prt
IF keyword_set(prt) THEN print,z
IF keyword_set(stp) THEN stop,'PERCENTILE>>>'
k=0
RETURN,z
END
