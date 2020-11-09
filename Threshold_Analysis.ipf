#pragma rtGlobals=3		// Use modern global access method and strict wave access.

// 9-15-20 This is a threshold analysis built to reanalyze waves where other threshold detection methods falsely
// demarcate threshold as the location where a slow somatic voltage acceleration occurs
// third derivatives of those waveforms likely show two peaks in close proximity, the first being
// "true" threshold, the second being the transition/activation of somatic sodium channels.


// 9-18-20 to do's
// add a function to "blank" 0s -> NaNs
// consider how to redo other AP analyses that were dependent on a threshold measure

Menu "Threshold Analysis"
	"In-Depth Threshold Analysis", ThresholdAccurate(0,0)
	"Threshold Analysis - Mini", ThresholdAccurate(0,1)
end


Function ThresholdAccurate(DetectionThreshold, mode)		// Detection threshold for spikes,
	Variable DetectionThreshold, mode							// Guimode 1- mini version, 0 (or anything else) - regular
	Variable /G populate
	Variable /G wavestart, waveend, activerheonum, windowstart=1, windowend=10, maxrheo
	Variable /G displaymode = 0, GUImode = mode
	Variable /G cursorstartloc =5
	
	
	String  ListOfTraceNames = TraceNameList ("", ";",1)
	Variable TraceCount = ItemsInList(ListOfTraceNames)
	String WavePrefix = "ad1_",IinjStart
	Variable BaselineStart,BaselineEnd,StartCurrent,EndCurrent,CurrentStep,AHPStart,tint,AHPEnd
	BaselineStart=0;BaselineEnd=4;EndCurrent=14;AHPStart=4

	// finds waves with spikes by checking threshold crossing
	variable i,j
	j=0
	String RheobaseSpikeName, Dv1Name, Dv2Name, Dv3Name
	make/O/N=1/T RheobaseSpikeWaves
	For (i=0; i<TraceCount; i+=1)
		wave CurrentWave=WaveRefIndexed("",i,1)
		EndCurrent = numpnts(currentwave)	// catch to reset endcurrent to just the end of the whole step if I did a longer pulse
		FindLevel /Q/R=(StartCurrent,EndCurrent) Currentwave, DetectionThreshold
		If (V_flag == 0)
			RheobaseSpikeName="Rheobase_"+num2str(j)
			Duplicate /O Currentwave,$RheobaseSpikeName
			RheobaseSpikeWaves[j]=RheobaseSpikeName
			j=j+1
			redimension /n=(j+1) RheobaseSpikeWaves
		EndIf
	EndFor
	redimension /n=(j) RheobaseSpikeWaves
	variable RheobaseTraceCount=numpnts(RheobaseSpikeWaves)
	
	maxrheo = j
	
	For (i=0; i<RheobaseTraceCount; i+=1)
		Wave CurrentRheobaseWave=$(RheobaseSpikeWaves[i])
		if(i==0)
			//MakeDerivGraphs()	// old code from troubleshooting
			if(Guimode ==1)					
				MakeAnalysisPanelmini()
			else
				MakeAnalysisPanel()
			endif
		endif
		Dv1Name = "DV1_" + num2str(i)
		Dv2Name = "DV2_" + num2str(i)
		Dv3Name = "DV3_" + num2str(i)
		Differentiate CurrentRheoBaseWave /D=$Dv1Name
		Smooth 5, $Dv1Name
		Differentiate CurrentRheoBaseWave /D=$Dv2Name
		Differentiate $Dv2Name
		Smooth 5, $Dv2Name
		Differentiate CurrentRheoBaseWave /D=$Dv3Name
		Differentiate $Dv3Name
	//	Smooth 5, $Dv3Name
		Differentiate $Dv3Name
		Smooth 5, $Dv3Name

	//	AppendtoGraph /W=APAnalysis CurrentRheoBaseWave
	//	AppendtoGraph /W=FirstDeriv $Dv1Name
	//	AppendtoGraph /W=SecondDeriv $Dv2Name
	//	AppendtoGraph /W=ThirdDeriv $Dv3Name
		if(GUImode == 0)
			AppendtoGraph /W=ThreshAnalysisPanel#APPanel CurrentRheoBaseWave
			AppendtoGraph /W=ThreshAnalysisPanel#D1Panel $Dv1Name
			AppendtoGraph /W=ThreshAnalysisPanel#D2Panel $Dv2Name
			AppendtoGraph /W=ThreshAnalysisPanel#D3Panel $Dv3Name
		endif
	endfor


		
end


Function MakeAnalysisPanel()
	NVAR windowstart, windowend
	NVAR activerheonum, maxrheo
	NVAR cursorstartloc
	wave peak1amp, peak1time, peak2amp, peak2time, rheonum, peak1derivvoltage, peak2derivvoltage
		wave appeakvol, appeakloc, vrest
	DoWindow ThreshAnalysisPanel
	if(V_Flag == 1)
		Killwindow ThreshAnalysisPanel
	endif
	NewPanel /W = (10,0,1240, 1225) /N=ThreshAnalysisPanel as "Threshold Analysis Panel"
	Display /W = (10,50,600,300) /HOST=ThreshAnalysisPanel /N = APPanel
	Display /W = (10,340,600,590) /HOST=ThreshAnalysisPanel /N = D1Panel	
	Display /W = (10,630,600,880) /HOST=ThreshAnalysisPanel /N = D2Panel	
	Display /W = (10,920,600,1170) /HOST=ThreshAnalysisPanel /N = D3Panel	
	Display /W = (650, 50, 1100,400) /HOST=ThreshAnalysisPanel /N = ActiveAP
	Display /W = (650, 450, 1100, 800) /HOST =ThreshAnalysisPanel /N = ActiveDeriv


	Button populate, pos={10,10}, win=ThreshAnalysisPanel, size={150,30}, proc=populate_proc, title = "Select Display Mode"
	Button initialize, pos={175,10}, win=ThreshAnalysisPanel, size = {150,30}, proc=initialize_proc, title = "Initialize Analysis Waves"
	Button forcedisplay, pos={350,10}, win=ThreshAnalysisPanel, size={150,30}, proc=forcedisplay_proc, title = "Override Wave Display"
	Button lock, pos={500,10}, win=ThreshAnalysisPanel, size={150,30}, proc=lockbtns_proc, title = "Lock Buttons"
	Button analyze, pos={50,1180}, win = ThreshAnalysisPanel, size = {150,40}, proc= locatepeaks_proc, title = "Analyze for Threshold"
	Button dv1analyze, pos={220,1180}, win = ThreshAnalysisPanel, size = {200,40}, proc= locatedv1pks_proc, title = "Approximate From Dv1"
	Button annotate, pos = {430, 1180}, win = ThreshAnalysisPanel, size = {150,40}, proc=Annotate_proc, title = "Annotate PPP"	
	Button closeAll, pos={1100,1180}, win=ThreshAnalysisPanel, size={150,40}, proc=closeanalysis_proc,title="Exit Analysis", fsize = 14
	SetDrawEnv /W=ThreshAnalysisPanel fsize= 20,fstyle= 1,textrgb= ((0),(0),(0))
	DrawText /W=ThreshAnalysisPanel 800,35, "Wave of Interest"
		DrawLine /W=ThreshAnalysisPanel 775,40,975,40
		
	SetVariable rheonum, pos={650, 420}, size = {140,20}, proc=num_proc, value = activerheonum, title = "Rheo number", fsize=14, limits = {0,maxrheo-1,1}
	setvariable windowscaling1, pos={800,420}, size={140,20},proc=resize_window_proc, value = windowstart, title = "Window start", fsize=14,limits={0,inf,0.5}
	setvariable windowscaling2, pos={950,420}, size={140,20},proc=resize_window_proc, value = windowend, title = "Window end", fsize=14,limits={0,inf,0.5}
	setvariable cursorloc, pos={1115,420}, size={140,20},proc=cursorloc_proc, value = cursorstartloc, title = "Cursor Loc", fsize=14,limits={0,inf,0.5}

	Button getcrsrval1, pos={1115, 515}, size={100,40}, proc=getcrsr1_proc, title = "Save Peak 1", fsize = 14
	Button getcrsrval2, pos={1115, 575}, size={100,40}, proc=getcrsr2_proc, title = "Save Peak 2", fsize = 14
	
	Button csramp1, pos={1115, 150}, size={100,40}, proc=csramp1_proc, title = "Amp 1", fsize = 14
	Button csramp2, pos={1115, 200}, size={100,40}, proc=csramp2_proc, title = "Amp 2", fsize = 14
	
	Button both1, pos={1115, 675}, size={100,40},proc=both1_proc, title = "Get All 1", fsize= 14
	Button both2,  pos={1115, 725}, size={100,40},proc=both2_proc, title = "Get All 2", fsize= 14
	
	Button nanfill, pos={1115,350}, size={100,40}, proc=exclude_proc, title = "Exclude Wave", fsize=14
	
	Button redim, pos= {650,1180}, size = {150,40}, proc=redim_proc, title = "Redimension Waves", fsize = 14
	
	Button finish, pos={950, 1180}, size = {150,40}, proc=finish_proc, title = "Get Ampl Data", fsize = 14
	Button avg, pos={800, 1180}, size={150,40}, proc=avgallwaves_proc, title = "Average Values", fsize =14
	ShowInfo/W=ThreshAnalysisPanel

end


Function HighlightRheoWave(wavenum)
	variable wavenum
	NVAR cursorstartloc, displaymode, maxrheo, GUImode
	string WaveNameStr, Dv1Name, Dv2Name, Dv3Name
	variable i	

	if(displaymode == 0)
		TabulaRasa(maxrheo)
		if(GUImode == 0)
			for(i=0;i<maxrheo; i+=1)
				WaveNameStr = "Rheobase_" + num2str(i)
				Dv1Name = "DV1_" + num2str(i)
				Dv2Name = "DV2_" + num2str(i)
				Dv3Name = "DV3_" + num2str(i)	
				
				AppendtoGraph /W=ThreshAnalysisPanel#APPanel  $WaveNameStr
				AppendtoGraph /W=ThreshAnalysisPanel#D1Panel $Dv1Name
				AppendtoGraph /W=ThreshAnalysisPanel#D2Panel $Dv2Name
				AppendtoGraph /W=ThreshAnalysisPanel#D3Panel $Dv3Name
				
				ModifyGraph /Z /W=ThreshAnalysisPanel#APPanel lsize($WaveNameStr) = .5,   rgb($WaveNameStr) = (0,0,0), lstyle($WaveNameStr)=8
				ModifyGraph /Z /W=ThreshAnalysisPanel#D1Panel lsize($Dv1Name) = .5, rgb($Dv1Name) = (0,0,0), lstyle($Dv1Name)=8
				ModifyGraph /Z /W=ThreshAnalysisPanel#D2Panel lsize($Dv2Name) = .5, rgb($Dv2Name) = (0,0,0), lstyle($Dv2Name)=8
				ModifyGraph /Z /W=ThreshAnalysisPanel#D3Panel lsize($Dv3Name) = .5, rgb($Dv3Name) = (0,0,0), lstyle($Dv3Name)=8
			endfor
			
			WaveNameStr = "Rheobase_" + num2str(wavenum)
			Dv1Name = "DV1_" + num2str(wavenum)
			Dv2Name = "DV2_" + num2str(wavenum)
			Dv3Name = "DV3_" + num2str(wavenum)	
			
			ModifyGraph /Z /W=ThreshAnalysisPanel#APPanel lsize($WaveNameStr)=4,rgb($WaveNameStr)=(65280,0,0), lstyle($WaveNameStr)=0
			ModifyGraph /Z/W=ThreshAnalysisPanel#D1Panel lsize($Dv1Name)=4,rgb($Dv1Name)=(65280,0,0), lstyle($Dv1Name)=0
			ModifyGraph /Z /W=ThreshAnalysisPanel#D2Panel lsize($Dv2Name)=4,rgb($Dv2Name)=(65280,0,0),lstyle($Dv2Name)=0
			ModifyGraph /Z /W=ThreshAnalysisPanel#D3Panel lsize($Dv3Name)=4,rgb($Dv3Name)=(65280,0,0), lstyle($Dv3Name)=0
			
		endif
		AppendtoGraph /W=ThreshAnalysisPanel#ActiveAP $WaveNameStr
		AppendtoGraph /W=ThreshAnalysisPanel#ActiveDeriv $Dv3Name
			//Cursor /W=ThreshAnalysisPanel#ActiveAP A $WaveNameStr  5
			SetActiveSubwindow ThreshAnalysisPanel#ActiveAP
			Cursor /K C
			Cursor /K D
			SetActiveSubWindow ThreshAnalysisPanel#ActiveDeriv
			Cursor /W= ThreshAnalysisPanel#ActiveDeriv  A $Dv3Name  cursorstartloc
	elseif(displaymode == 1)
		TabulaRasa(maxrheo)
			i = wavenum
			WaveNameStr = "Rheobase_" + num2str(i)
			Dv1Name = "DV1_" + num2str(i)
			Dv2Name = "DV2_" + num2str(i)
			Dv3Name = "DV3_" + num2str(i)	
			if(GUImode == 0)
				AppendtoGraph /W=ThreshAnalysisPanel#APPanel  $WaveNameStr
				AppendtoGraph /W=ThreshAnalysisPanel#D1Panel $Dv1Name
				AppendtoGraph /W=ThreshAnalysisPanel#D2Panel $Dv2Name
				AppendtoGraph /W=ThreshAnalysisPanel#D3Panel $Dv3Name
			endif
			AppendtoGraph /W=ThreshAnalysisPanel#ActiveAP $WaveNameStr
			AppendtoGraph /W=ThreshAnalysisPanel#ActiveDeriv $Dv3Name
				SetActiveSubwindow ThreshAnalysisPanel#ActiveAP
				Cursor /K C
				Cursor /K D
				SetActiveSubWindow ThreshAnalysisPanel#ActiveDeriv
				Cursor /W= ThreshAnalysisPanel#ActiveDeriv  A $Dv3Name  cursorstartloc
	endif
end
Function TabulaRasa(maxnum)
	variable maxnum
	variable i 
		string WaveNameStr, Dv1Name, Dv2Name, Dv3Name
	for(i = 0; i<maxnum; i+=1)
		WaveNameStr = "Rheobase_" + num2str(i)
		Dv1Name = "DV1_" + num2str(i)
		Dv2Name = "DV2_" + num2str(i)
		Dv3Name = "DV3_" + num2str(i)	
		RemoveFromGraph /Z /W=ThreshAnalysisPanel#APPanel $WaveNameStr
		RemovefromGraph /Z /W = ThreshAnalysisPanel#D1Panel $Dv1Name
		RemovefromGraph /Z /W = ThreshAnalysisPanel#D2Panel $Dv2Name
		RemovefromGraph /Z /W = ThreshAnalysisPanel#D3Panel $Dv3Name
		RemoveFromGraph /Z /W=ThreshAnalysisPanel#ActiveAP $WaveNameStr
		RemoveFromGraph /Z /W=ThreshAnalysisPanel#ActiveDeriv $Dv3Name
	endfor

end

function locatepeaks_proc (ctrlName) : Buttoncontrol
	string ctrlname
	
	String  ListOfTraceNames = TraceNameList ("", ";",1)
	Variable TraceCount = ItemsInList(ListOfTraceNames)
	variable i
	For (i=0; i<TraceCount; i+=1)
		wave CurrentWave=WaveRefIndexed("",i,1)
		wave tempwave
		differentiate currentwave /d=tempwave
		
		FindLevel /Q  tempwave, 20
		//in progress
	EndFor
end
Function locatedv1pks_proc (ctrlName) : Buttoncontrol
	string CtrlName
		NVAR activerheonum
		wave peak1amp, peak1time, peak2amp, peak2time, rheonum, peak1derivvoltage, peak2derivvoltage
		wave appeakvol, appeakloc, vrest
		variable TimePt
		
		string wavenamestr = "Dv1_" + num2str(activerheonum)
		FindLevel /Q $wavenamestr, 20
		TimePt = V_LevelX
		//peak1time[activerheonum] = TimePt
		
		wavenamestr = "Dv3_" + num2str(activerheonum)
			SetActiveSubWindow ThreshAnalysisPanel#ActiveDeriv
			Cursor /W= ThreshAnalysisPanel#ActiveDeriv  A $wavenamestr  TimePt

end


Function initialize_proc (ctrlName) : Buttoncontrol
	String CtrlName
	
	Make/o/n=0 peak1amp, peak1time, peak2amp, peak2time, rheonum, peak1derivvoltage, peak2derivvoltage
	Make/o/n=0 appeakvol, appeakloc, vrest
	Edit /W= (650, 825, 1200, 1150) /HOST=ThreshAnalysisPanel /N = ThreshParams rheonum, peak1Amp, peak1time, peak2Amp, Peak2time, peak1derivvoltage, peak2derivvoltage, appeakvol, appeakloc, vrest


end
Function forcedisplay_proc (CtrlName) : ButtonControl
	String CtrlName
	wave peak1amp, peak1time, peak2amp, peak2time, rheonum, peak1derivvoltage, peak2derivvoltage
		wave appeakvol, appeakloc, vrest
	Edit /W= (650, 825, 1200, 1150) /HOST=ThreshAnalysisPanel /N = ThreshParams rheonum, peak1Amp, peak1time, peak2Amp, Peak2time, peak1derivvoltage, peak2derivvoltage, appeakvol, appeakloc, vrest

	if(waveexists(peak1amp))
		ModifyControl initialize disable=1
	endif
end
Function lockbtns_proc (ctrlName) : ButtonControl
	String CtrlName
	ModifyControl initialize disable=1
	ModifyControl forcedisplay disable=1
	ModifyControl lock disable=1
end
function resize_window_proc (ctrlName, varNum, varStr, varName) : setvariablecontrol
	string ctrlname
	Variable varNum
	String varStr
	String varName
	ResizeWindows()
end
Function cursorloc_proc (ctrlName, varNum, varStr, varName) : setvariablecontrol
	string ctrlname
	Variable varNum
	String varStr
	String varName
	NVAR cursorstartloc
	cursorstartloc = varNum
end
Function closeanalysis_proc (ctrlName) : Buttoncontrol
	String CtrlName
		Killwindow ThreshAnalysisPanel
		
end
Function populate_proc(ctrlName) : Buttoncontrol
	String CtrlName
	
	NVAR displaymode, activerheonum
	if(Displaymode == 0)
		displaymode = 1
	elseif(Displaymode == 1)
		displaymode = 0
	endif
	
		HighlightRheoWave(activerheonum)

end	
Function num_proc(ctrlName,varNum,varStr,varName) : SetVariableControl
	String ctrlName
	Variable varNum
	String varStr
	String varName
	NVAR activerheonum
	activerheonum=varNum
	HighlightRheoWave(activerheonum)
	ResizeWindows()
end
Function getcrsr1_proc (ctrlName) : ButtonControl
	String ctrlName
	NVAR activerheonum
	wave peak1amp, peak1time, peak2amp, peak2time, rheonum, peak1derivvoltage, peak2derivvoltage
	rheonum[activerheonum] = activerheonum
	peak1time[activerheonum] = xcsr(A)
	peak1derivvoltage[activerheonum] = vcsr(A)
end
Function getcrsr2_proc (ctrlName) : ButtonControl
	String ctrlName
	NVAR activerheonum
	wave peak1amp, peak1time, peak2amp, peak2time, rheonum, peak1derivvoltage, peak2derivvoltage
	rheonum[activerheonum] = activerheonum
	peak2time[activerheonum] = xcsr(A)
	peak2derivvoltage[activerheonum] = vcsr(A)
end
Function csramp1_proc (ctrlName) : ButtonControl
	String CtrlName
	NVAR activerheonum
	wave peak1amp, peak1time, peak2amp, peak2time, rheonum, peak1derivvoltage, peak2derivvoltage
	peak1amp[activerheonum] = vcsr(A)
end
Function csramp2_proc (ctrlName) : ButtonControl
	String CtrlName
	NVAR activerheonum
	wave peak1amp, peak1time, peak2amp, peak2time, rheonum, peak1derivvoltage, peak2derivvoltage
	peak2amp[activerheonum] = vcsr(A)
end
Function both1_proc (ctrlName) : ButtonControl
	String CtrlName
	NVAR activerheonum
	wave peak1amp, peak1time, peak2amp, peak2time, rheonum, peak1derivvoltage, peak2derivvoltage
	wave tempwave
		variable timept = xcsr(A)
	string wavenamestr = "Rheobase_" + num2str(activerheonum)
	rheonum[activerheonum] = activerheonum
	peak1time[activerheonum] = timept	
	duplicate /o $wavenamestr, tempwave
	peak1amp[activerheonum] = tempwave[timept*100]
	peak1derivvoltage[activerheonum] = vcsr(A)
	SetActiveSubwindow ThreshAnalysisPanel#ActiveAP
	Cursor /K C
	Cursor /h=2 C $wavenamestr, timept
	SetActiveSubwindow ThreshAnalysisPanel#ActiveDeriv

end
Function both2_proc (CtrlName) : ButtonControl
	String CtrlName
	NVAR activerheonum
	wave peak1amp, peak1time, peak2amp, peak2time, rheonum, peak1derivvoltage, peak2derivvoltage
	wave tempwave
		variable timept = xcsr(A)
	string wavenamestr = "Rheobase_" + num2str(activerheonum)
	rheonum[activerheonum] = activerheonum
	peak2time[activerheonum] = timept	
	duplicate /o $wavenamestr, tempwave
	peak2amp[activerheonum] = tempwave[timept*100]
	peak2derivvoltage[activerheonum] = vcsr(A)
	SetActiveSubwindow ThreshAnalysisPanel#ActiveAP
	Cursor /K D
	Cursor /h=2 D $wavenamestr, timept
	SetActiveSubwindow ThreshAnalysisPanel#ActiveDeriv
end
Function exclude_proc (ctrlname): buttoncontrol
	String ctrlname
	NVAR activerheonum
	wave peak1amp, peak1time, peak2amp, peak2time, rheonum, peak1derivvoltage, peak2derivvoltage
	rheonum[activerheonum] = activerheonum
	peak1time[activerheonum] = NaN
	peak2time[activerheonum] = NaN
	peak1amp[activerheonum] = NaN
	peak2amp[activerheonum] = NaN
	peak1derivvoltage[activerheonum] = NaN
	peak2derivvoltage[activerheonum] = NaN

end

function redim_proc(CtrlName) : ButtonControl
	String CtrlName
	NVAR maxrheo
	wave peak1amp, peak1time, peak2amp, peak2time, rheonum, peak1derivvoltage, peak2derivvoltage
	wave appeakvol, appeakloc, vrest
	redimension /N=(maxrheo) peak1amp, peak1time, peak2amp, peak2time, rheonum,peak1derivvoltage, peak2derivvoltage
	redimension /N=(maxrheo) appeakvol, appeakloc, vrest
	ModifyControl initialize disable=1
	BlankZeroes(peak1amp)
	BlankZeroes(peak1time)
	BlankZeroes(peak2amp)
	BlankZeroes(peak2time)
	BlankZeroes(peak1derivvoltage)
	BlankZeroes(peak2derivvoltage)
	BlankZeroes(appeakvol)
	BlankZeroes(appeakloc)
	BlankZeroes(vrest)
end
Function avgallwaves_proc(ctrlname) : ButtonControl
	String CtrlName
	wave peak1amp, peak1time, peak2amp, peak2time, rheonum,peak1derivvoltage, peak2derivvoltage
		wave appeakvol, appeakloc, vrest


//Rheobase reps	Vrest	Threshold current	absolute threshold	relative threshold (rest)	Spike amplitde (relative threshold)	amp relative rest	halfwidth	risetime (10-90)	max depol rate	max repol rate	AHP absolute amplitude	AHP amp relative rest	AHP latency	latency to threshold	latency to peak


	make /o/n=8 analyzed_results							// order is peak1amp, peak1time, peak2amp, peak2time, peak1derivvoltage, peak2derivvoltage
	make /o/n=8/T outputtext

	duplicate /o peak1amp, tempwave				
	wavetransform zapNaNs tempwave
	analyzed_results[0] = mean(tempwave)
	outputtext[0] = "Peak 1 Amp"
	
	duplicate /o peak1time, tempwave
	wavetransform zapNaNs tempwave
	analyzed_results[1] = mean(tempwave)
	outputtext[1] = "Peak 1 Time"

	duplicate /o peak2amp, tempwave
	wavetransform zapNaNs tempwave
	analyzed_results[2] = mean(tempwave)
	outputtext[2] = "Peak 2 Amp"
	
	duplicate /o peak2time, tempwave
	wavetransform zapNaNs tempwave
	analyzed_results[3] = mean(tempwave)
	outputtext[3] = "Peak 2 Time"
	
	duplicate /o peak1derivvoltage, tempwave
	wavetransform zapNaNs tempwave
	analyzed_results[4] = mean(tempwave)
	outputtext[4] = "Peak 1 3rd Deriv"
	
	duplicate /o peak2derivvoltage, tempwave
	wavetransform zapNaNs tempwave
	analyzed_results[5] = mean(tempwave)
	outputtext[5] = "Peak 2 3rd Deriv"
	
	// I want to run through the waves and find the difference between
	// voltage of spike peak vs vrest, and vs threshold (peak1amp)
	//	store that as two new waves, then average the results
	variable i
	NVAR maxrheo
	make /o/n=(maxrheo) amprelthresh, threshrelrest
	for(i = 0; i < maxrheo; i+=1)
		amprelthresh[i] = appeakvol[i] - peak1amp[i]
		threshrelrest[i] = peak1amp[i] - vrest[i]
	endfor
	
	duplicate /o amprelthresh, tempwave
	wavetransform zapNaNs tempwave
	analyzed_results[6] = mean(tempwave)
	outputtext[6] = "Spike Amp Rel Thresh"
	
	duplicate /o threshrelrest, tempwave
	wavetransform zapNaNs tempwave
	analyzed_results[7] = mean(tempwave)
	outputtext[7] = "Thresh Rel Rest"
	
		edit outputtext,analyzed_results
		
	

	// work on output!
	// Figure out exactly what quantities I want to put into tracker
	// need to build a function that removes 0's and NaNs from a wave before averaging
	
end
Function finish_proc (ctrlName) : ButtonControl
	string CtrlName
	FinishAPAnalysis()
end
Function Annotate_proc (ctrlName) : ButtonControl
	string CtrlName
	doWindow AnnotatePPP
	if(V_Flag == 1)
		killWindow AnnotatePPP
	endif
	PPPAnnotate()
end

Function ResizeWindows()
	NVAR windowstart, windowend, displaymode, GUImode
	setaxis /W=ThreshAnalysisPanel#ActiveAP bottom windowstart, windowend
	setaxis /W=ThreshAnalysisPanel#ActiveDeriv bottom windowstart, windowend
	if(displaymode == 1)
		if(GUImode == 0)
			setaxis /W=ThreshAnalysisPanel#APPanel bottom windowstart, windowend
			setaxis /W=ThreshAnalysisPanel#D1Panel bottom windowstart, windowend
			setaxis /W=ThreshAnalysisPanel#D2Panel bottom windowstart, windowend
			setaxis /W=ThreshAnalysisPanel#D3Panel bottom windowstart, windowend
		endif
	elseif(displaymode == 0)
		if(GUImode == 0)
			setaxis /W=ThreshAnalysisPanel#APPanel /A
			setaxis /W=ThreshAnalysisPanel#D1Panel /A
			setaxis /W=ThreshAnalysisPanel#D2Panel /A
			setaxis /W=ThreshAnalysisPanel#D3Panel /A
		endif
	endif
end
Function /WAVE BlankZeroes(waveIn)
	Wave waveIn
	variable i
	//Duplicate /O waveIn, waveOut
	for(i=0; i<numpnts(waveIn); i+=1)
		if(waveIn[i] == 0)
			waveIn[i] = NaN
		endif
	endfor
	return waveIn
end

Function FinishAPAnalysis()
	NVAR maxrheo
	
	string wavenm
	wave peak1amp, peak1time, peak2amp, peak2time, rheonum,peak1derivvoltage, peak2derivvoltage
	wave appeakvol, appeakloc, vrest
	variable i
	for(i = 0; i<maxrheo; i+=1)
		wavenm = "Rheobase_" + num2str(i)
		wave tempwave = $wavenm
		Wavestats/Q tempwave
		appeakvol[i] = V_max
		FindLevel /Q tempwave, appeakvol[i]
		appeakloc[i] = V_LevelX 
		wavestats/Q/R=(0,4) tempwave 
		vrest[i] = V_avg
		
		// rest of spike analysis
		
	endfor


end

Function PPPAnnotate()
	NVAR activerheonum
	wave peak1amp, peak1time, peak2amp, peak2time, rheonum, peak1derivvoltage, peak2derivvoltage
	string dv1name, wavename1
	variable timepoint, ymax, ymin
	dv1name = "Dv1_" + num2str(activerheonum)
	wavename1 = "Rheobase_" + num2str(activerheonum)
	wavestats /Q $dv1name 
		ymax = V_max +50
		ymin = V_min -50
	Display /W=(825, 10, 1400, 400) /N=AnnotatePPP $dv1name vs $wavename1
	SetDrawEnv xcoord= bottom,ycoord= left
	if(peak1amp[activerheonum] != NaN)
		timepoint = peak1amp[activerheonum]
		SetDrawEnv xcoord= bottom,ycoord= left
		DrawLine /W=AnnotatePPP timepoint, ymin, timepoint, ymax
		SetAxis left ymin, ymax
	endif
	if(peak2amp[activerheonum] != NaN)
		timepoint = peak2amp[activerheonum]
		SetDrawEnv xcoord= bottom,ycoord= left
		SetDrawEnv /W=AnnotatePPP dash = 8
		DrawLine /W=AnnotatePPP timepoint, ymin, timepoint, ymax

	endif



end



//unused for troubleshooting
Function MakeDerivGraphs()
			DoWindow APAnalysis
			if(V_flag == 1)
				KillWindow APAnalysis
			endif
			DoWindow FirstDeriv
			if(V_Flag == 1)
				KillWindow FirstDeriv
			endif
			DoWindow SecondDeriv
			if(V_flag == 1)
				KillWindow SecondDeriv
			endif
			DoWindow ThirdDeriv
			if(V_flag == 1)	
				KillWindow ThirdDeriv
			endif
			Display /W = (10,0,520,150) /N = APAnalysis as "Rheobase Spikes"
			ModifyGraph /W=APAnalysis mode=0
			Display /W = (10,225,520,375) /N = FirstDeriv as "First Derivatives"
			ModifyGraph /W=FirstDeriv mode=0
			Display /W = (10,425,520,575) /N = SecondDeriv as "Second Derivatives"
			ModifyGraph /W=SecondDeriv mode = 0
			Display /W = (10,625,520,775) /N = ThirdDeriv as "Third Derivatives"
			ModifyGraph /W=ThirdDeriv mode=0

end








 // A BUNCH OF MODIFICATIONS TO BUILD A SMALLER, EFFICIENT GUI
 // This is primarily driven by issues with mac/windows and high-res display incompatibilities
 
 
 
Function MakeAnalysisPanelmini()
	NVAR windowstart, windowend
	NVAR activerheonum, maxrheo
	NVAR cursorstartloc
	wave peak1amp, peak1time, peak2amp, peak2time, rheonum, peak1derivvoltage, peak2derivvoltage
		wave appeakvol, appeakloc, vrest
	DoWindow ThreshAnalysisPanel
	if(V_Flag == 1)
		Killwindow ThreshAnalysisPanel
	endif
	NewPanel /W = (10,0,800, 550) /N=ThreshAnalysisPanel as "Threshold Analysis Panel"
	DefineGuide /W=ThreshAnalysisPanel leftside ={FL,.3, FR} 
	DefineGuide /W=ThreshAnalysisPanel rightside ={FL, .95, FR}
	DefineGuide /W=ThreshAnalysisPanel upper1 ={FT, 0.05, FB} 
	DefineGuide /W=ThreshAnalysisPanel upper2 ={FT, .40, FB}
	DefineGuide /W=ThreshAnalysisPanel upper3 ={FT, .475, FB}
	DefineGuide /W=ThreshAnalysisPanel upper4 ={FT, .675, FB}
	DefineGuide /W=ThreshAnalysisPanel lower1 ={FT, .35, FB}
	DefineGuide /W=ThreshAnalysisPanel lower2 ={FT, .70, FB}
	DefineGuide /W=ThreshAnalysisPanel lower3 ={FT, .65, FB}
	DefineGuide /W=ThreshAnalysisPanel lower4 ={FT, .85, FB}

	Display /FG = (leftside, upper1, rightside, lower1) /HOST=ThreshAnalysisPanel /N = ActiveAP
	Display /FG = (leftside, upper2, rightside, lower2) /HOST =ThreshAnalysisPanel /N = ActiveDeriv

	Button initialize, pos={25,10}, win=ThreshAnalysisPanel, size = {150,30}, proc=initializequick_proc, title = "Initialize Analysis Waves"
	Button forcedisplay, pos={25,40}, win=ThreshAnalysisPanel, size={150,30}, proc=forcedisplayquick_proc, title = "Override Wave Display"
	Button lock, pos={25,70}, win=ThreshAnalysisPanel, size={150,30}, proc=lockbtns_proc, title = "Lock Buttons"
	Button closeAll, pos={25,500}, win=ThreshAnalysisPanel, size={150,40}, proc=closeanalysis_proc,title="Exit Analysis"
	
	SetVariable rheonum, pos={25, 120}, size = {140,20}, proc=numquick_proc, value = activerheonum, title = "Rheo_#", fsize=14, limits = {0,maxrheo-1,1}
	setvariable windowscaling1, pos={25,160}, size={140,20},proc=resize_window_proc, value = windowstart, title = "Win_start", fsize=14,limits={0,inf,0.5}
	setvariable windowscaling2, pos={25,200}, size={140,20},proc=resize_window_proc, value = windowend, title = "Window end", fsize=14,limits={0,inf,0.5}
	setvariable cursorloc, pos={25,240}, size={140,20},proc=cursorloc_proc, value = cursorstartloc, title = "Cursor Loc", fsize=14,limits={0,inf,0.5}

	Button both1, pos={25, 280}, size={100,40},proc=both1_proc, title = "Get All 1", fsize= 14
	Button both2,  pos={25, 320}, size={100,40},proc=both2_proc, title = "Get All 2", fsize= 14
	
	Button nanfill, pos={25,360}, size={100,40}, proc=exclude_proc, title = "Exclude Wave", fsize=14
	
	Button finish, pos= {25,420}, size = {150,40}, proc=finish_proc, title = "Finish Spikes", fsize = 14
	Button dv1analyze, pos={135,280}, win = ThreshAnalysisPanel, size = {80,50}, proc= locatedv1pks_proc, title = "Dv1"	
	Button PPPAnnotate, pos={135,340}, win = ThreshAnalysisPanel, size = {80,50}, proc = Annotate_proc, title = "Check Anno"
	
	Button avg, pos={25, 460}, size={150,40}, proc=avgallwaves_proc, title = "Average Values", fsize =14
	ShowInfo/W=ThreshAnalysisPanel

//	SetWindow kwTopWin hook(ThreshResize)=ThreshPanel_WinResize_hook

end

Function initializequick_proc (ctrlName) : Buttoncontrol
	String CtrlName
	Make/o/n=0 peak1amp, peak1time, peak2amp, peak2time, rheonum, peak1derivvoltage, peak2derivvoltage
	Make/o/n=0 appeakvol, appeakloc, vrest
	edit /W = (.3, .75, .95, .95) /HOST=ThreshAnalysisPanel /N=ThreshParamsrheonum peak1Amp, peak1time, peak2Amp, Peak2time, peak1derivvoltage, peak2derivvoltage, appeakvol, appeakloc, vrest


end
Function forcedisplayquick_proc (CtrlName) : ButtonControl
	String CtrlName
	wave peak1amp, peak1time, peak2amp, peak2time, rheonum, peak1derivvoltage, peak2derivvoltage
		wave appeakvol, appeakloc, vrest
	edit /W = (.3, .75, .95, .95) /HOST=ThreshAnalysisPanel /N=ThreshParamsrheonum peak1Amp, peak1time, peak2Amp, Peak2time, peak1derivvoltage, peak2derivvoltage, appeakvol, appeakloc, vrest
	if(waveexists(peak1amp))
		ModifyControl initialize disable=1
	endif
	redim_proc(ctrlname)
end

Function HighlightQuick(wavenum)
	variable wavenum
	NVAR cursorstartloc
	string WaveNameStr,Dv3Name
	variable i
	for(i=0;i<200; i+=1)
		WaveNameStr = "Rheobase_" + num2str(i)
		Dv3Name = "DV3_" + num2str(i)	
		RemoveFromGraph /Z /W=ThreshAnalysisPanel#ActiveAP $WaveNameStr
		RemoveFromGraph /Z /W=ThreshAnalysisPanel#ActiveDeriv $Dv3Name
	endfor	
	WaveNameStr = "Rheobase_" + num2str(wavenum)
	Dv3Name = "DV3_" + num2str(wavenum)	
	AppendtoGraph /W=ThreshAnalysisPanel#ActiveAP $WaveNameStr
	AppendtoGraph /W=ThreshAnalysisPanel#ActiveDeriv $Dv3Name
		//Cursor /W=ThreshAnalysisPanel#ActiveAP A $WaveNameStr  5
		SetActiveSubwindow ThreshAnalysisPanel#ActiveAP
		Cursor /K C
		Cursor /K D
		SetActiveSubWindow ThreshAnalysisPanel#ActiveDeriv
		Cursor /W= ThreshAnalysisPanel#ActiveDeriv  A $Dv3Name  cursorstartloc	
end
Function numquick_proc(ctrlName,varNum,varStr,varName) : SetVariableControl
	String ctrlName
	Variable varNum
	String varStr
	String varName
	NVAR activerheonum
	activerheonum=varNum
	HighlightQuick(activerheonum)
	ResizeWindows()
end
