"""Audit calibration NPZs against their manifest; requires NumPy, no DAQ stack.

Usage: python tools/inspect_daq_npz.py DATA_DIRECTORY OUTPUT_DIRECTORY
Writes a per-step CSV and a JSON summary; never modifies acquisitions.
"""

import argparse
from collections import Counter
import csv
import hashlib
import json
from pathlib import Path

import numpy as np


def inspect_step(path, entry):
    with path.open('rb') as stream:
        digest = hashlib.file_digest(stream, 'sha256').hexdigest()
    if path.stat().st_size != entry['bytes'] or digest != entry['sha256']:
        raise ValueError(f'{path.name}: manifest size/SHA256 mismatch')
    with np.load(path, allow_pickle=False) as z:
        a, channels, ticks = z['adc'], z['channels'], z['timestamps']
        meta = json.loads(z['metadata_json'].item())
        r = meta['receipt']
        if (r['schema'], r['frame_version'], r['samples_per_frame'],
            r['adc_bits'], r['clock_hz'], r['channel_namespace']) != (
                'pds.calibration.step.v1', 4, 256, 14, 62500000, 'legacy_FPGA'):
            raise ValueError(f'{path.name}: unsupported schema')
        if a.dtype != np.uint16 or a.shape != (len(channels), 256):
            raise ValueError(f'{path.name}: invalid ADC array')
        for name, dtype in [('channels', np.uint8), ('timestamps', np.uint64),
                            ('stream_ids', np.uint8), ('timing_tags', np.uint8),
                            ('continuation', np.bool_)]:
            if z[name].dtype != dtype or z[name].shape != (len(a),):
                raise ValueError(f'{path.name}: invalid {name}')
        ids, counts = np.unique(channels, return_counts=True)
        observed = {str(int(c)): int(n) for c, n in zip(ids, counts)}
        if observed != entry['counts'] or observed != r['received_counts']:
            raise ValueError(f'{path.name}: channel counts disagree')
        if sorted(map(int, observed)) != sorted(r['channels']):
            raise ValueError(f'{path.name}: channel IDs disagree')
        if entry['label'] != r['label'] or entry['source_sha256'] != r['sha256']:
            raise ValueError(f'{path.name}: receipt disagrees with manifest')
        if int(a.max()) > 16383:
            raise ValueError(f'{path.name}: ADC exceeds 14 bits')
        rows = []
        for channel in ids:
            mask = channels == channel
            adc, ts = a[mask], ticks[mask]
            if np.any(ts[1:] < ts[:-1]):
                raise ValueError(f'{path.name}: decreasing timestamps')
            delta = np.diff(ts)
            # Diagnostics only: first 32 samples are not a validated pedestal region.
            baseline = np.median(adc[:, :32], axis=1)
            average = adc.mean(axis=0) - baseline.mean()
            rows.append(dict(
                file=path.name, step_id=r['step_id'], label=r['label'],
                role=r['role'], vgain=r['coordinates'].get('vgain'),
                led_bias=r['coordinates'].get('led_bias_270nm'),
                channel=int(channel),
                module=meta['module_by_firmware_channel'][str(channel)],
                panel_channel=r['firmware_to_panel'][str(channel)],
                offset=r['coordinates'].get('offset_by_native_channel', {}).get(str(channel)),
                waveforms=len(adc), samples=adc.shape[1], adc_min=int(adc.min()),
                adc_max=int(adc.max()), rail_sample_fraction=float(np.mean((adc == 0) | (adc == 16383))),
                rail_waveform_fraction=float(np.mean(np.any((adc == 0) | (adc == 16383), axis=1))),
                timestamp_first=int(ts[0]), timestamp_last=int(ts[-1]),
                period_ticks=r['period_ticks'],
                nonnominal_intervals=int(np.count_nonzero(delta != r['period_ticks'])),
                duplicate_timestamps=int(np.count_nonzero(delta == 0)),
                stream_ids=';'.join(map(str, np.unique(z['stream_ids'][mask]))),
                timing_tags=';'.join(map(str, np.unique(z['timing_tags'][mask]))),
                continuation_count=int(np.count_nonzero(z['continuation'][mask])),
                diagnostic_baseline32_median=float(np.median(baseline)),
                diagnostic_mean_min=float(average.min()),
                diagnostic_mean_min_sample=int(average.argmin()+1),
                diagnostic_mean_max=float(average.max()),
                diagnostic_mean_max_sample=int(average.argmax()+1),
            ))
        return rows, r


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('data_directory', type=Path)
    parser.add_argument('output_directory', type=Path)
    args = parser.parse_args()
    entries = json.loads((args.data_directory / 'manifest.json').read_text())
    names = [entry['file'] for entry in entries]
    if len(names) != len(set(names)):
        raise ValueError('Duplicate manifest filenames')
    if set(names) != {p.name for p in args.data_directory.glob('*.npz')}:
        raise ValueError('NPZ files disagree with manifest')
    rows, roles, gains, labels, failures = [], Counter(), set(), Counter(), []
    for i, entry in enumerate(entries):
        try:
            step_rows, receipt = inspect_step(args.data_directory / entry['file'], entry)
            rows.extend(step_rows)
            roles[receipt['role']] += 1
            gains.add(receipt['coordinates'].get('vgain'))
            labels[receipt['label']] += 1
        except Exception as exc:
            failures.append(dict(file=entry['file'], error=str(exc)))
        if (i+1) % 25 == 0 or i+1 == len(entries):
            print(f'Inspected {i+1}/{len(entries)}; failures={len(failures)}', flush=True)
    summary = dict(
        data_directory=str(args.data_directory.resolve()), files=len(entries),
        bytes=sum(e['bytes'] for e in entries), validated_files=len(entries)-len(failures),
        roles=dict(roles), vgain_values=sorted(g for g in gains if g is not None),
        repeated_labels={k: v for k, v in labels.items() if v > 1},
        waveforms=sum(r['waveforms'] for r in rows),
        samples=sum(r['waveforms']*r['samples'] for r in rows),
        channels=sorted({r['channel'] for r in rows}),
        nonnominal_intervals=sum(r['nonnominal_intervals'] for r in rows),
        duplicate_timestamps=sum(r['duplicate_timestamps'] for r in rows),
        continuation_count=sum(r['continuation_count'] for r in rows),
        maximum_rail_waveform_fraction=max((r['rail_waveform_fraction'] for r in rows), default=None),
        failures=failures,
        timestamp_note='CSV timestamps are exact integer ticks; import as uint64 or text, not double.',
        diagnostic_note='baseline32 and average extrema are exploratory, not a validated pedestal or pulse window.',
    )
    args.output_directory.mkdir(parents=True, exist_ok=True)
    if rows:
        with (args.output_directory / 'steps.csv').open('w', newline='', encoding='utf-8') as stream:
            writer = csv.DictWriter(stream, fieldnames=list(rows[0]))
            writer.writeheader()
            writer.writerows(rows)
    (args.output_directory / 'summary.json').write_text(json.dumps(summary, indent=2), encoding='utf-8')
    print(json.dumps(summary, indent=2))
    if failures:
        raise SystemExit(1)


if __name__ == '__main__':
    main()
