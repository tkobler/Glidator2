#!/usr/bin/env zsh
# Build and run the Glidator unit tests on several watches in the simulator.
#
# Usage (from anywhere; the script moves to the repository root):
#   zsh tools/run-watches.zsh [--release] [--no-restart] [--batch-size N] <watch>...
#
# For each watch:
#   - compile to /tmp/glidator-build/<watch>.prg (with -t, unless --release);
#   - run `monkeydo <prg> <watch> -t` (skipped with --release);
#   - write the full output to /tmp/glidator-build/<watch>.log;
#   - print one line: build OK/KO, passed/failed counts, failing test names.
# Each step (build, test run) is limited to RUN_WATCHES_TIMEOUT seconds
# (default 300). A step that takes longer is killed and reported as
# "BLOCKED". A test run that prints no test at all within RUN_WATCHES_SILENT
# seconds (default 120, 0 = no limit) is killed and reported as "SILENT".
# This delay starts when monkeydo is launched, so it includes the time
# monkeydo needs to push the .prg and the simulator needs to load the app
# (a few seconds when the simulator is healthy).
#
# `monkeydo -t` exits with 1 even when every test passes, so the result is
# read from the Toybox.Test output (per-test PASS/FAIL/ERROR lines, the
# RESULTS table and the "FAILED (passed=..)" summary), never from the exit
# code. A test in ERROR counts as failed.
#
# Lots and simulator restarts (decision D4 A of 2026-10-12):
#   - The watches are run in lots. By default the whole list is one lot;
#     --batch-size N (or RUN_WATCHES_BATCH=N) cuts it into lots of N watches.
#     Each lot starts with a "=== lot i/n: <watches>" line.
#   - Before the first test run of each lot, the simulator is restarted with
#     `relancer-simulateur` (it stops the simulator, opens it again and waits
#     until its process is there). The restart comes right after the first
#     successful build of the lot, because that .prg is used to check that
#     the simulator answers.
#   - "The simulator answers" means: a probe run
#     `monkeydo <prg> <watch> -t run_watches_probe` prints at least one
#     "Executing test" line, i.e. the simulator loaded and ran the app (the
#     probe test does not exist, so the probe itself ends in ERROR: expected).
#     Probes (each limited to 30s) are repeated every 5s until
#     RUN_WATCHES_SIM_WAIT seconds (default 120) have passed.
#   - A watch whose test run is SILENT, BLOCKED or gives no test output makes
#     the script restart the simulator and run that watch once more (its line
#     then ends with "(retried after simulator restart)"). If it fails again,
#     the next watch with tests to run gets a fresh restart too.
#   - If the simulator does not answer after a restart, or if
#     relancer-simulateur fails, the script says so, only builds the
#     remaining watches ("tests SKIPPED (simulator not answering)") and exits
#     with status 3.
#   - --no-restart or RUN_WATCHES_RESTART=0: no restart at all. When monkeydo
#     cannot reach the simulator, it is only opened once with connectiq, then
#     the watch is run once more (behaviour before D4 A).
#   - --release runs no test, so it never restarts the simulator.
#
# Environment variables (all optional):
#   RUN_WATCHES_TIMEOUT    limit of one build or test run, seconds (300)
#   RUN_WATCHES_SILENT     limit before the first test line, seconds (120, 0 = none)
#   RUN_WATCHES_SIM_WAIT   wait for the simulator to answer after a restart (120)
#   RUN_WATCHES_BATCH      watches per lot (0 = all watches in one lot)
#   RUN_WATCHES_RESTART    1 (default) or 0 to disable the restarts (same as --no-restart)
#   RUN_WATCHES_BUILD_DIR  output directory, must be under /tmp/ (/tmp/glidator-build)
#
# Exit status: 0 when every watch was handled (whatever the test results),
# 2 for a usage error, 3 when the simulator stopped answering.
#
# Only monkeyc, monkeydo, relancer-simulateur and connectiq are called;
# everything else is zsh builtins.
# Tests of this script (stubs, no SDK needed): zsh tools/test-run-watches.zsh

emulate -L zsh
setopt extended_glob
zmodload zsh/files 2>/dev/null || true   # builtin mkdir / rm
zmodload zsh/zselect                     # builtin sub-second wait
zmodload zsh/datetime                    # EPOCHREALTIME

readonly SCRIPT=${0:A}
readonly BUILD_DIR=${RUN_WATCHES_BUILD_DIR:-/tmp/glidator-build}
readonly TIMEOUT=${RUN_WATCHES_TIMEOUT:-300}
readonly SILENT=${RUN_WATCHES_SILENT:-120}
readonly SIM_WAIT=${RUN_WATCHES_SIM_WAIT:-120}
readonly PROBE_PAUSE=5
readonly PROBE_TEST=run_watches_probe
readonly RESTART_LIMIT=120
readonly USAGE="usage: zsh tools/run-watches.zsh [--release] [--no-restart] [--batch-size N] <watch>..."

usage_error() {
  print -u2 -r -- "$1"
  print -u2 -r -- $USAGE
  exit 2
}

# Prints the comment block at the top of this file.
print_help() {
  local line
  for line in "${(@f)$(<$SCRIPT)}"; do
    [[ $line == '#!'* ]] && continue
    [[ $line == '#'* ]] || break
    line=${line#\#}
    print -r -- "${line# }"
  done
}

cd -- "${SCRIPT:h}/.." || { print -u2 "cannot cd to repository root"; exit 2 }

[[ $BUILD_DIR == /tmp/?* && $BUILD_DIR != *..* ]] ||
  usage_error "RUN_WATCHES_BUILD_DIR must be under /tmp/: $BUILD_DIR"
for value in $TIMEOUT $SIM_WAIT; do
  [[ $value == <1-> ]] || usage_error "RUN_WATCHES_TIMEOUT and RUN_WATCHES_SIM_WAIT must be whole numbers >= 1"
done
[[ $SILENT == <-> ]] || usage_error "RUN_WATCHES_SILENT must be a whole number"
readonly PROBE_LIMIT=$(( SIM_WAIT < 30 ? SIM_WAIT : 30 ))

release=0
restart=${RUN_WATCHES_RESTART:-1}
[[ $restart == [01] ]] || usage_error "RUN_WATCHES_RESTART must be 0 or 1: $restart"
batch=${RUN_WATCHES_BATCH:-0}
[[ $batch == <-> ]] || usage_error "RUN_WATCHES_BATCH must be a whole number: $batch"
typeset -a watches
args=("$@")
for (( i = 1; i <= $#args; i++ )); do
  arg=$args[i]
  case $arg in
    --release) release=1 ;;
    --no-restart) restart=0 ;;
    --batch-size=*)
      batch=${arg#*=}
      [[ $batch == <1-> ]] || usage_error "--batch-size needs a whole number >= 1" ;;
    --batch-size)
      (( i++ ))
      batch=${args[i]-}
      [[ $batch == <1-> ]] || usage_error "--batch-size needs a whole number >= 1" ;;
    -h|--help) print_help; exit 0 ;;
    -*) usage_error "unknown option: $arg" ;;
    *) watches+=("$arg") ;;
  esac
done
(( ${#watches} )) || usage_error "no watch given"
(( batch > 0 && batch < ${#watches} )) || batch=${#watches}
n_lots=$(( (${#watches} + batch - 1) / batch ))

mkdir -p -- $BUILD_DIR || exit 2

# Background jobs get their own process group, so a blocked monkeydo can be
# killed together with the processes it started.
setopt monitor 2>/dev/null

kill_group() {
  kill -TERM -- -$1 2>/dev/null || kill -TERM $1 2>/dev/null
  zselect -t 200
  kill -KILL -- -$1 2>/dev/null || kill -KILL $1 2>/dev/null
  wait $1 2>/dev/null
}

# run_limited <log> <seconds> <silent-seconds> <command...>
# Runs the command in the background with its output appended to <log> and
# waits at most <seconds>. When <silent-seconds> is not 0 and the log holds
# no "Executing test" line after that many seconds, the command is killed.
# Sets REPLY to the exit status, "blocked" or "silent".
run_limited() {
  local log=$1 limit=$2 quiet=$3
  shift 3
  "$@" >>| $log 2>&1 &
  local pid=$! start=$EPOCHREALTIME heard=0
  while kill -0 $pid 2>/dev/null; do
    if (( EPOCHREALTIME - start >= limit )); then
      kill_group $pid
      REPLY=blocked
      return 0
    fi
    if (( quiet > 0 && !heard && EPOCHREALTIME - start >= quiet )); then
      if [[ "$(<$log)" == *'Executing test '* ]]; then
        heard=1
      else
        kill_group $pid
        REPLY=silent
        return 0
      fi
    fi
    zselect -t 50
  done
  wait $pid
  REPLY=$?
  return 0
}

# parse_results <log>
# Sets n_total n_pass n_fail, failed_names (array) and summary.
# A test is identified by its "Executing test <name>..." line; its status is
# the next line that is exactly PASS, FAIL or ERROR (log lines such as
# "ERROR (23:02): LAYOUT ..." are ignored). The RESULTS table, when present,
# has the last word. A test without any status counts as failed.
parse_results() {
  local log=$1 line current="" in_table=0 name st
  local -A status_of
  local -a order
  n_total=0 n_pass=0 n_fail=0 summary="" failed_names=()
  [[ -r $log ]] || return 0
  for line in "${(@f)$(<$log)}"; do
    line=${line%%[[:space:]]#}
    if [[ $line == (#b)'Executing test '(*)'...' ]]; then
      current=$match[1]
      [[ -n ${status_of[$current]-} ]] || order+=("$current")
      status_of[$current]=NONE
    elif [[ -n $current && $line == (PASS|FAIL|ERROR) ]]; then
      status_of[$current]=$line
      current=""
    elif [[ $line == RESULTS ]]; then
      in_table=1 current=""
    elif (( in_table )) && [[ $line == (#b)([^[:space:]]##)[[:space:]]##(PASS|FAIL|ERROR) ]]; then
      [[ -n ${status_of[$match[1]]-} ]] || order+=("$match[1]")
      status_of[$match[1]]=$match[2]
    elif [[ $line == (PASSED|FAILED)' ('*')' ]]; then
      summary=$line
    fi
  done
  for name in $order; do
    st=${status_of[$name]}
    (( n_total++ ))
    case $st in
      PASS) (( n_pass++ )) ;;
      NONE) (( n_fail++ )); failed_names+=("$name (no result)") ;;
      *)    (( n_fail++ )); failed_names+=("$name ($st)") ;;
    esac
  done
  return 0
}

sim_started=0
# Without restarts: opens the simulator once per script run.
# Returns 1 if already tried.
start_simulator() {
  (( sim_started )) && return 1
  sim_started=1
  local wait=$(( SIM_WAIT < 20 ? SIM_WAIT : 20 ))
  print -r -- "  simulator not reachable: starting it with connectiq, waiting ${wait}s"
  connectiq >/dev/null 2>&1 &!
  zselect -t $(( wait * 100 ))
  return 0
}

sim_dead=0
# wait_for_simulator <prg> <watch> <log>
# Probes the simulator until it runs the app or SIM_WAIT seconds have passed.
wait_for_simulator() {
  local prg=$1 watch=$2 log=$3 probe_log=$BUILD_DIR/$2.probe.tmp
  local start=$EPOCHREALTIME remaining
  local -i pause_cs
  while true; do
    : >| $probe_log
    run_limited $probe_log $PROBE_LIMIT 0 monkeydo $prg $watch -t $PROBE_TEST
    print -r -- "### probe: monkeydo $prg $watch -t $PROBE_TEST (exit $REPLY)" >> $log
    print -r -- "$(<$probe_log)" >> $log
    if [[ "$(<$probe_log)" == *'Executing test '* ]]; then
      rm -f -- $probe_log
      printf '  simulator answered after %.0fs\n' $(( EPOCHREALTIME - start ))
      return 0
    fi
    remaining=$(( SIM_WAIT - (EPOCHREALTIME - start) ))
    (( remaining > 0 )) || break
    pause_cs=$(( (remaining < PROBE_PAUSE ? remaining : PROBE_PAUSE) * 100 + 1 ))
    zselect -t $pause_cs
  done
  rm -f -- $probe_log
  print -r -- "  simulator NOT ANSWERING ${SIM_WAIT}s after restart: no more test runs, the remaining watches are only built"
  return 1
}

# restart_simulator <reason> <prg> <watch> <log>
# Restarts the simulator and waits until it answers. Sets sim_dead on failure.
restart_simulator() {
  local reason=$1 prg=$2 watch=$3 log=$4 out=$BUILD_DIR/relancer.tmp line
  print -r -- "  restarting simulator $reason"
  : >| $out
  run_limited $out $RESTART_LIMIT 0 relancer-simulateur
  print -r -- "### relancer-simulateur $reason (exit $REPLY)" >> $log
  print -r -- "$(<$out)" >> $log
  for line in "${(@f)$(<$out)}"; do
    [[ -n $line ]] && print -r -- "    $line"
  done
  rm -f -- $out
  if [[ $REPLY != 0 ]]; then
    print -r -- "  relancer-simulateur failed (exit $REPLY): no more test runs, the remaining watches are only built"
    sim_dead=1
    return 1
  fi
  wait_for_simulator $prg $watch $log && return 0
  sim_dead=1
  return 1
}

pending_restart=""
index=0
for watch in $watches; do
  if (( index % batch == 0 )); then
    lot=$(( index / batch + 1 ))
    print -r -- "=== lot $lot/$n_lots: ${watches[index+1,index+batch]}"
    (( restart )) && pending_restart="before lot $lot/$n_lots"
  fi
  (( index++ ))

  prg=$BUILD_DIR/$watch.prg
  log=$BUILD_DIR/$watch.log
  run_log=$BUILD_DIR/$watch.run.tmp
  t0=$SECONDS
  : >| $log

  build_args=(-f monkey.jungle -o $prg -d $watch -y developer_key)
  (( release )) || build_args+=(-t)
  print -r -- "### monkeyc $build_args" >> $log
  run_limited $log $TIMEOUT 0 monkeyc $build_args

  if [[ $REPLY == blocked ]]; then
    line="$watch: build BLOCKED (>${TIMEOUT}s)"
  elif (( REPLY != 0 )); then
    line="$watch: build KO (exit $REPLY)"
  elif (( release )); then
    line="$watch: build OK (release, no test run)"
  elif (( sim_dead )); then
    line="$watch: build OK, tests SKIPPED (simulator not answering)"
  elif [[ -n $pending_restart ]] && ! restart_simulator "$pending_restart" $prg $watch $log; then
    line="$watch: build OK, tests SKIPPED (simulator not answering)"
  else
    pending_restart=""
    retried=0 tried_restart=0
    while true; do
      : >| $run_log
      run_limited $run_log $TIMEOUT $SILENT monkeydo $prg $watch -t
      run_status=$REPLY
      parse_results $run_log
      mute=0
      [[ $run_status == (blocked|silent) ]] || (( n_total == 0 )) && mute=1
      if (( mute && restart && !tried_restart )); then
        print -r -- "### monkeydo $prg $watch -t (exit $run_status, before restart)" >> $log
        print -r -- "$(<$run_log)" >> $log
        tried_restart=1
        if restart_simulator "after $watch stayed silent" $prg $watch $log; then
          retried=1
          continue
        fi
        break
      fi
      if (( !restart )) && [[ $run_status != (blocked|silent) ]] && (( n_total == 0 )) && start_simulator; then
        print -r -- "### monkeydo $prg $watch -t (no test output, exit $run_status)" >> $log
        print -r -- "$(<$run_log)" >> $log
        continue
      fi
      break
    done
    print -r -- "### monkeydo $prg $watch -t (exit $run_status)" >> $log
    print -r -- "$(<$run_log)" >> $log
    rm -f -- $run_log
    (( mute && restart && !sim_dead )) && pending_restart="after $watch stayed silent"

    if [[ $run_status == blocked ]]; then
      line="$watch: build OK, tests BLOCKED (>${TIMEOUT}s) after $n_total tests: $n_pass passed, $n_fail failed"
    elif [[ $run_status == silent ]]; then
      line="$watch: build OK, tests SILENT (no test output after ${SILENT}s)"
    elif (( n_total == 0 )); then
      line="$watch: build OK, tests NOT RUN (monkeydo exit $run_status, no test output)"
    else
      line="$watch: build OK, $n_total tests: $n_pass passed, $n_fail failed"
      if [[ $summary == (#b)*passed=([0-9]##)*failed=([0-9]##)*errors=([0-9]##)* ]] &&
         (( match[1] != n_pass || match[2] + match[3] != n_fail )); then
        line+=" (MISMATCH with summary: $summary)"
      elif [[ -z $summary ]]; then
        line+=" (no summary line)"
      fi
    fi
    (( retried )) && line+=" (retried after simulator restart)"
    (( ${#failed_names} )) && line+=" -- failed: ${(j:, :)failed_names}"
  fi
  line+=" [$(( SECONDS - t0 ))s, log: $log]"
  print -r -- $line
done

(( sim_dead )) && exit 3
exit 0
