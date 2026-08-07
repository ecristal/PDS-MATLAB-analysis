# Initial Project Code Inventory

This is an automatically generated, non-invasive first pass over project-owned MATLAB candidates under `Scripts_analisis/`. It does **not** infer scientific correctness or replace a manual review of `Live_scripts/analysis_daphne_data.mlx` and other Live Scripts. Vendor trees are deliberately excluded.

## Scope and method

- Entries catalogued: **121** (`.m` and `.mlx`, excluding detected vendor directories).
- MATLAB source entries whose first executable declaration is a function: **68**.
- MATLAB source entries treated as scripts: **39**.
- Live Scripts pending manual/MATLAB export review: **14**.
- Function signatures, leading comments, and potential function-call tokens were extracted from `.m` files only. Call candidates are leads for manual dependency mapping, not a validated call graph.

## Families for manual review

### Calibration, fitting and metrics (6)

| Path | Type | Entry point | Notes |
|---|---|---|---|
| `data/charge_pump_calculations.m` | MATLAB source | `script` | Este script se utiliza para calcular la transferencia de energía en una bomba de carga. En una bomba de carga, la carga almacenada en un cap |
| `data/find_peaks_hist_adaptive.m` | MATLAB source | `find_peaks_hist_adaptive` | FIND_PEAKS_HIST_ADAPTIVE Adaptive peak positions for histogram data (Option A: findpeaks). % Usage: [locs,pks,widths,proms,min_sep] = find_p |
| `data/fit2SPE.m` | MATLAB source | `fit2SPE` | reusable project function or helper (review required) |
| `data/gaussian_fit_SNR.m` | MATLAB source | `gaussian_fit_SNR` | y_hist = histcounts(integral,h.BinEdges); L = islocalmax(movmedian(y_hist,2),'MinSeparation',min_sep,'SamplePoints',x_hist); L = L & (x_hist |
| `data/my_gaussian_fit.m` | MATLAB source | `my_gaussian_fit` | x_hist_plot = x_axis_low_limit:0.01:x_axis_high_limit; snr_gauss_fit = fit(x_hist',y_hist','gauss4'); gauss_fitted_curve = snr_gauss_fit(x_h |
| `data/plotSNRandDynamicRange.m` | MATLAB source | `plotSNRandDynamicRange` | reusable project function or helper (review required) |

### DAPHNE/NP04 configuration and analysis (22)

| Path | Type | Entry point | Notes |
|---|---|---|---|
| `daphne/analisis_1.m` | MATLAB source | `script` | load('C1_data.mat') histogram_bin = 1e-9; min_sep = 10; |
| `daphne/calculateMedianPedestal.m` | MATLAB source | `calculateMedianPedestal` | This script calculates the pedestal taking randomly distributed regions in the pretrigger cualting the mean values, then the returned averag |
| `daphne/calculateVbr.m` | MATLAB source | `calculateVbr` | stabilized_position_init = 130; |
| `daphne/concatenate_daphne_wavefomrs.m` | MATLAB source | `concatenate_daphne_wavefomrs` | reusable project function or helper (review required) |
| `daphne/opt_calc_matched_filter.mlx` | Live Script | `live-script` | Binary ZIP-based Live Script: content review/export pending. |
| `daphne/optimun_daphne_weiner.m` | MATLAB source | `script` | Script para calcular el filtro optimo de wiener close all; |
| `daphne/sum_fitted_data.m` | MATLAB source | `sum_fitted_data` | reusable project function or helper (review required) |
| `daphne/tf_filter.m` | MATLAB source | `tf_filter` | reusable project function or helper (review required) |
| `daphne/trigger_jitter_analisis.m` | MATLAB source | `script` | jitter analisis clearvars -except x x_int y trigger number_waveforms length_vector filename configuration %%%%%%% |
| `daphne/weiner_deconv2.m` | MATLAB source | `weiner_deconv2` | b = 1 + 1/((modulus_tf_fft(k)^2)*(0.00001)*(original_signal(k)/noise_spectrum(k))); |
| `daphne/z_poles_signal_daphne.m` | MATLAB source | `script` | reusable project function or helper (review required) |
| `data/build_NP04_file_dir.m` | MATLAB source | `build_file_dir` | BUILD_FILE_DIR Build a nested struct of .dat file paths by scanning vgain_* tree. % Output leaf: file_dir.vgain_1330.p40p.endpoint_104.chann |
| `data/get_NP04_channel_numbers.m` | MATLAB source | `get_NP04_channel_numbers` | GET_CHANNEL_NUMBERS_SAFE Same as get_channel_numbers but returns [] if missing. |
| `data/modify_daphne_analysis_titles.m` | MATLAB source | `modify_daphne_analysis_titles` | reusable project function or helper (review required) |
| `data/NP04_channel2idx.m` | MATLAB source | `NP04_channel2idx` | reusable project function or helper (review required) |
| `data/NP04_endpoint2idx.m` | MATLAB source | `NP04_endpoint2idx` | reusable project function or helper (review required) |
| `data/NP04_idx2pde.m` | MATLAB source | `NP04_idx2pde` | reusable project function or helper (review required) |
| `data/NP04_pde2idx.m` | MATLAB source | `NP04_pde2idx` | reusable project function or helper (review required) |
| `data/NP04_snr_dr_set.m` | MATLAB source | `NP04_snr_dr_set` | SNR_DR_SET Store SNR + dynamic range into nested cell structure. % Layout: snr_dr_data{vgain}{pdeIdx}{endpoint}{channel}.snr |
| `data/NP04_vgain2idx.m` | MATLAB source | `NP04_vgain2idx` | reusable project function or helper (review required) |
| `data/optimal_filter_for_daphne_gpessina.m` | MATLAB source | `script` | best filter determination according to g.pessina lectures load('C:\Users\e_cri\OneDrive\Documents\PhD\Investigacion\MATLAB\sim_cold_amp\tran |
| `data/optimal_filter_for_daphne_gpessina_function.m` | MATLAB source | `optimal_filter_for_daphne_gpessina_function` | best filter determination according to g.pessina lectures load('C:\Users\e_cri\OneDrive\Documents\PhD\Investigacion\MATLAB\sim_cold_amp\tran |

### Data IO and format conversion (12)

| Path | Type | Entry point | Notes |
|---|---|---|---|
| `daphne/extract_and_import_DAPHNE_data.m` | MATLAB source | `extract_and_import_DAPHNE_data` | ---- Determine extension(s) robustly ---- Could be "...dat.gz" or "...something.gz" — we assume it becomes a .dat after gunzip gunzip output |
| `daphne/extract_data_for_daphne_weiner.m` | MATLAB source | `script` | Este script se utiliza para extraer datos relevenates para la implementacion del filtro weiner. Entre estos datos se encuentran la señales d |
| `daphne/import_daphne_data_mult_waveforms.m` | MATLAB source | `script` | reusable project function or helper (review required) |
| `daphne/import_data_daphne.m` | MATLAB source | `script` | filename = strcat('fbk_31_6_vgain_089_fpgafilter_off_behavioral_filtered_fast'); imported_data = importdata(strcat(filename,'.dat'))'; %% tx |
| `daphne/import_data_daphne_func.m` | MATLAB source | `import_data_daphne_func` | clearvars -except ch waveforms_length; filename = strcat('fbk_31_6_vgain_089_fpgafilter_off_behavioral_filtered_fast'); waveform_number = 50 |
| `daphne/save_to_dat.m` | MATLAB source | `script` | reusable project function or helper (review required) |
| `daphne/write_data_to_binary_txt_file.m` | MATLAB source | `write_data_to_binary_txt_file` | load(filename); |
| `data/CAENdata2Matlab.m` | MATLAB source | `script` | Antialias filter %%%%%%%%%%%%%% |
| `data/import_lecroy.m` | MATLAB source | `script` | importar datos de lecroy waverunner x = []; x = [x data.x]; |
| `data/npy2dat_CAENdigitizer_format.m` | MATLAB source | `npy2dat_CAENdigitizer_format` | n = floor((length_waveform-skip_samples)/max_length); [c,d] = size(data_f); |
| `data/readBinaryDataRSOsc.m` | MATLAB source | `readBinaryDataRSOsc` | readBinaryDataRSOsc This function parses binary data from RS Osciloscope function [data] = readBinaryDataRSOsc(dataInfo,dataWaveform) dataIn |
| `data/ReadLeCroyBinaryWaveform.m` | MATLAB source | `ReadLeCroyBinaryWaveform` | ReadLeCroyBinaryWaveform -  read binary waveform file created by a LeCroy Oscilloscope waveform = LeCroyBinaryWaveform(FILENAME) loads the w |

### Live Script analysis workflows (14)

| Path | Type | Entry point | Notes |
|---|---|---|---|
| `Live_scripts/analysis_daphne_data-BR-Lenovo.mlx` | Live Script | `live-script` | Binary ZIP-based Live Script: content review/export pending. |
| `Live_scripts/analysis_daphne_data.mlx` | Live Script | `live-script` | Binary ZIP-based Live Script: content review/export pending. |
| `Live_scripts/analysis_daphne_data_debug_purposes.mlx` | Live Script | `live-script` | Binary ZIP-based Live Script: content review/export pending. |
| `Live_scripts/analysis_daphne_data_multirun.mlx` | Live Script | `live-script` | Binary ZIP-based Live Script: content review/export pending. |
| `Live_scripts/analysis_daphne_data_multivar.mlx` | Live Script | `live-script` | Binary ZIP-based Live Script: content review/export pending. |
| `Live_scripts/analysis_daphne_data_V2.mlx` | Live Script | `live-script` | Binary ZIP-based Live Script: content review/export pending. |
| `Live_scripts/analysis_daphne_data_vgain_scan.mlx` | Live Script | `live-script` | Binary ZIP-based Live Script: content review/export pending. |
| `Live_scripts/analysis_daphne_data_vgain_scan_mezz.mlx` | Live Script | `live-script` | Binary ZIP-based Live Script: content review/export pending. |
| `Live_scripts/analysis_daphne_data_vgain_scan_november_coldbox.mlx` | Live Script | `live-script` | Binary ZIP-based Live Script: content review/export pending. |
| `Live_scripts/analysis_daphne_data_vgain_scan_np04.mlx` | Live Script | `live-script` | Binary ZIP-based Live Script: content review/export pending. |
| `Live_scripts/analysis_daphne_data_vgain_scan_np04_final.m` | MATLAB source | `script` | Live scripts para el analisis de los datos producidos DAPHNE V2A This section loads data to memory |
| `Live_scripts/analysis_daphne_data_vgain_scan_np04_final.mlx` | Live Script | `live-script` | Binary ZIP-based Live Script: content review/export pending. |
| `Live_scripts/analysis_data_megacell_test_stand.mlx` | Live Script | `live-script` | Binary ZIP-based Live Script: content review/export pending. |
| `Live_scripts/calculate_matched_filter.mlx` | Live Script | `live-script` | Binary ZIP-based Live Script: content review/export pending. |

### Plotting and presentation (5)

| Path | Type | Entry point | Notes |
|---|---|---|---|
| `data/align3d_axis_labels.m` | MATLAB source | `align3d_axis_labels` | Center X/Y/Z labels along their axes, rotate to be parallel to each axis, and place them slightly OUTSIDE the plot box. Use orthographic for |
| `data/align3d_axis_labels_outside.m` | MATLAB source | `align3d_axis_labels_outside` | Parallel to the visible axis lines, centered, and nudged outside the box. Limits, midpoints, ranges outward offsets in data units |
| `data/plotOverimposeSignals.m` | MATLAB source | `script` | reusable project function or helper (review required) |
| `data/plotPersistance.m` | MATLAB source | `plotPersistance` | reusable project function or helper (review required) |
| `data/plotWignerDistribution.m` | MATLAB source | `script` | reusable project function or helper (review required) |

### Signal processing and filtering (29)

| Path | Type | Entry point | Notes |
|---|---|---|---|
| `data/backfilter.m` | MATLAB source | `backfilter` | funcion que calcula el filtro forward-backwards filtro_b = tf(a,b,1,'Variable','z'); filtro_ss_b = ss(filtro_b); |
| `data/calculateSignalUndershoot.m` | MATLAB source | `calculateSignalUndershoot` | This function returns the undershoot of the signal defined as peak of the undershoot/peak_value signal pedestal |
| `data/fbk_tf_analisis.m` | MATLAB source | `script` | This script tries to eliminate zeros and poles causing numerical issues when combining the transfer functions compensator_daphne = tf(zpk([d |
| `data/fbk_tf_analisis_carlas_setup.m` | MATLAB source | `script` | This script tries to eliminate zeros and poles causing undershoot in Carla's setup for HPK SiPMs compensator_coldamp = tf(zpk([polos(1) polo |
| `data/fourier_z_transform.m` | MATLAB source | `fourier_z_transform` | reusable project function or helper (review required) |
| `data/general_tf_estimation_pds_algorithm.m` | MATLAB source | `script` | algoritmo para identificar la funcion de transferencia Esteban Javier Cristaldo Morales clear all |
| `data/gradient_descent_tf_estimator_test.m` | MATLAB source | `errorEstimation` | Script de prueba del metodo de descenso de la gradiente para estimar la funcion de transferencia conociendo los vectores de entrada y de sal |
| `data/gradient_descent_tf_estimator_test_2.m` | MATLAB source | `errorEstimation` | Script de prueba del metodo de descenso de la gradiente para estimar la funcion de transferencia conociendo los vectores de entrada y de sal |
| `data/gradient_descent_tf_estimator_test_3.m` | MATLAB source | `estimateMSE` | Este script implementa la ecuacion en el libro "System identification for users" d L Ljung en la seccion 1.3 El problema arquetipo De nuevo  |
| `data/hpk_tf_analisis_carlas_setup.m` | MATLAB source | `script` | This script tries to eliminate zeros and poles causing undershoot in Carla's setup for HPK SiPMs data_test = data_muon(floor(rand(1,1)*end), |
| `data/mi_dft.m` | MATLAB source | `mi_dft` | delta_f = fs/(num_samples); |
| `data/mi_fcdft.m` | MATLAB source | `mi_fcdft` | delta_f = fs/(num_samples); |
| `data/mi_fdft.m` | MATLAB source | `mi_fdft` | reusable project function or helper (review required) |
| `data/mi_wiener_deconv.m` | MATLAB source | `mi_wiener_deconv` | g_wiener = (conj_p_tf)./(abs_p_tf + 15000); |
| `data/noise_transfer_function_estimation.m` | MATLAB source | `script` | this script calculate the power spectral density of DAPHNE to make a estimation of the noise transfer function. window_f = hanning(4096); |
| `data/radon_transform_frac_fourier.m` | MATLAB source | `script` | radon transform vars1 = load('C:\Users\e_cri\OneDrive\Documents\PhD\Investigacion\MATLAB\sim_cold_amp\transfer_function_estimation\fractiona |
| `data/test_active_filters.m` | MATLAB source | `script` | Filtro Butterworth Filtro chebyschev |
| `data/test_avg_wiener-MSI-ESTEBAN-CRISTALDO.m` | MATLAB source | `script` | noise_rand = detrend(daphne_noise_fbk_int_off(end+1-i,:)); noise = filter(tf_integrator_hpk.Numerator,tf_integrator_hpk.Denominator,noise);  |
| `data/test_avg_wiener.m` | MATLAB source | `script` | tf_local = tf_input_output_d*sim2daphne_tf_int_off; signal = single_pe_output_estimated_int_off; ppm = ParforProgressbar(N); |
| `data/test_fractional_fourier_filter.m` | MATLAB source | `script` | [tf_system1] = mi_idtft(p1); [tf_system2] = mi_idtft(p2); input_test_2 = single_pe_input_int_off + circshift(single_pe_input_int_off,150) +  |
| `data/test_fractional_fourier_filter_decimated.m` | MATLAB source | `script` | input_test_2 = single_pe_input_int_off + circshift(single_pe_input_int_off,150) + circshift(single_pe_input_int_off,350); input_test_2 = max |
| `data/test_fractional_pedestal_filter.m` | MATLAB source | `script` | script donde se filtra el pretrigger en varios planos con la transformada fraccional de fourier Calculo de las tranformadas desde a=0.95 - a |
| `data/testscripts/test_dft.m` | MATLAB source | `script` | script to test the fft scripts The scripts seems to work ok |
| `data/testscripts/test_fir_wiener.m` | MATLAB source | `script` | tf_local = tf_input_output_d*sim2daphne_tf_int_off; |
| `data/testscripts/test_irr_wiener.m` | MATLAB source | `script` | tf_local = tf_input_output_d*sim2daphne_tf_int_off; Noise model %%%%%%%%% |
| `data/testscripts/test_irr_wiener_symbolic.m` | MATLAB source | `script` | tf_local = tf_input_output_d*sim2daphne_tf_int_off; Noise model %%%%%%%%% |
| `data/tf_op_amp_comparisson.m` | MATLAB source | `script` | experiment/prototype or workflow (review required) |
| `data/wiener_deconvolve.m` | MATLAB source | `wiener_deconvolve` | Calculate the length of the signal and transfer function Calculate the power spectral density of the noise Calculate the frequency response  |
| `data/wienerFilt.m` | MATLAB source | `wienerFilt` | % Wiener filter based on Wiener-Hopf equations This function takes as inputs a noisy signal, x, and a reference signal, y, in order to compu |

### Tests and experiments (3)

| Path | Type | Entry point | Notes |
|---|---|---|---|
| `data/cb_teststand_led.m` | MATLAB source | `script` | reusable project function or helper (review required) |
| `data/test_weiner.m` | MATLAB source | `plot_fourier` | signal = daphne_output_simulated; Perform the Weiner deconvolution to remove the effect of the transfer function Compare the original signal |
| `data/trigger_tests_ROC_analisis.m` | MATLAB source | `script` | analisis de los tres archivos ROC close all roc_data_bicocca = load('BICOCCA\RUN2\roc_file2.mat').roc_data; |

### Utilities / review required (30)

| Path | Type | Entry point | Notes |
|---|---|---|---|
| `data/analize_data_CAEN.m` | MATLAB source | `script` | load(strcat('channel_',num2str(ch),'.mat')) data = data; Tm = Tm; |
| `data/analyze_roc_data_selftrigger.m` | MATLAB source | `analyze_roc_data_selftrigger` | experiment/prototype or workflow (review required) |
| `data/calculate_trigger_cfd.m` | MATLAB source | `calculate_trigger_cfd` | this function calculates the trigger from the filtered signal and cfd highpass filter [num_f,den_f] = butter(2,0.1e6/(62.5e6/2),'high'); |
| `data/calculate_trigger_position.m` | MATLAB source | `calculate_trigger_position` | this function calculates the position of trigger events |
| `data/calculateTriggerPositionsWithWindow.m` | MATLAB source | `calculateTriggerPositionsWithWindow` | this function returns the triggers position inside a given window use this function to analyze simulations data of the trigger module with t |
| `data/chooseOption.m` | MATLAB source | `NP04_endpoint2idx` | reusable project function or helper (review required) |
| `data/correct_ROC_data_trigger_analysis.m` | MATLAB source | `script` | correct roc data |
| `data/double2binary_coefficients.m` | MATLAB source | `double2binary_coefficients` | reusable project function or helper (review required) |
| `data/downsample_data.m` | MATLAB source | `downsample_data` | Antialias filter %%%%%%%%%%%%%% |
| `data/export_matlab_script_dependencies.m` | MATLAB source | `script` | Entry point (.m exported from your live script) Destination folder Collision-safe naming (in case two different folders contain the same foo |
| `data/float2bin.m` | MATLAB source | `float2bin` | This function converts a floating point number to a binary string. %Input: f - floating point number, either double or single Output: b - st |
| `data/generate_hg.m` | MATLAB source | `generate_hg` | reusable project function or helper (review required) |
| `data/generate_hg_h.m` | MATLAB source | `generate_hg_h` | reusable project function or helper (review required) |
| `data/generate_HV_matrices.m` | MATLAB source | `generate_HV_matrices` | Matriz H if(is_even ~= 0) Matriz V |
| `data/generateFractionalZeroCompensator.m` | MATLAB source | `generateFractionalZeroCompensator` | This script generates a fractional zero compensator FIR coefficients The non_mp_zero_index is the index of the non minimun phase zero First  |
| `data/get_dat_paths.m` | MATLAB source | `get_dat_paths` | GET_DAT_PATHS Return all matches across runs (string array). % Example: paths = get_dat_paths(file_dir, 1330, "40p", 104, 12); |
| `data/getDataFromWafflesPickleFile.m` | MATLAB source | `getDataFromWafflesPickleFile` | reusable project function or helper (review required) |
| `data/getProminentMaximums.m` | MATLAB source | `getProminentMaximums` | reusable project function or helper (review required) |
| `data/mi_idtft.m` | MATLAB source | `mi_idtft` | reusable project function or helper (review required) |
| `data/moving_median.m` | MATLAB source | `moving_median` | MOVING_MEDIAN Centered moving-median smoothing. y_med = MOVING_MEDIAN(y, win) y   : vector (row or column) |
| `data/myfiltfilt.m` | MATLAB source | `myfiltfilt` | funcion que calcula el filtro forward-backwards F_b = filtro_ss_b.A; G_b = filtro_ss_b.B; |
| `data/myfiltfilt2.m` | MATLAB source | `myfiltfilt2` | funcion que calcula el filtro forward-backwards filtro_ss_b = ss(filtro_b); F_b = filtro_ss_b.A; |
| `data/noiseGenerator.m` | MATLAB source | `noiseGenerator` | reusable project function or helper (review required) |
| `data/noiseGeneratorFromFile.m` | MATLAB source | `noiseGeneratorFromFile` | reusable project function or helper (review required) |
| `data/numberAsPow2.m` | MATLAB source | `numberAsPow2` | reusable project function or helper (review required) |
| `data/parseXML.m` | MATLAB source | `parseXML` | PARSEXML Convert XML file to a MATLAB structure. Recurse over child nodes. This could run into problems with very deeply nested trees. |
| `data/ROC_file_analysis.m` | MATLAB source | `ROC_file_analysis` | pauc = pauc + trapz(fpr(1:min_fpr_pos),tpr(1:min_fpr_pos)); plot(threshold(1:end-1),diff(acc)) |
| `data/sinple_pe_input_estimator.m` | MATLAB source | `script` | This script takes the fitted DAPHNE waveforms and calculates the impulse from the simulations necesary to obtain a single PE waveform. |
| `data/xmltools.m` | MATLAB source | `xmltools` | XMLTOOLS - tools for managing xml data sets - if arg is a string : arg is an XML file to convert into MATLAB struct - if arg is a variable : |
| `data/zo_ths4531.m` | MATLAB source | `script` | calculo de la impedancia de salida del THS4531 a partir de los datos del datasheet |

## Recommended manual-review order

1. `Live_scripts/analysis_daphne_data.mlx`: establish exact purpose, inputs, steps, outputs, and required helper functions.
2. Import chain: `import_data_daphne*`, `import_daphne_data_mult_waveforms`, `extract_and_import_DAPHNE_data`, and associated binary/NPY readers.
3. DAPHNE/NP04 mappings and run/path helpers: `NP04_*`, `build_NP04_file_dir`, `get_dat_paths`, and `get_NP04_channel_numbers`.
4. Matched-filter and Wiener/filter family: identify the authoritative implementation and distinguish prototypes from production code.
5. VGAIN/NP04 Live Script family and `analysis_daphne_data_vgain_scan_np04_final.m`: determine relationship and current authoritative workflow.
6. Calibrations/data artifacts: identify provenance and whether they are inputs, outputs, or fixtures.

## Machine-readable companion

`function_index.csv` contains the raw first-pass fields, including SHA-backed path inventory in `manifest.csv`.
