# CI dependency model

The root Dioptase repository is the integration manifest for the project. Its
Git submodule entries pin one compatible commit of each component. Root
`software-ci.yml` jobs initialize only the submodules needed by that job and
run the owning submodule's CI script.

The standalone assembler workflow is self-contained. Both emulators require
the assembler to generate instruction-test inputs, the compiler requires the
assembler and both emulators, and the OS requires the assembler, compiler, and
full emulator. Their standalone workflows first check out an immutable root
commit, initialize the dependencies recorded by that commit, and then check out
the pull request component over its uninitialized submodule path. This tests a
known-good dependency stack with exactly one component replaced by the proposed
change.

Each dependent repository defines `DIOPTASE_STACK_REF` with a known-good full
root commit SHA. A repository-level Actions variable with the same name may
advance that baseline without editing the workflow, but it must also contain a
full 40-character commit SHA. Branch and tag names are rejected so dependency
versions cannot change between otherwise identical CI runs.

For a coordinated change across repositories:

1. Publish the component branches.
2. Create a root repository branch that updates all affected submodule
   pointers.
3. Run root `Software CI` against that branch.
4. Merge the component changes and then the tested root pointer update.
5. Advance each dependent subrepo's `DIOPTASE_STACK_REF` variable to the new
   tested root commit when it should become the standalone CI baseline.

Caches may reduce compilation time, but cache keys must include the relevant
lockfile and pinned component commits. Cached output is never used to decide
which dependency version to test.
