---
title: pds.simulation.simulatePedestalStressWaveforms
type: function
status: software-audited
tags: [simulation, pedestal, truth, iir, noise]
repo_path: src/+pds/+simulation/simulatePedestalStressWaveforms.m
---

[Código fuente MATLAB](../../src/+pds/+simulation/simulatePedestalStressWaveforms.m)

Composes independent event rows in double on a long parent trace, filters event
components, adds baseline and continuous noise, then crops. Optional clipping is
last. Uses [`generateEventTrain`](generateEventTrain.md) and [`generateColoredNoise`](generateColoredNoise.md). Progress:
`docs/status/pedestal-estimation-refactor-status.md`. Configuration-specific example and caveats:
`docs/validation/task13-fbk-vgain1700.md`.

## Signature and executable synthetic example

```matlab
addpath('src');
[w,t] = pds.simulation.simulatePedestalStressWaveforms([],16e-9, ...
    ResponseNumerator=[1 -1], ResponseDenominator=[1 -.9], ...
    OnePeAmplitude=40, BaselineOffset=6000, Seed=17);
assert(isequal(size(w),[1 2048]));
assert(isequal(t.preAdc,t.components.baseline+t.components.reference+ ...
    t.components.dark+t.components.largeEvent+t.components.noise));
```

Here 40 and 6000 are synthetic chosen amplitudes, NOT DAPHNE calibration values.
`sampleCount=[]` selects 2048; `samplePeriod` in seconds is mandatory. Both scalar
inputs otherwise require finite positive values; sample count is an integer.
Output shape is `EventCount × sampleCount`. Numeric integer inputs are validated
then converted to double; int64/uint64 values outside ±flintmax are rejected.
Sparse and complex inputs are rejected on the simulator's numeric surface.

## Response, geometry, and resource options

| Name | Default | Contract |
|---|---|---|
| `ResponseNumerator` | required | Finite nonzero real coefficient vector in causal `z^-1` filter convention |
| `ResponseDenominator` | 1 | Finite real vector, nonzero lead; all poles strictly within unit circle |
| `OnePeAmplitude` | required | Positive finite amplitude in configured waveform units; separate from temporal shape |
| `EventCount` | 1 | Positive integer number of independent parent traces |
| `PretriggerSampleCount` | floor(N/2) | Integer samples before event reference in final crop |
| `PedestalSampleCount` | 100 | Positive integer, independent of reference index |
| `PedestalGuardSampleCount` | 0 | Nonnegative integer; shifts pedestal earlier without changing length |
| `BurnInSampleCount` | auto | Nonnegative integer at least validated impulse horizon minus one |
| `ResponseTolerance` | 1e-3 | Strictly between zero and one |
| `MaximumParentSampleCount` | 1e6 | Positive integer bound across parent samples × event rows; also bounds expected dark+large arrivals |

If pretrigger=P, guard=G and pedestal length=L, pedestal indices are
`P-G-L+1:P-G`, and event reference is `P+1`. Require `L+G<=P<N`.
Parent length is `2*(burnIn+max(P,N-P-1))+1`; its reference is at the center.
The crop has at least `burnIn` samples of prior history even for asymmetric crops.

Response coefficients are divided by the maximum absolute impulse amplitude,
preserving polarity. `OnePeAmplitude` therefore specifies magnitude, not a forced
positive peak for arbitrary negative-polarity responses. The response peak index
is the first absolute maximum and is distinct from the impulse/reference index;
it may lie outside the delivered crop. This is a linear time-invariant model.
The use of a population mean for individual-event shape assumes suitable alignment,
linearity, and no material saturation/selection distortion.

For an IIR, the initial impulse horizon is based on pole radius, tolerance with a
1e-3 safety factor, numerator length and denominator order. It doubles until the
last quarter's maximum absolute response relative to the peak is below tolerance.
The caller cannot shorten burn-in below this horizon. This is a conservative
numerical settling check, not a proof of physical tail behavior or a bound on
aggregate Poisson tail contamination. FIR uses its supplied finite support.
Resource checks bound parent array sizes and expected arrivals, not the
unbounded realized Poisson count nor every MATLAB temporary allocation.

## Events and injection

`EventOptions` defaults to `struct()`. Only exact names from this allowlist are
accepted: `SignalMultiplicityDistribution`, `SignalMultiplicity`,
`SignalMultiplicityLambda`, `SignalMultiplicitySupport`, `SignalMultiplicityPmf`,
`DarkRateHz`, `LargeEventRateHz`, `LargeAmplitudeDistribution`, `LargeAmplitude`,
`LargeAmplitudeRange`. Their domains and defaults are those of
[`generateEventTrain`](generateEventTrain.md). Default signal multiplicity is one and both other rates
are zero. Use `SignalMultiplicity=0` for no reference impulse.

`EventCount`, `ReferenceIndex`, `ReferenceAmplitude`, `Seed`, `RandomStream`, and
`SaturationRange` cannot be supplied inside `EventOptions`. Reference and dark
amplitudes use the same explicit `OnePeAmplitude`; large-event amplitude is in
waveform units, NOT PE. Enabling a positive large rate requires an explicit
`LargeAmplitude` (fixed) or `LargeAmplitudeRange` (uniform).

Optional `InjectedEvents=[]` consists of `[row parentSample class amplitude]`
rows, with class 1=dark, 2=large. Indices are one-based integers; amplitudes must be
positive, and dark amplitude exactly equals `OnePeAmplitude`. Nonempty injections
require nonblank scalar `InjectedEventProvenance` (default empty string). They
are deterministic additions for designed scenarios, not replacements for a
Poisson process. Coincident additions accumulate in double. They remain separate
from generated `eventTruth` lists, and are included in parent impulses, filtered
components, arrival masks and contamination flags.

## Baseline scenarios

`BaselineOffset=0` is a finite scalar. `BaselineMode="constant"` by default.
All mode-specific options default to `[]`; supplying a parameter for another mode
is rejected. Parameters for the selected nonconstant mode must be explicit.

- `constant`: offset on every parent sample.
- `slope`: `BaselineSlopePerSample`, finite signed units/sample. Offset is the
  baseline at the parent reference, with linear drift on both sides.
- `step`: finite signed `BaselineStepAmplitude` and integer
  `BaselineStepOffsetSamples` relative to the parent reference. The step index
  must be inside the parent, and the amplitude is added from that sample onward.
- `wander`: positive `BaselineWanderStepRms`; Gaussian random-walk increments.
  Parent sample 1 equals offset. This is nonstationary, NOT a measured frontend
  spectrum; its crop variance depends on parent length.

`pedestalBaselineMean` and `baselineAtReference` are separate estimands. The former
is the mean of the actual baseline component in the pedestal region, not the mean
of a potentially contaminated observed waveform.

## Noise and RNG

`NoisePsd=[]` means no continuous noise. Nonempty PSD must contain exactly the
PARENT sample count in nonnegative bilateral FFT-ordered bins, in waveform-unit²/Hz,
with Hermitian symmetry. There is no implicit interpolation or physical PSD.
A geometry-only call with identical response/count settings can obtain the required
parent length. Supply PSD on that grid in a second call.

`NoiseRms=[]` preserves absolute supplied PSD scaling. A positive finite NoiseRms
rescales EACH entire parent realization to that RMS; the crop RMS need not equal
it. Noise is generated on the full parent before cropping, not generated directly
on the final N samples. See `noiseDiagnostics` for realization and normalization.
A PSD estimated from pretrigger may include dark/external noise and is not
necessarily pure electronics noise. Do not transfer it across VGAIN/frontends.

`Seed=[]` and `RandomStream=[]` are exclusive. With neither, a local mt19937ar
seed 0 is used. An explicit seed is an integer in [0,2^32-1]. RandomStream must be
a local scalar RandStream; the global stream handle is rejected. A private clone
preserves generator type, stream/substream, state, normal transform, antithetic and
precision settings. Only after all composition and validation succeeds is its
final state committed to the supplied stream. Failed calls leave that stream
unchanged; some late validation may perform work on the private clone first.
No global RNG mutation occurs. Draw order is events → wander → continuous noise.

## ADC and arithmetic

`SaturationRange=[]` leaves values unchanged, including values above 2^14.
An explicit finite increasing `[lower upper]` clips after composition. This is NOT
quantization, encoding, rounding, or a hardware ADC model. Pre-saturation numeric
overflow is an error; clipping never conceals Inf/NaN. Both outputs remain double.

## Truth schema

- Geometry: `referenceIndex`, `parentReferenceIndex`, `parentSampleCount`,
  `cropIndices`, `pedestalIndices`, `burnInSampleCount`, `responsePeakIndex`,
  `parentResponsePeakIndex`.
- Baseline estimands: `pedestalBaselineMean`, `baselineAtReference`.
- `response`: normalized `numerator`, `denominator`, `impulse`, pre-normalization
  `peakMagnitude`, impulse `peakIndex`, `poles`, `poleRadius`,
  `terminalRelativePeak`, `tolerance`.
- `components`: cropped `baseline`, `reference`, `dark`, `largeEvent`, `noise`.
- `parent.components`: same fields on full parent; `parent.impulses` and
  `parent.arrivalMasks` for reference/dark/largeEvent.
- `arrivalMasks`: cropped impulse arrivals, NOT response-tail masks.
- `pedestalContamination`: per-row reference/dark/largeEvent flags when the net
  absolute component on any pedestal sample exceeds
  `OnePeAmplitude*ResponseTolerance`. Superposition/cancellation can affect these
  flags; they are not eventwise purity guarantees.
- `filterStates`: reference/dark/largeEvent, each with `initial`, `atCrop`, `final`
  arrays of shape event rows × filter order. Initial state is zero before burn-in.
- `eventTruth`: generated process truth from [`generateEventTrain`](generateEventTrain.md), with dark
  amplitudes/components rescaled into configured waveform units. Its lists do not
  contain deterministic injections; `injectedEvents` and
  `injectedEventProvenance` record those separately.
- `preAdc`, `postAdc`, `saturationMask`, `saturationRange`.
- `noiseDiagnostics`: empty struct without noise; otherwise generator diagnostics
  refer to the parent, with crop noise separately in `components.noise`.
- `random`: source, seed, type, initial/final state, settings, normal transform,
  antithetic and fullPrecision. `configuration`: requested options except the
  mutable RandomStream handle, plus resolved SampleCount and SamplePeriod;
  resolved automatic geometry is in the explicit truth fields above.

Exact reconstruction applies to `preAdc` in this arithmetic order:
`baseline + reference + dark + largeEvent + noise`. Output equals `postAdc`.

## Validation evidence

`tests/TestSimulatePedestalStressWaveforms.m`: 14 tests passed, zero failed or
incomplete after the QUALITY-13-1 fix. Focused evidence: `17-quality-green.log`.
Parent standard suite: `18-quality-full-suite.log`, 173/173 with checkcode zero
on source and tests, MATLAB R2025b Update 3. Logs are under
`outputs/validation/task13-core/`. Two deprecation warnings are
from the existing legacy compatibility test, not this simulator.

TDD logs preserve inherited cycles 01–03, resumed cycle 04 and new cycles 05–13.
`04-green-resumed.log` contains a failed attempt, followed by passing
`04-green-fixed.log`; `05-red.log` is a syntax failure, not behavioral RED;
`05-red-valid.log` is the valid RED. Final test-only cleanup and stronger asymmetric
noise crop were verified by the parent confirmation, not credited to the earlier
subagent run. A subsequent independent quality review found QUALITY-13-1:
nonfinite generated-event truth could escape checks when a negative baseline
cancelled the overflow in the delivered waveform. A new regression first failed
(`16-quality-red.log`), then `requireFinite(events)` rejected the overflow before
stream commit (`17-quality-green.log`). The regression checks both caller stream
and global RNG preservation. The new full suite and four-case integration passed;
independent re-review of these changed bytes approved SPEC preservation and QUALITY.
See `docs/status/task13-audit-closure.md` for the exact G2 manifest, certificate and the
subsequent documentation-only closure (not part of the audited bytes).
