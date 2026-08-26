# One-shot RC2 source materialization

The temporary workflow `.github/workflows/materialize-rc2-source-20260826.yml` exists only to convert the historical TestFlight patch chain into committed release source.

It intentionally runs the same pre-finalizer sequence used by Codemagic, resolves Flutter dependencies, runs the final TestFlight finalizer, formats and validates the resulting tree, runs the full test suite, runs the finalizer a second time to prove idempotence, and commits the resulting source as:

`RC2: materialize finalized release source`

After that commit is produced and reviewed, the next step is to simplify Codemagic so it tests/builds the committed source without applying the historical source-mutating Python patch chain. Do not remove the patch chain before the materialization commit exists and passes the acceptance gates in `MATERIALIZATION_STATUS_20260826.md`.
