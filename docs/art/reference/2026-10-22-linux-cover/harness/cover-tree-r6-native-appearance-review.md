# R6 native cover appearance review

All three original tree plates were viewed at native960×540. Actual run is
clean exit0/diagnostics0/manifest failures0, bound to tool00f7eba6. That clean
execution is not visual acceptance.

No source ordering bug was found: kit−2 + tree1 gives−1; real pickup Icon5
and proxy-root10/batch0 are above that canopy. The shared shader changes RGB
and alpha, without lowering their draw order. It is also the player compositor.
A locked ring first inherits alpha0.55, then full coverage multiplies by0.56,
giving nominal alpha0.308. About69% of the canopy background consequently
remains in the resulting RGB. Its sampled green pixels are compatible with
correct quiet-icon blending; they do not establish later canopy occlusion.

The covered ring at(-168,6616) is very difficult to recognize at native size
against the busy leaves; this review cannot call its outline clearly readable.
Health at(-56,6752) legitimately straddles the canopy edge: covered portions
are muted, while source-visible uncovered lower pixels stay bright pink.
Player front/behind/front and the real moving enemy transition are retained,
but their material/fragment counters do not supply a contrast oracle.

The isolated pickup native fixture uses solid gray leaves and a saturated
synthetic icon. Its locked-alpha check deliberately expects extra backdrop
show-through, so it cannot resolve this small real-item readability question.
No same-frame icon-on/off native reference exists to isolate exact contrast.
Root visual acceptance remains withheld; no runtime change is proposed or made
by this read-only review. Source/actual RGB samples and hashes of the three
unchanged original plates are recorded in the adjacent JSON.
