# Engineering notebook

## 2026-08-18 — One GUI configuration retains every stimulus protocol

The stimulation GUI now keeps an in-memory configuration for each protocol.
Changing protocols preserves the stimulus-specific edits for the protocol being
left, while display, TTL, session, and shared analysis settings remain common.
Saving writes the complete protocol collection to one timestamped MAT file, and
startup restores the newest collection automatically. The legacy top-level
`cfg` is retained in the file so existing single-protocol readers continue to
work; older configuration files are promoted to a one-entry collection when
loaded.

## 2026-08-12 — RF presentation geometry and quick-analysis timing

Flashed bars now use the same selected mapping rectangle as moving bars. The
orthogonal dimension spans that rectangle rather than the entire display, and
the final rectangle is clipped at all four mapping boundaries.

Moving-bar analysis now treats each Screen TTL as a sweep-onset marker only.
Within-sweep position is reconstructed from the per-frame flip timestamps and
bar centers already saved by presentation. This preserves delayed or extended
frame intervals. Old runs fall back to zero-based frame-index timing using the
measured display IFI, nominal frame rate, or finally duration divided by frame
count, and the result records that fallback.

RF preprocessing was separated from the vendored full sweep pipeline. The
visual-stim path keeps filtering, negative-artifact cleanup, drift adjustment,
and identical vendored spike detection/removal, but deliberately omits crop
tables, dataset validation, plateau/PSP processing, plateau extraction, and Vm
summary statistics.
