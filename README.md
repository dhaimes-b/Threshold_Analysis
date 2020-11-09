# Threshold_Analysis
For analysis of threshold spikes acquired in Igor Pro

# Purpose
This code was written Sept. 2020 for the purpose of alleviating issues of spike threshold analysis performed across heterogeneous populations of neurons.
Previous threshold detection methods typically rely on 1 methodology (such as a cutoff value, or a peak in a given derivative (2nd,3rd,etc.). However, utilizing one methodology, without specifically guiding these detection algorithms can provide misleading, or inaccurate results. Therefore, I've created this code with the intention to perform user-assisted spike detection, that is reliant upon an experienced electrophysiologists knowledge of threshold. The user can systemically perform peak detection on the third derivative of the waveform, confirm by seeing how the value chosen would align with other spike detection methodologies, and then assess it's accuracy in the phase-space (the 1st derivative of voltage plotted against the voltage of the original waveform). 
