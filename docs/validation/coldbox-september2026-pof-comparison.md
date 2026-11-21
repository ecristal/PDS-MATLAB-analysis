---
type: validation-report
status: validated-runtime
workflow: coldbox-september2026-pof-shaping-v1
dataset: ColdBox-September2026-PoF-M3-M6
tags: [daphne, coldbox, pof, gaussian-fit, snr]
---

# ColdBox September 2026: PoF configuration comparison

## Scope

The analysis covers the four available directories under `PoF_data`: `PoF_OFF`, `PoF_OLD`, `PoF_NEW`, and `PoF_ALL`.

- M3: DAPHNE channels 8 and 9 in all four configurations.
- M6: DAPHNE channels 20 and 21 in `PoF_OLD`, `PoF_NEW`, and `PoF_ALL`.
- `PoF_OFF` contains no M6 directory or archives. Those two cases are represented as unavailable data, not as zero SNR.

Every available archive contains 30,000 waveforms with 1,024 samples at 62.5 MHz. VGAIN is 500 in all cases; the recorded VBIAS codes are 810 for M3 and 0 for M6.

## Processing contract

The fixed processing contract is:

1. 15--85% RMS cut;
2. per-waveform pedestal calculated exclusively as the mean of samples `1:100`;
3. 15--85% pedestal cut;
4. pedestal subtraction;
5. third-order 2 MHz Butterworth low-pass for M3;
6. no low-pass for M6;
7. the same IIR integrator and HPK moving-mean stages for both modules;
8. amplitude score from three samples around the maximum of the mean processed waveform;
9. common bin-width sweep `0.02:0.01:0.05`;
10. normalization by the second peak;
11. `SNR = (mu1-mu0)/sigma0`.

The six-component multi-Gaussian fit was valid in 12/14 cases. For `PoF_OLD M6 CH2` and `PoF_NEW M6 CH2`, that global curve described the higher-photoelectron populations poorly even though the 0-PE and 1-PE populations were visibly distinct. The same local Gaussian procedure was therefore used in both cases, with fixed normalized windows `[-0.45, 0.45]` and `[0.60, 1.40]`. No channel-specific window tuning was used.

Local-fit quality:

- `PoF_OLD M6 CH2`: combined R² 0.950490; pedestal R² 0.932260; 1-PE R² 0.966853.
- `PoF_NEW M6 CH2`: combined R² 0.935534; pedestal R² 0.929985; 1-PE R² 0.931704.

All 14 available channel/configuration cases therefore have valid 0-PE and 1-PE fits.

## SNR by channel

| Configuration | M3 CH1 | M3 CH2 | M6 CH1 | M6 CH2 |
|---|---:|---:|---:|---:|
| PoF_OFF | 4.191467 | 5.130256 | unavailable | unavailable |
| PoF_OLD | 4.073954 | 4.128426 | 5.615760 | 5.075024 |
| PoF_NEW | 4.291179 | 4.396085 | 5.338000 | 3.743873 |
| PoF_ALL | 4.942583 | 4.466218 | 5.139942 | 5.879334 |

## Descriptive module means

The means below use both channels when available. They are descriptive summaries, not uncertainty-weighted combinations.

| Configuration | M3 mean SNR | Change from PoF_OFF | M6 mean SNR | Change from PoF_OLD |
|---|---:|---:|---:|---:|
| PoF_OFF | 4.660861 | reference | unavailable | unavailable |
| PoF_OLD | 4.101190 | -12.01% | 5.345392 | reference |
| PoF_NEW | 4.343632 | -6.81% | 4.540936 | -15.05% |
| PoF_ALL | 4.704400 | +0.93% | 5.509638 | +3.07% |

## Interpretation

There is no common monotonic SNR trend across the PoF configurations. The response is channel dependent:

- M3 CH1 relative to `PoF_OFF`: `PoF_OLD -2.80%`, `PoF_NEW +2.38%`, `PoF_ALL +17.92%`.
- M3 CH2 relative to `PoF_OFF`: `PoF_OLD -19.53%`, `PoF_NEW -14.31%`, `PoF_ALL -12.94%`.
- M6 CH1 relative to `PoF_OLD`: `PoF_NEW -4.95%`, `PoF_ALL -8.47%`.
- M6 CH2 relative to `PoF_OLD`: `PoF_NEW -26.23%`, `PoF_ALL +15.85%`.

The M3 average for `PoF_ALL` (+0.93%) hides opposite channel-level changes: CH1 increases by 17.92%, while CH2 decreases by 12.94%. M6 also shows an opposing response under `PoF_ALL`: CH1 decreases while CH2 increases.

The largest observed reduction is M6 CH2 in `PoF_NEW`, from 5.075024 to 3.743873 (-26.23%). The highest individual SNR is M6 CH2 in `PoF_ALL`, at 5.879334. For M3, the highest value is CH2 in `PoF_OFF`, at 5.130256.

These values are point estimates from acquisitions taken at different timestamps. There are no repeated acquisitions per configuration and no fit-uncertainty model. The results demonstrate observed differences but do not establish statistical significance or attribute causality solely to PoF. Time drift, external noise, and other acquisition conditions may contribute.

## Artifacts

Output directory:

`outputs/validation/coldbox-september2026-pof-comparison/`

Main artifacts:

- `snr_bar_chart.png` — SNR summary by configuration, module, and channel;
- `histograms_montage.png` — montage of all 14 histograms and fits;
- 14 individual histogram plots;
- `summary.csv` — results, hashes, parameters, and fit method;
- `snr_by_configuration.csv` — long-format bar-chart data;
- `module_summary.csv` — descriptive module means;
- `summary.mat` and `summary.md`.

Focused MATLAB R2025b evidence: 2/2 unit and integration tests passed, with 0 failures and 0 incomplete tests.