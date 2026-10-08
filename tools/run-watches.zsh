#!/usr/bin/env zsh
# Build and run the Glidator unit tests on several watches in the simulator.
#
# Usage (from anywhere; the script moves to the repository root):
#   zsh tools/run-watches.zsh [--release] <watch> [<watch>...]
#
# For each watch:
#   - compile to /tmp/glidator-build/<watch>.prg (with -t, unless --release);
#   - run `monkeydo <prg> <watch> -t` (skipped with --release);
#   - write the full output to /tmp/glidator-build/<watch>.log;
#   - print one line: build OK/KO, passed/failed counts, failing test names.
# Each step (build, test run) is limited to RUN_WATCHES_TIMEOUT seconds
# (default 300). A step that takes longer is killed and reported as
# "BLOCKED"; the script then moves on to the next watch.
#
# `monkeydo -t` exits with 1 even when every test passes, so the result is
# read from the Toybox.Test output (per-test PASS/FAIL/ERROR lines, the
# RESULTS table and the "FAILED (passed=..)" summary), never from the exit
# code. A test in ERROR counts as failed.
#
# Only monkeyc, monkeydo and connectiq (to open the simulator when monkeydo
# cannot reach it) are called; everything else is zsh builtins.

emulate -L zsh
setopt extended_glob
zmodload zsh/files 2>/dev/null || true   # builtin mkdir / rm
zmodload zsh/zselect                     # builtin sub-second wait

readonly BUILD_DIR=/tmp/glidator-build
readonly TIMEOUT=${RUN_WATCHES_TIMEOUT:-300}
readonly SIM_START_WAIT=20
readonly USAGE="usage: zsh tools/run-watches.zsh [--release] <watch>..."

cd -- "${0:A:h}/.." || { print -u2 "cannot cd to repository root"; exit 2 }

release=0
typeset -a watches
for arg in "$@"; do
  case $arg in
    --release) release=1 ;;
    -h|--help) print -r -- $USAGE; exit 0 ;;
    -*) print -u2 -r -- "unknown option: $arg"; print -u2 -r -- $USAGE; exit 2 ;;
    *) watches+=("$arg") ;;
  esac
done
(( ${#watches} )) || { print -u2 -r -- $USAGE; exit 2 }

mkdir -p -- $BUILD_DIR || exit 2

# Background jobs get their own process group, so a blocked monkeydo can be
# killed together with the processes it started.
setopt monitor 2>/dev/null

# run_limited <log> <seconds> <command...>
# Runs the command in the background with its output appended to <log> and
# waits at most <seconds>. Sets REPLY to the exit status, or "blocked".
run_limited() {
  local log=$1 limit=$2
  shift 2
  "$@" >>| $log 2>&1 &
  local pid=$! start=$SECONDS
  while kill -0 $pid 2>/dev/null; do
    if (( SECONDS - start >= limit )); then
      kill -TERM -- -$pid 2>/dev/null || kill -TERM $pid 2>/dev/null
      zselect -t 200
      kill -KILL -- -$pid 2>/dev/null || kill -KILL $pid 2>/dev/null
      wait $pid 2>/dev/null
      REPLY=blocked
      return 0
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
# Opens the simulator once per script run. Returns 1 if already tried.
start_simulator() {
  (( sim_started )) && return 1
  sim_started=1
  print -r -- "  simulator not reachable: starting it with connectiq, waiting ${SIM_START_WAIT}s"
  connectiq >/dev/null 2>&1 &!
  zselect -t $(( SIM_START_WAIT * 100 ))
  return 0
}

for watch in $watches; do
  prg=$BUILD_DIR/$watch.prg
  log=$BUILD_DIR/$watch.log
  run_log=$BUILD_DIR/$watch.run.tmp
  t0=$SECONDS
  : >| $log

  build_args=(-f monkey.jungle -o $prg -d $watch -y developer_key)
  (( release )) || build_args+=(-t)
  print -r -- "### monkeyc $build_args" >> $log
  run_limited $log $TIMEOUT monkeyc $build_args

  if [[ $REPLY == blocked ]]; then
    line="$watch: build BLOCKED (>${TIMEOUT}s)"
  elif (( REPLY != 0 )); then
    line="$watch: build KO (exit $REPLY)"
  elif (( release )); then
    line="$watch: build OK (release, no test run)"
  else
    while true; do
      : >| $run_log
      run_limited $run_log $TIMEOUT monkeydo $prg $watch -t
      parse_results $run_log
      if [[ $REPLY != blocked ]] && (( n_total == 0 )) && start_simulator; then
        print -r -- "### monkeydo $prg $watch -t (no test output, exit $REPLY)" >> $log
        print -r -- "$(<$run_log)" >> $log
        continue
      fi
      break
    done
    print -r -- "### monkeydo $prg $watch -t (exit $REPLY)" >> $log
    print -r -- "$(<$run_log)" >> $log
    rm -f -- $run_log

    if [[ $REPLY == blocked ]]; then
      line="$watch: build OK, tests BLOCKED (>${TIMEOUT}s) after $n_total tests: $n_pass passed, $n_fail failed"
    elif (( n_total == 0 )); then
      line="$watch: build OK, tests NOT RUN (monkeydo exit $REPLY, no test output)"
    else
      line="$watch: build OK, $n_total tests: $n_pass passed, $n_fail failed"
      if [[ $summary == (#b)*passed=([0-9]##)*failed=([0-9]##)*errors=([0-9]##)* ]] &&
         (( match[1] != n_pass || match[2] + match[3] != n_fail )); then
        line+=" (MISMATCH with summary: $summary)"
      elif [[ -z $summary ]]; then
        line+=" (no summary line)"
      fi
    fi
    (( ${#failed_names} )) && line+=" -- failed: ${(j:, :)failed_names}"
  fi
  line+=" [$(( SECONDS - t0 ))s, log: $log]"
  print -r -- $line
done
