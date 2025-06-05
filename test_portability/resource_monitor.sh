#!/usr/bin/env bash
#./resource_monitor.sh $(pgrep -f llama-cli)

# ╔════════════════════════════════════════════════════════════════════════════╗
# ║                         🖥️  Bash Process Resource Monitor                  ║
# ╠════════════════════════════════════════════════════════════════════════════╣
# ║ Monitors RAM and per-core CPU usage for a given PID in real time.          ║
# ║                                                                            ║
# ║ FEATURES:                                                                  ║
# ║  • Live RAM usage: current, peak, and average (in MB)                      ║
# ║  • Per-core CPU usage with color-coded load (green/yellow/red)             ║
# ║  • Highlights cores actively used by the target process (**)               ║
# ║  • TUI layout with box-drawing characters for clarity                      ║
# ║  • Runtime tracker: HH:MM:SS since process start                           ║
# ║  • Compact date format: dd.mm.yy HH:MM:SS                                  ║
# ║  • Clean exit summary with final RAM and runtime stats                     ║
# ║  • Optional --no-color mode for raw output                                 ║
# ║                                                                            ║
# ║ USAGE:                                                                     ║
# ║   ./resource_monitor.sh <PID> [--no-color]                                 ║
# ║                                                                            ║
# ║ EXAMPLE:                                                                   ║
# ║   ./resource_monitor.sh 12345                                              ║
# ║   ./resource_monitor.sh 12345 --no-color                                   ║
# ╚════════════════════════════════════════════════════════════════════════════╝


# === Resource Monitor ===
# Monitors RAM and CPU usage for a given PID in real-time.
# Usage: ./resource_monitor.sh <PID> [--no-color]

monitor_resources() {
  local pid=$1
  local no_color=$2
  local start_time=$(date +%s)
  local start_fmt=$(date -d "@$start_time" "+%d.%m.%y %H:%M:%S")

  local count=0 sum_mem=0 peak_mem=0

  # Colors
  local RED="\033[31m" GREEN="\033[32m" YELLOW="\033[33m" RESET="\033[0m"
  if [[ "$no_color" == "--no-color" ]]; then
    RED="" GREEN="" YELLOW="" RESET=""
  fi

  # Hide cursor and ensure it's restored on exit
  tput civis
  trap 'tput cnorm; echo; exit' INT TERM EXIT

  local num_cores
  num_cores=$(nproc)

  # Function to read CPU stats lines for cores only (cpu0, cpu1, ...)
  read_cpu_stats() {
    # Reads lines from /proc/stat for each core into an array
    mapfile -t cpu_stats < <(grep -E '^cpu[0-9]+' /proc/stat)
  }

  # Read initial CPU stats
  read_cpu_stats
  local -a cpu_before=("${cpu_stats[@]}")

  while kill -0 "$pid" 2>/dev/null; do
    # Memory usage (RSS in Kb to Mb)
    local rss_kb
    rss_kb=$(ps -o rss= -p "$pid" 2>/dev/null | tr -d ' ' || echo 0)
    local mem_mb=$((rss_kb / 1024))

    ((count++))
    sum_mem=$((sum_mem + mem_mb))
    ((mem_mb > peak_mem)) && peak_mem=$mem_mb
    local avg_mem=$((sum_mem / count))

    # Sleep 1 second before reading CPU stats again
    sleep 1
        # Add right after sleep 1
    if ! kill -0 "$pid" 2>/dev/null; then break; fi


    read_cpu_stats
    local -a cpu_after=("${cpu_stats[@]}")

    # Get list of CPU cores the process threads are running on
    local -a used_cores=()
    if [[ -d /proc/$pid/task ]]; then
      used_cores=($(ps -L -p "$pid" -o psr= 2>/dev/null | tr -d ' ' | sort -n | uniq))
    fi

    local total_cpu=0
    local -a core_usages=()

    for ((i=0; i<num_cores; i++)); do
      # Split CPU stats line into fields (e.g. cpu0 123 456 789 ...)
      read -ra b <<< "${cpu_before[i]}"
      read -ra a <<< "${cpu_after[i]}"

      # Fields after the first are time counters:
      # user, nice, system, idle, iowait, irq, softirq, steal, guest, guest_nice
      # Idle is field 4 (index 4), total is sum of all fields after first

      local idle_before=${b[4]}
      local idle_after=${a[4]}

      local total_before=0
      local total_after=0

      for val in "${b[@]:1}"; do ((total_before += val)); done
      for val in "${a[@]:1}"; do ((total_after += val)); done

      local delta_total=$((total_after - total_before))
      local delta_idle=$((idle_after - idle_before))
      local delta_used=$((delta_total - delta_idle))

      local usage=0
      if ((delta_total > 0)); then
        usage=$((100 * delta_used / delta_total))
      fi
      core_usages[i]=$usage
      total_cpu=$((total_cpu + usage))
    done

    local avg_cpu=0
    if ((num_cores > 0)); then
      avg_cpu=$((total_cpu / num_cores))
    fi

    local now
    now=$(date "+%d.%m.%y %H:%M:%S")
    local runtime=$(( $(date +%s) - start_time ))
    local hr=$((runtime / 3600))
    local min=$(( (runtime % 3600) / 60 ))
    local sec=$((runtime % 60))
    local time_fmt
    time_fmt=$(printf "%02d:%02d:%02d" $hr $min $sec)
    

    # Clear screen and print
    printf "\033[H\033[J"
    echo -e "╔══════════════════════════════════════════════════════════════════════════════╗"
    printf  "║ 🧠 RAM Usage - Current: %4d Mb | Peak: %4d Mb | Average: %4d Mb%23s\n" "$mem_mb" "$peak_mem" "$avg_mem" ""
    echo    "╠══════════════════════════════════════════════════════════════════════════════╣"
    printf  "║ ⚙️  CPU Usage - Cores Used: %2d/%d, 💤 Idle: %2d%45s \n" "${#used_cores[@]}" "$num_cores" "$((num_cores - ${#used_cores[@]}))" ""
    echo    "╠══════════════════════════════════════════════════════════════════════════════╣"
    printf  "║ ⏱️  Runtime: %-8s | Start: %-19s | Now: %-19s\n" "$time_fmt" "$start_fmt" "$now"
    echo    "╠══════════════════════════════════════════════════════════════════════════════╣"
    echo -e "║ 🍇 CPU Cores: 🍇  ---  🌟 Total CPU Avg: ${avg_cpu}.% ${RESET}"

    for ((row=0; row<num_cores; row+=4)); do
      printf "║"
      for ((col=0; col<4; col++)); do
        local i=$((row + col))
        if (( i >= num_cores )); then
          printf " %-14s" ""
        else
          local usage=${core_usages[i]}
          local core_label="C$i"
          # Mark core if used by process threads
          if [[ " ${used_cores[*]} " =~ " $i " ]]; then
            core_label+="**"
          fi
          local color=$GREEN
          if (( usage >= 70 )); then
            color=$RED
          elif (( usage >= 30 )); then
            color=$YELLOW
          fi
          printf " %b%-4s:%3d%%%b    " "$color" "$core_label" "$usage" "$RESET"
          # | Format   | Purpose                                                                                |
          # | `%-4s`   | The `core_label` (e.g. `C0*`) is **left-aligned** in 4 spaces — tight but fits `C12*`. |
          # | `:%3d%%` | Adds colon right next to label, usage right-aligned in 3 spaces (e.g. `100%`)          |
          # | `"    "` | Adds 4 spaces after each core group to separate nicely                                 |
          # | -------- | -------------------------------------------------------------------------------------- |
        fi
      done
      printf "\n"
    done

    echo    "║ Legend: ** = core used by process | green = low, yellow = med, red = high"
    echo    "╚══════════════════════════════════════════════════════════════════════════════╝"
    
    # Save current cpu_after as cpu_before for next iteration
    cpu_before=("${cpu_after[@]}")

  done

  end_time=$(date +%s)
  end_fmt=$(date -d "@$end_time" "+%d.%m.%y %H:%M:%S")
  start_fmt=$(date -d "@$start_time" "+%d.%m.%y %H:%M:%S")


  echo -e "\n╔══════════════════════════════════════════════════════════════════════════════╗"
  printf  "║ 💀 Process %-7d has exited. Summary:%46s\n" "$pid" ""
  echo    "╠══════════════════════════════════════════════════════════════════════════════╣"
  printf  "║ ⏱️  Runtime: %-8s | 🌅 Start: %-19s | 🌇 End: %-19s\n" "$time_fmt" "$start_fmt" "$end_fmt"
  echo    "╠══════════════════════════════════════════════════════════════════════════════╣"
  printf  "║ 🧠 Final RAM - Peak: %4d Mb | Average: %4d Mb%36s\n" "$peak_mem" "$avg_mem" ""
  echo    "╚══════════════════════════════════════════════════════════════════════════════╝"

  # Show cursor before exit
  tput cnorm
}

monitor_resources "$@"
