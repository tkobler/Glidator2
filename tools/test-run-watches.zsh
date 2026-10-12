#!/usr/bin/env zsh
# Tests for tools/run-watches.zsh, without the Connect IQ SDK.
#
# Usage: zsh tools/test-run-watches.zsh
#
# monkeyc, monkeydo, connectiq and relancer-simulateur are replaced by small
# stubs (written to a temporary directory under /tmp/glidator-build/ and put
# first in PATH) that log every call. Each case runs the real script and
# checks its output, its exit status and the sequence of calls.
#
# Stub behaviour, chosen by the watch name:
#   ok*    - two passing tests;
#   ko*    - build fails (exit 100);
#   mute*  - first test run prints nothing and hangs, later runs pass;
#   dead*  - every test run prints nothing and hangs;
#   freeze* - the test run hangs and the simulator never answers again;
#   hang*  - every test run prints one passing test, starts a second one and
#            hangs.
# The probe run (test name run_watches_probe) answers unless the file
# <state>/sim_dead exists; then every monkeydo call fails at once, as when
# the simulator is unreachable. Probe calls are counted in <state>/probes:
# the first STUB_PROBE_FAILS of them fail (simulator still starting).
# STUB_RELANCER_EXIT sets the exit status of relancer-simulateur.

emulate -L zsh
zmodload zsh/files 2>/dev/null || true

cd -- "${0:A:h}/.." || { print -u2 "cannot cd to repository root"; exit 2 }

readonly ROOT=/tmp/glidator-build/test-run-watches.$$
readonly STUBS=$ROOT/stubs
mkdir -p -- $STUBS || exit 2

n_checks=0 n_failed=0
typeset -a failed_checks

check() {   # check <description> <command...>
  local desc=$1; shift
  (( n_checks++ ))
  if "$@"; then
    print -r -- "  ok   $desc"
  else
    (( n_failed++ ))
    failed_checks+=("$case_name: $desc")
    print -r -- "  FAIL $desc"
  fi
}
contains() { [[ $1 == *"$2"* ]] }
lacks()    { [[ $1 != *"$2"* ]] }
equals()   { [[ $1 == "$2" ]] }
matches()  { [[ $1 == $~2 ]] }

write_stub() {   # write_stub <name> <body>
  print -r -- "#!/bin/zsh
state=\$STUB_STATE
$2" >| $STUBS/$1
  chmod 755 $STUBS/$1
}

write_stub monkeyc '
watch=""
while (( $# )); do [[ $1 == -d ]] && { watch=$2; shift }; shift; done
print -r -- "monkeyc $watch" >> $state/calls
[[ $watch == ko* ]] && { print "BUILD FAILED"; exit 100 }
print "BUILD SUCCESSFUL"'

write_stub monkeydo '
watch=$2 name=${4:-}
print -r -- "monkeydo $watch${name:+ $name}" >> $state/calls
if [[ -e $state/sim_dead ]]; then print "Unable to connect to the simulator"; exit 1; fi
if [[ $name == run_watches_probe ]]; then
  print -r -- probe >> $state/probes
  probes=(${(f)"$(<$state/probes)"})
  if (( ${#probes} <= ${STUB_PROBE_FAILS:-0} )); then print "Unable to connect to the simulator"; exit 1; fi
  print "Executing test run_watches_probe..."
  print "ERROR"
  print "RESULTS"
  print "run_watches_probe   ERROR"
  print "FAILED (passed=0, failed=0, errors=1)"
  exit 1
fi
case $watch in
  mute*) if [[ ! -e $state/muted.$watch ]]; then : >| $state/muted.$watch; sleep 30; fi ;;
  dead*) sleep 30 ;;
  freeze*) : >| $state/sim_dead; sleep 30 ;;
  hang*) print "Executing test testA..."; print "PASS"; print "Executing test testB..."; sleep 30 ;;
esac
print "Executing test testA..."
print "PASS"
print "Executing test testB..."
print "PASS"
print "RESULTS"
print "testA   PASS"
print "testB   PASS"
print "PASSED (passed=2, failed=0, errors=0)"
exit 1'

write_stub relancer-simulateur '
print -r -- "relancer" >> $state/calls
print "Simulateur relancé (pid 4242)."
exit ${STUB_RELANCER_EXIT:-0}'

write_stub connectiq '
print -r -- "connectiq" >> $state/calls'

# run_case <name> [VAR=value...] -- <script arguments...>
# Sets out (stdout + stderr), st (exit status) and calls (one call per line).
case_name=""
run_case() {
  case_name=$1; shift
  local -a envs
  while [[ $1 != -- ]]; do envs+=("$1"); shift; done
  shift
  local state=$ROOT/$case_name
  mkdir -p -- $state/build
  : >| $state/calls
  : >| $state/probes
  [[ -n ${SIM_DEAD-} ]] && : >| $state/sim_dead
  print -r -- "$case_name"
  out=$(env PATH="$STUBS:$PATH" STUB_STATE=$state \
        RUN_WATCHES_BUILD_DIR=$state/build RUN_WATCHES_TIMEOUT=6 \
        RUN_WATCHES_SILENT=1 RUN_WATCHES_SIM_WAIT=2 $envs \
        zsh tools/run-watches.zsh "$@" 2>&1)
  st=$?
  calls=$(<$state/calls)
}
count() {   # count <text> <line>: number of lines of <text> equal to <line>
  local -a lines=("${(@f)1}")
  REPLY=${#${(M)lines:#$2}}
}
nl=$'\n'

# --- existing calls keep working -------------------------------------------
run_case compat_default -- ok1 ok2
check "exit 0" equals $st 0
check "ok1 result line unchanged" contains "$out" "ok1: build OK, 2 tests: 2 passed, 0 failed ["
check "ok2 result line unchanged" contains "$out" "ok2: build OK, 2 tests: 2 passed, 0 failed ["
check "one restart before the lot, probe, then the tests" equals "$calls" \
  "monkeyc ok1${nl}relancer${nl}monkeydo ok1 run_watches_probe${nl}monkeydo ok1${nl}monkeyc ok2${nl}monkeydo ok2"
check "restart reported" contains "$out" "restarting simulator before lot 1/1"
check "relancer-simulateur output shown" contains "$out" "Simulateur relancé (pid 4242)."
check "answer reported" contains "$out" "simulator answered"

run_case release -- --release ok1 ok2
check "exit 0" equals $st 0
check "release line unchanged" contains "$out" "ok1: build OK (release, no test run)"
check "no restart nor monkeydo in release mode" equals "$calls" "monkeyc ok1${nl}monkeyc ok2"

# --- lots ----------------------------------------------------------------------
run_case batches -- --batch-size 2 ok1 ok2 ok3
check "exit 0" equals $st 0
check "lot headers" contains "$out" "=== lot 1/2: ok1 ok2"
check "second lot header" contains "$out" "=== lot 2/2: ok3"
check "restart before each lot, none inside a lot" equals "$calls" \
  "monkeyc ok1${nl}relancer${nl}monkeydo ok1 run_watches_probe${nl}monkeydo ok1${nl}monkeyc ok2${nl}monkeydo ok2${nl}monkeyc ok3${nl}relancer${nl}monkeydo ok3 run_watches_probe${nl}monkeydo ok3"
check "restart of lot 2 reported" contains "$out" "restarting simulator before lot 2/2"

run_case batches_equals_form -- --batch-size=2 ok1 ok2 ok3
count "$calls" relancer
check "--batch-size=N accepted: two restarts" equals $REPLY 2

run_case batches_env RUN_WATCHES_BATCH=1 -- ok1 ok2
count "$calls" relancer
check "RUN_WATCHES_BATCH=1: one restart per watch" equals $REPLY 2

run_case batch_bigger_than_list -- --batch-size 10 ok1 ok2
count "$calls" relancer
check "lot larger than the list: one restart" equals $REPLY 1
check "single lot header" contains "$out" "=== lot 1/1: ok1 ok2"

# --- build failure: the restart waits for a watch that has tests to run --------
run_case build_ko_first -- ko1 ok1
check "exit 0" equals $st 0
check "build KO line unchanged" contains "$out" "ko1: build KO (exit 100)"
check "restart after the first successful build" equals "$calls" \
  "monkeyc ko1${nl}monkeyc ok1${nl}relancer${nl}monkeydo ok1 run_watches_probe${nl}monkeydo ok1"

run_case all_builds_ko -- ko1 ko2
check "exit 0" equals $st 0
check "no restart when no test runs" equals "$calls" "monkeyc ko1${nl}monkeyc ko2"

# --- disabling the restart -------------------------------------------------------
run_case no_restart -- --no-restart --batch-size 1 ok1 ok2
check "exit 0" equals $st 0
check "--no-restart: no restart, no probe" equals "$calls" \
  "monkeyc ok1${nl}monkeydo ok1${nl}monkeyc ok2${nl}monkeydo ok2"
check "--no-restart: result lines unchanged" contains "$out" "ok2: build OK, 2 tests: 2 passed, 0 failed ["

run_case no_restart_env RUN_WATCHES_RESTART=0 -- ok1
check "RUN_WATCHES_RESTART=0: no restart, no probe" equals "$calls" "monkeyc ok1${nl}monkeydo ok1"

run_case no_restart_mute -- --no-restart mute1
check "--no-restart: silent watch reported" contains "$out" "mute1: build OK, tests SILENT (no test output after 1s)"
check "--no-restart: silent watch not retried" equals "$calls" "monkeyc mute1${nl}monkeydo mute1"

SIM_DEAD=1 run_case no_restart_unreachable -- --no-restart ok1
check "--no-restart: old fallback opens the simulator once" contains "$calls" "connectiq"
check "--no-restart: never calls relancer-simulateur" lacks "$calls" "relancer"
check "--no-restart: not-run line unchanged" contains "$out" "ok1: build OK, tests NOT RUN (monkeydo exit 1, no test output)"

# --- a silent watch: restart and one retry ----------------------------------------
run_case mute_retry -- ok1 mute1 ok2
check "exit 0" equals $st 0
check "silent watch: restart, probe, retry once" equals "$calls" \
  "monkeyc ok1${nl}relancer${nl}monkeydo ok1 run_watches_probe${nl}monkeydo ok1${nl}monkeyc mute1${nl}monkeydo mute1${nl}relancer${nl}monkeydo mute1 run_watches_probe${nl}monkeydo mute1${nl}monkeyc ok2${nl}monkeydo ok2"
check "retried watch result" contains "$out" "mute1: build OK, 2 tests: 2 passed, 0 failed (retried after simulator restart)"
check "restart cause reported" contains "$out" "restarting simulator after mute1 stayed silent"

run_case dead_watch -- dead1 ok1
check "exit 0" equals $st 0
check "watch silent twice: reported" contains "$out" "dead1: build OK, tests SILENT (no test output after 1s) (retried after simulator restart)"
check "watch silent twice: retried once, next watch gets a fresh simulator" equals "$calls" \
  "monkeyc dead1${nl}relancer${nl}monkeydo dead1 run_watches_probe${nl}monkeydo dead1${nl}relancer${nl}monkeydo dead1 run_watches_probe${nl}monkeydo dead1${nl}monkeyc ok1${nl}relancer${nl}monkeydo ok1 run_watches_probe${nl}monkeydo ok1"
check "next watch passes" contains "$out" "ok1: build OK, 2 tests: 2 passed, 0 failed ["

# --- the simulator does not come back -----------------------------------------------
SIM_DEAD=1 run_case sim_dead -- ok1 ok2
check "exit 3" equals $st 3
check "clear message" contains "$out" "simulator NOT ANSWERING 2s after restart"
check "ok1 tests skipped" contains "$out" "ok1: build OK, tests SKIPPED (simulator not answering)"
check "ok2 still built, tests skipped" contains "$out" "ok2: build OK, tests SKIPPED (simulator not answering)"
count "$calls" relancer
check "a single restart attempt" equals $REPLY 1
check "no test run after giving up" lacks "$calls" "monkeydo ok2"
check "only probes for ok1" lacks "${calls}${nl}" "monkeydo ok1${nl}"
count "$calls" "monkeydo ok1 run_watches_probe"
check "waiting stops: 2 probes in 2s (at 0s, then after a 2s pause)" equals $REPLY 2

# --- the simulator answers after a few probes ------------------------------------
run_case slow_simulator RUN_WATCHES_SIM_WAIT=20 STUB_PROBE_FAILS=2 -- ok1
check "exit 0" equals $st 0
check "probes repeated until the third answers, then tests run" equals "$calls" \
  "monkeyc ok1${nl}relancer${nl}monkeydo ok1 run_watches_probe${nl}monkeydo ok1 run_watches_probe${nl}monkeydo ok1 run_watches_probe${nl}monkeydo ok1"
# two 5s pauses, plus up to 0.5s of polling for each of the 3 probes
check "answer reported after the two 5s pauses" matches "$out" "*simulator answered after 1[0-2]s*"
check "tests run" contains "$out" "ok1: build OK, 2 tests: 2 passed, 0 failed ["

run_case simulator_too_slow RUN_WATCHES_SIM_WAIT=7 STUB_PROBE_FAILS=5 -- ok1
check "exit 3" equals $st 3
count "$calls" "monkeydo ok1 run_watches_probe"
check "probes at 0s, 5s and 7s, then give up" equals $REPLY 3
check "clear message" contains "$out" "simulator NOT ANSWERING 7s after restart"

# --- a watch that prints tests then hangs -----------------------------------------
run_case hang RUN_WATCHES_TIMEOUT=3 -- hang1 ok1
check "exit 0" equals $st 0
check "blocked twice: reported with partial counts and the retry" contains "$out" \
  "hang1: build OK, tests BLOCKED (>3s) after 2 tests: 1 passed, 1 failed (retried after simulator restart) -- failed: testB (no result)"
check "hang: restart, retry once, fresh restart for the next watch" equals "$calls" \
  "monkeyc hang1${nl}relancer${nl}monkeydo hang1 run_watches_probe${nl}monkeydo hang1${nl}relancer${nl}monkeydo hang1 run_watches_probe${nl}monkeydo hang1${nl}monkeyc ok1${nl}relancer${nl}monkeydo ok1 run_watches_probe${nl}monkeydo ok1"

run_case freeze_mid_run -- --batch-size 2 freeze1 ok1 ok2
check "exit 3" equals $st 3
check "frozen watch keeps its first result, not marked as retried" contains "$out" \
  "freeze1: build OK, tests SILENT (no test output after 1s) ["
check "rest of the lot skipped" contains "$out" "ok1: build OK, tests SKIPPED (simulator not answering)"
check "next lot skipped, no new restart" contains "$out" "ok2: build OK, tests SKIPPED (simulator not answering)"
count "$calls" relancer
check "two restarts only (lot start, after the silent watch)" equals $REPLY 2
check "ok1 and ok2 never run" lacks "$calls" "monkeydo ok"

run_case relancer_fails STUB_RELANCER_EXIT=1 -- ok1
check "exit 3" equals $st 3
check "failure of relancer-simulateur reported" contains "$out" "relancer-simulateur failed (exit 1)"
check "no probe after a failed restart" equals "$calls" "monkeyc ok1${nl}relancer"

# --- arguments ------------------------------------------------------------------------
run_case help -- --help
check "help exit 0" equals $st 0
check "help documents --no-restart" contains "$out" "--no-restart"
check "help documents --batch-size" contains "$out" "--batch-size"
check "help documents RUN_WATCHES_SIM_WAIT" contains "$out" "RUN_WATCHES_SIM_WAIT"

for bad in "--batch-size" "--batch-size 0" "--batch-size x" "--batch-size=" "--batch-size -1"; do
  run_case "bad_${bad// /_}" -- ${=bad} ok1
  check "'$bad' rejected with exit 2" equals $st 2
  check "'$bad' builds nothing" equals "$calls" ""
done

run_case no_watch -- --no-restart
check "no watch: exit 2" equals $st 2

run_case bad_build_dir RUN_WATCHES_BUILD_DIR=/etc/glidator -- ok1
check "build dir outside /tmp rejected" equals $st 2
check "nothing built" equals "$calls" ""

run_case bad_env_batch RUN_WATCHES_BATCH=abc -- ok1
check "invalid RUN_WATCHES_BATCH rejected" equals $st 2

for bad in yes 2 no; do
  run_case "bad_env_restart_$bad" RUN_WATCHES_RESTART=$bad -- ok1
  check "RUN_WATCHES_RESTART='$bad' rejected with exit 2" equals $st 2
  check "RUN_WATCHES_RESTART='$bad' builds nothing" equals "$calls" ""
done

run_case env_restart_1 RUN_WATCHES_RESTART=1 -- ok1
check "RUN_WATCHES_RESTART=1 accepted: restart done" contains "$calls" "relancer"

rm -rf -- $ROOT
print
print -r -- "$n_checks checks, $n_failed failed"
(( n_failed )) && print -rl -- "failed:" "  "${^failed_checks}
(( n_failed == 0 ))
