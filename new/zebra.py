#!/usr/bin/env python3
"""
zebra.py - Automated Test Point Insertion Tournament Manager

UPDATED:
- Uses combined analysis.py instead of separate entropy.py and spectral.py
- Simplified metrics parsing from results.csv
- Signal name normalization
- Rollback capability for bad test points

Usage:
    python3 zebra.py --config config.json
    python3 zebra.py --entropy-thresh 0.14 --sc-thresh 5.0 --po-thresh 0.5
"""

import argparse
import json
import os
import shutil
import subprocess
import sys
import re
import time
import csv
from pathlib import Path
from typing import Dict, List, Tuple, Optional
from dataclasses import dataclass, asdict
from datetime import datetime


@dataclass
class SignalMetrics:
    """Metrics for a single signal"""
    signal_name: str
    entropy: Optional[float] = None
    sc_avg: Optional[float] = None
    po_cos: Optional[float] = None
    width: Optional[int] = None
    
    def to_dict(self):
        return asdict(self)
    
    def is_better_than(self, other: 'SignalMetrics') -> bool:
        """Check if this metrics is better than another"""
        improvements = 0
        comparisons = 0
        
        if self.entropy is not None and other.entropy is not None:
            if self.entropy > other.entropy:
                improvements += 1
            comparisons += 1
        
        if self.sc_avg is not None and other.sc_avg is not None:
            if self.sc_avg > other.sc_avg:
                improvements += 1
            comparisons += 1
        
        if self.po_cos is not None and other.po_cos is not None:
            if self.po_cos > other.po_cos:
                improvements += 1
            comparisons += 1
        
        # Consider better if at least 50% of metrics improved
        return comparisons > 0 and (improvements / comparisons) >= 0.5


@dataclass
class TournamentConfig:
    """Configuration for tournament execution"""
    rtl_dir: str = "rtl"
    tb_dir: str = "tb"
    work_dir: str = "tournament_work"
    vcd_parser: str = "./vcdparse/verilog-vcd-parser/build/vcd-parse"
    tbgen_script: str = "tbgen.py"
    analysis_script: str = "analysis.py"  # Combined analysis script
    
    # Thresholds
    entropy_threshold: float = 0.14
    sc_avg_threshold: float = 5.0
    po_cos_threshold: float = 0.5
    change_threshold: float = 0.20  # 20% entropy change to continue
    
    # Simulation parameters
    sim_cycles: int = 50000
    random_seed: int = 1
    
    # Tool paths
    vcs_path: str = "vcs"
    
    max_tournaments: int = 10
    
    # Main design file (DUT)
    main_design_file: Optional[str] = None  # Auto-detected if None
    
    # Rollback settings
    enable_rollback: bool = True  # Enable rollback on worse metrics
    min_improvement: float = 0.05  # Minimum improvement to keep TP
    
    @classmethod
    def from_dict(cls, d: dict):
        return cls(**{k: v for k, v in d.items() if k in cls.__annotations__})


class TournamentOrchestrator:
    """Main orchestrator for test point insertion tournaments"""
    
    def __init__(self, config: TournamentConfig):
        self.config = config
        self.tournament_num = 0
        self.metrics_history = {}  # {tournament_num: {signal: SignalMetrics}}
        self.test_points_inserted = {}  # {tournament_num: [(signal, tp_type)]}
        self.summary_reports = []
        
        # Create work directory
        Path(self.config.work_dir).mkdir(parents=True, exist_ok=True)
        Path(self.config.tb_dir).mkdir(parents=True, exist_ok=True)
        
        self.log_file = open(os.path.join(self.config.work_dir, "zebra.log"), "w")
        
        # Detect main design file if not specified
        if self.config.main_design_file is None:
            self.config.main_design_file = self.detect_main_design_file()
        
    def log(self, msg: str, level: str = "INFO"):
        """Log message to console and file"""
        timestamp = datetime.now().strftime("%Y-%m-%d %H:%M:%S")
        log_msg = f"[{timestamp}] [{level}] {msg}"
        print(log_msg)
        self.log_file.write(log_msg + "\n")
        self.log_file.flush()
    
    def normalize_signal_name(self, signal_name: str) -> str:
        """Normalize signal name by removing hierarchy prefixes like 'dut.' or 'tb_top.'"""
        if '.' in signal_name:
            parts = signal_name.split('.')
            return parts[-1]
        return signal_name
        
    def run_command(self, cmd: str, cwd: str = None, timeout: int = 3600) -> Tuple[int, str, str]:
        """Execute shell command and return (returncode, stdout, stderr)"""
        self.log(f"Executing: {cmd}")
        
        try:
            result = subprocess.run(
                cmd,
                shell=True,
                cwd=cwd or self.config.work_dir,
                capture_output=True,
                text=True,
                timeout=timeout
            )
            return result.returncode, result.stdout, result.stderr
        except subprocess.TimeoutExpired:
            self.log(f"Command timed out: {cmd}", "ERROR")
            return -1, "", "Timeout"
        except Exception as e:
            self.log(f"Command failed: {cmd} - {e}", "ERROR")
            return -1, "", str(e)
    
    def run_vcd_parser(self, cmd: str, cwd: str = None) -> Tuple[int, str, str]:
        """Execute VCD parser with smart termination"""
        self.log(f"Executing VCD parser: {cmd}")
        
        try:
            process = subprocess.Popen(
                cmd,
                shell=True,
                cwd=cwd or ".",
                stdout=subprocess.PIPE,
                stderr=subprocess.PIPE,
                text=True,
                bufsize=1
            )
            
            stdout_lines = []
            stderr_lines = []
            completed = False
            
            import select
            start_time = time.time()
            max_wait = 30
            
            while True:
                if process.poll() is not None:
                    remaining_out, remaining_err = process.communicate()
                    if remaining_out:
                        stdout_lines.append(remaining_out)
                    if remaining_err:
                        stderr_lines.append(remaining_err)
                    break
                
                if time.time() - start_time > max_wait:
                    self.log("VCD parser timeout, terminating...", "WARNING")
                    process.terminate()
                    try:
                        process.wait(timeout=2)
                    except subprocess.TimeoutExpired:
                        process.kill()
                    break
                
                try:
                    if hasattr(select, 'select'):
                        readable, _, _ = select.select([process.stdout, process.stderr], [], [], 0.1)
                        
                        if process.stdout in readable:
                            line = process.stdout.readline()
                            if line:
                                stdout_lines.append(line)
                                self.log(f"  VCD: {line.strip()}", "DEBUG")
                                
                                if "Times recorded:" in line or "Times Recorded:" in line:
                                    self.log("VCD parsing completed, terminating parser...")
                                    completed = True
                                    time.sleep(0.5)
                                    process.terminate()
                                    try:
                                        process.wait(timeout=2)
                                    except subprocess.TimeoutExpired:
                                        process.kill()
                                    break
                        
                        if process.stderr in readable:
                            line = process.stderr.readline()
                            if line:
                                stderr_lines.append(line)
                    else:
                        time.sleep(0.1)
                        if time.time() - start_time > 10:
                            process.terminate()
                            break
                    
                except Exception as e:
                    self.log(f"Error reading process output: {e}", "WARNING")
                    break
            
            stdout = ''.join(stdout_lines)
            stderr = ''.join(stderr_lines)
            returncode = process.returncode if process.returncode is not None else 0
            
            if completed or "Times recorded:" in stdout or "Times Recorded:" in stdout:
                returncode = 0
            
            return returncode, stdout, stderr
            
        except Exception as e:
            self.log(f"VCD parser execution failed: {e}", "ERROR")
            return -1, "", str(e)
    
    def detect_main_design_file(self) -> Optional[str]:
        """Auto-detect the main design file (DUT)"""
        self.log("Auto-detecting main design file...")
        
        rtl_files = list(Path(self.config.rtl_dir).glob("*.v"))
        
        if not rtl_files:
            self.log("No RTL files found", "ERROR")
            return None
        
        tb_files = list(Path(self.config.tb_dir).glob("*.v"))
        if tb_files:
            for tb_file in tb_files:
                with open(tb_file, 'r') as f:
                    tb_content = f.read()
                
                for rtl_file in rtl_files:
                    module_name = rtl_file.stem
                    pattern = rf'\b{module_name}\s+\w+\s*\('
                    if re.search(pattern, tb_content):
                        self.log(f"Detected main design file: {rtl_file.name} (instantiated in {tb_file.name})")
                        return str(rtl_file)
        
        largest_file = max(rtl_files, key=lambda f: os.path.getsize(f))
        self.log(f"Using largest RTL file as main design: {largest_file.name}")
        return str(largest_file)
    
    def regenerate_testbench(self) -> bool:
        """Regenerate testbench using tbgen.py after test point insertion"""
        self.log(f"=== Regenerating Testbench (Tournament {self.tournament_num}) ===")
        
        if not os.path.exists(self.config.tbgen_script):
            self.log(f"Testbench generator script not found: {self.config.tbgen_script}", "ERROR")
            return False
        
        if not self.config.main_design_file:
            self.log("Main design file not specified", "ERROR")
            return False
        
        target_tb = os.path.join(self.config.tb_dir, "tb_top.v")
        if os.path.exists(target_tb):
            backup_tb = os.path.join(
                self.config.work_dir, 
                f"tb_top_backup_t{self.tournament_num}.v"
            )
            shutil.copy(target_tb, backup_tb)
            self.log(f"Backed up old testbench to {backup_tb}")
        
        cmd = (
            f"python3 {self.config.tbgen_script} "
            f"{self.config.main_design_file} "
            f"tb_top.v "
            f"{self.config.sim_cycles}"
        )
        
        rc, stdout, stderr = self.run_command(cmd, cwd=".")
        
        if rc != 0:
            self.log(f"Testbench generation failed: {stderr}", "ERROR")
            return False
        
        if not os.path.exists("tb_top.v"):
            self.log(f"Generated testbench (tb_top.v) not found", "ERROR")
            return False
        
        shutil.move("tb_top.v", target_tb)
        self.log(f"New testbench placed at {target_tb}")
        
        return True
    
    def compile_design(self) -> bool:
        """Compile RTL and testbench with VCS"""
        self.log(f"=== Compiling Design (Tournament {self.tournament_num}) ===")
        
        rtl_files = list(Path(self.config.rtl_dir).glob("*.v"))
        tb_files = list(Path(self.config.tb_dir).glob("*.v"))
        
        if not rtl_files:
            self.log(f"No RTL files found in {self.config.rtl_dir}", "ERROR")
            return False
        
        if not tb_files:
            self.log(f"No testbench files found in {self.config.tb_dir}", "ERROR")
            return False
        
        rtl_str = " ".join([str(f) for f in rtl_files])
        tb_str = " ".join([str(f) for f in tb_files])
        
        cmd = (
            f"{self.config.vcs_path} -full64 +v2k -timescale=1ns/1ps "
            f"-debug_pp +define+SIM -o simv {rtl_str} {tb_str}"
        )
        
        rc, stdout, stderr = self.run_command(cmd, cwd=".")
        
        if rc != 0:
            self.log(f"Compilation failed: {stderr}", "ERROR")
            return False
        
        self.log("Compilation successful")
        return True
    
    def run_simulation(self) -> bool:
        """Run VCS simulation"""
        self.log(f"=== Running Simulation (Tournament {self.tournament_num}) ===")
        
        cmd = f"./simv +ntb_random_seed={self.config.random_seed} -l sim_t{self.tournament_num}.log"
        rc, stdout, stderr = self.run_command(cmd, cwd=".")
        
        if rc != 0:
            self.log(f"Simulation failed: {stderr}", "ERROR")
            return False
        
        if not os.path.exists("tb_top.vcd"):
            self.log("VCD file not generated", "ERROR")
            return False
        
        self.log("Simulation complete")
        return True
    
    def parse_vcd(self) -> bool:
        """Parse VCD to timeseries CSV"""
        self.log(f"=== Parsing VCD (Tournament {self.tournament_num}) ===")
        
        if not os.path.exists(self.config.vcd_parser):
            self.log(f"VCD parser not found: {self.config.vcd_parser}", "ERROR")
            return False
        
        cmd = f"{self.config.vcd_parser} tb_top.vcd timeseries_t{self.tournament_num}.csv"
        rc, stdout, stderr = self.run_vcd_parser(cmd, cwd=".")
        
        if rc != 0 and rc != -1:
            self.log(f"VCD parsing failed: {stderr}", "ERROR")
            return False
        
        if not os.path.exists(f"timeseries_t{self.tournament_num}.csv"):
            self.log("Timeseries CSV not generated", "ERROR")
            return False
        
        try:
            csv_size = os.path.getsize(f"timeseries_t{self.tournament_num}.csv")
            if csv_size < 100:
                self.log(f"Timeseries CSV seems incomplete (size: {csv_size} bytes)", "ERROR")
                return False
        except Exception as e:
            self.log(f"Error checking CSV file: {e}", "ERROR")
            return False
        
        self.log("VCD parsing complete")
        return True
    
    def calculate_metrics(self) -> bool:
        """Run combined entropy + spectral analysis"""
        self.log(f"=== Calculating Metrics (Tournament {self.tournament_num}) ===")
        
        if not os.path.exists(self.config.analysis_script):
            self.log(f"Analysis script not found: {self.config.analysis_script}", "ERROR")
            return False
        
        cmd = (
            f"python3 {self.config.analysis_script} "
            f"timeseries_t{self.tournament_num}.csv "
            f"> results_t{self.tournament_num}.txt"
        )
        rc, stdout, stderr = self.run_command(cmd, cwd=".")
        
        if rc != 0:
            self.log(f"Metrics calculation failed: {stderr}", "ERROR")
            return False
        
        # Check if results.csv was generated
        if not os.path.exists("results.csv"):
            self.log("results.csv not generated", "ERROR")
            return False
        
        # Rename to tournament-specific name
        results_csv = f"results_t{self.tournament_num}.csv"
        if os.path.exists(results_csv):
            os.remove(results_csv)
        shutil.copy("results.csv", results_csv)
        
        self.log(f"Metrics calculation complete - results in {results_csv}")
        return True
    
    def parse_metrics(self) -> Dict[str, SignalMetrics]:
        """Parse metrics from results.csv"""
        self.log(f"=== Parsing Metrics (Tournament {self.tournament_num}) ===")
        
        metrics = {}
        results_csv = f"results_t{self.tournament_num}.csv"
        
        if not os.path.exists(results_csv):
            self.log(f"Results CSV not found: {results_csv}", "ERROR")
            return metrics
        
        try:
            with open(results_csv, 'r') as f:
                reader = csv.DictReader(f)
                for row in reader:
                    signal = row['signal']
                    
                    # Normalize signal name
                    norm_signal = self.normalize_signal_name(signal)
                    
                    # Parse metrics
                    try:
                        entropy = float(row['entropy']) if row['entropy'] else None
                    except (ValueError, KeyError):
                        entropy = None
                    
                    try:
                        sc_avg = float(row['SC_avg']) if row['SC_avg'] else None
                    except (ValueError, KeyError):
                        sc_avg = None
                    
                    try:
                        po_cos = float(row['PO_cos']) if row['PO_cos'] else None
                    except (ValueError, KeyError):
                        po_cos = None
                    
                    metrics[norm_signal] = SignalMetrics(
                        signal_name=norm_signal,
                        entropy=entropy,
                        sc_avg=sc_avg,
                        po_cos=po_cos
                    )
            
            self.log(f"Parsed metrics for {len(metrics)} signals")
            
            # Debug: show sample metrics
            sample_signals = list(metrics.keys())[:5]
            for sig in sample_signals:
                m = metrics[sig]
                self.log(f"  Sample: {sig} - entropy={m.entropy}, sc_avg={m.sc_avg}, po_cos={m.po_cos}", "DEBUG")
            
        except Exception as e:
            self.log(f"Error parsing results CSV: {e}", "ERROR")
        
        return metrics
    
    def identify_testpoint_candidates(self, metrics: Dict[str, SignalMetrics]) -> List[Tuple[str, str]]:
        """Identify which signals need test points and what type"""
        candidates = []
        
        for signal, m in metrics.items():
            # Skip clock and reset signals
            if self._is_clk_or_rst(signal):
                continue
            
            # Skip testbench signals
            if signal.startswith('tb_') or 'tb_top' in signal.lower():
                continue
            
            # Skip test point signals
            if 'tp_ctrl' in signal.lower() or 'tp_obs' in signal.lower() or signal.endswith('_ctp') or signal.endswith('_otp'):
                continue
            
            needs_ctp = False
            needs_otp = False
            
            # Check entropy threshold
            if m.entropy is not None and m.entropy < self.config.entropy_threshold:
                needs_ctp = True
            
            # Check SC_avg threshold
            if m.sc_avg is not None and m.sc_avg < self.config.sc_avg_threshold:
                needs_ctp = True
            
            # Check PO_cos threshold
            if m.po_cos is not None and m.po_cos < self.config.po_cos_threshold:
                needs_otp = True
            
            # Determine test point type
            if needs_ctp and needs_otp:
                candidates.append((signal, "CTP+OTP"))
            elif needs_ctp:
                candidates.append((signal, "CTP"))
            elif needs_otp:
                candidates.append((signal, "OTP"))
        
        return candidates
    
    def _is_clk_or_rst(self, signal: str) -> bool:
        """Check if signal is clock or reset"""
        sig_lower = signal.lower()
        clk_patterns = ['clk', 'clock']
        rst_patterns = ['rst', 'reset', 'rst_n', 'rstn']
        
        for pattern in clk_patterns + rst_patterns:
            if pattern in sig_lower:
                return True
        return False
    
    def insert_testpoints(self, candidates: List[Tuple[str, str]]) -> bool:
        """Insert test points into RTL"""
        if not candidates:
            self.log("No test point candidates identified")
            return True
        
        self.log(f"=== Inserting {len(candidates)} Test Points ===")
        
        # Create backup of RTL
        backup_dir = os.path.join(self.config.work_dir, f"rtl_backup_t{self.tournament_num}")
        if os.path.exists(backup_dir):
            shutil.rmtree(backup_dir)
        shutil.copytree(self.config.rtl_dir, backup_dir)
        
        # Call test point inserter
        candidates_file = f"candidates_t{self.tournament_num}.json"
        cmd = f"python3 testpoint_inserter.py --rtl-dir {self.config.rtl_dir} --candidates {candidates_file}"
        
        # Write candidates to JSON
        candidates_data = [{"signal": sig, "type": tp_type} for sig, tp_type in candidates]
        with open(candidates_file, 'w') as f:
            json.dump(candidates_data, f, indent=2)
        
        rc, stdout, stderr = self.run_command(cmd, cwd=".")
        
        if rc != 0:
            self.log(f"Test point insertion failed: {stderr}", "ERROR")
            # Restore backup
            shutil.rmtree(self.config.rtl_dir)
            shutil.copytree(backup_dir, self.config.rtl_dir)
            return False
        
        self.log(f"Successfully inserted {len(candidates)} test points")
        self.test_points_inserted[self.tournament_num] = candidates
        
        # Regenerate testbench after test point insertion
        if not self.regenerate_testbench():
            self.log("Failed to regenerate testbench, but continuing", "WARNING")
        
        return True
    
    def rollback_bad_testpoints(self, prev_metrics: Dict[str, SignalMetrics], 
                                curr_metrics: Dict[str, SignalMetrics]) -> bool:
        """Check if metrics got worse and rollback if needed"""
        
        if not self.config.enable_rollback:
            return False
        
        if self.tournament_num == 0:
            return False
        
        self.log("=== Checking for Metric Degradation ===")
        
        prev_tps = self.test_points_inserted.get(self.tournament_num - 1, [])
        if not prev_tps:
            return False
        
        degraded_signals = []
        improved_signals = []
        unchanged_signals = []
        
        for signal, tp_type in prev_tps:
            norm_signal = self.normalize_signal_name(signal)
            
            if norm_signal not in prev_metrics or norm_signal not in curr_metrics:
                continue
            
            prev_m = prev_metrics[norm_signal]
            curr_m = curr_metrics[norm_signal]
            
            if curr_m.is_better_than(prev_m):
                improved_signals.append(signal)
            elif prev_m.is_better_than(curr_m):
                degraded_signals.append(signal)
            else:
                unchanged_signals.append(signal)
        
        self.log(f"  Improved: {len(improved_signals)}")
        self.log(f"  Degraded: {len(degraded_signals)}")
        self.log(f"  Unchanged: {len(unchanged_signals)}")
        
        total_checked = len(improved_signals) + len(degraded_signals) + len(unchanged_signals)
        if total_checked > 0:
            bad_ratio = (len(degraded_signals) + len(unchanged_signals)) / total_checked
            
            if bad_ratio > 0.5:
                self.log(f"  Metrics degraded/unchanged for {bad_ratio*100:.1f}% of signals - ROLLBACK", "WARNING")
                
                backup_dir = os.path.join(self.config.work_dir, f"rtl_backup_t{self.tournament_num-1}")
                if os.path.exists(backup_dir):
                    shutil.rmtree(self.config.rtl_dir)
                    shutil.copytree(backup_dir, self.config.rtl_dir)
                    self.log("  Restored RTL from previous tournament")
                    
                    del self.test_points_inserted[self.tournament_num - 1]
                    
                    return True
        
        return False
    
    def compare_metrics(self, prev_metrics: Dict[str, SignalMetrics], 
                       curr_metrics: Dict[str, SignalMetrics]) -> Tuple[bool, float]:
        """Compare metrics between tournaments to decide if we should continue"""
        
        if not prev_metrics or not curr_metrics:
            return False, 0.0
        
        entropy_changes = []
        
        for signal in prev_metrics:
            if signal not in curr_metrics:
                continue
            
            prev_ent = prev_metrics[signal].entropy
            curr_ent = curr_metrics[signal].entropy
            
            if prev_ent is None or curr_ent is None:
                continue
            
            if prev_ent == 0:
                continue
            
            change = abs(curr_ent - prev_ent) / prev_ent
            entropy_changes.append(change)
        
        if not entropy_changes:
            return False, 0.0
        
        avg_change = sum(entropy_changes) / len(entropy_changes)
        max_change = max(entropy_changes)
        
        self.log(f"Entropy change: avg={avg_change:.3f}, max={max_change:.3f}")
        
        should_continue = max_change >= self.config.change_threshold
        return should_continue, max_change
    
    def generate_summary_report(self, metrics: Dict[str, SignalMetrics], 
                               candidates: List[Tuple[str, str]]):
        """Generate summary report for this tournament"""
        
        report_path = os.path.join(self.config.work_dir, f"summary_report_t{self.tournament_num}.txt")
        
        with open(report_path, 'w') as f:
            f.write("=" * 80 + "\n")
            f.write(f"TOURNAMENT {self.tournament_num} SUMMARY REPORT\n")
            f.write("=" * 80 + "\n\n")
            
            f.write(f"Timestamp: {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}\n")
            f.write(f"Total signals analyzed: {len(metrics)}\n\n")
            
            # Entropy statistics
            entropies = [(s, m.entropy) for s, m in metrics.items() if m.entropy is not None]
            if entropies:
                entropies.sort(key=lambda x: x[1], reverse=True)
                f.write("--- Entropy Statistics ---\n")
                f.write(f"Signal with highest entropy: {entropies[0][0]} ({entropies[0][1]:.4f})\n")
                f.write(f"Signal with lowest entropy: {entropies[-1][0]} ({entropies[-1][1]:.4f})\n")
                
                low_entropy = [s for s, e in entropies if e < self.config.entropy_threshold]
                f.write(f"\nSignals below entropy threshold ({self.config.entropy_threshold}):\n")
                f.write(f"Count: {len(low_entropy)}\n")
                for sig in low_entropy[:20]:
                    f.write(f"  - {sig}: {metrics[sig].entropy:.4f}\n")
                if len(low_entropy) > 20:
                    f.write(f"  ... and {len(low_entropy) - 20} more\n")
                f.write("\n")
            
            # SC_avg statistics
            sc_avgs = [(s, m.sc_avg) for s, m in metrics.items() if m.sc_avg is not None]
            if sc_avgs:
                sc_avgs.sort(key=lambda x: x[1])
                f.write("--- Spectral Controllability (SC_avg) Statistics ---\n")
                f.write(f"Signals with lowest SC_avg (hardest to control):\n")
                for sig, sc in sc_avgs[:10]:
                    f.write(f"  - {sig}: {sc:.4f}\n")
                
                low_sc = [s for s, sc in sc_avgs if sc < self.config.sc_avg_threshold]
                f.write(f"\nSignals below SC_avg threshold ({self.config.sc_avg_threshold}): {len(low_sc)}\n\n")
            
            # Observability statistics
            po_coses = [(s, m.po_cos) for s, m in metrics.items() if m.po_cos is not None]
            if po_coses:
                po_coses.sort(key=lambda x: x[1] if x[1] is not None else 1.0)
                f.write("--- Observability (PO_cos) Statistics ---\n")
                f.write(f"Signals with lowest PO_cos (hardest to observe):\n")
                for sig, po in po_coses[:10]:
                    if po is not None:
                        f.write(f"  - {sig}: {po:.4f}\n")
                
                low_po = [s for s, po in po_coses if po is not None and po < self.config.po_cos_threshold]
                f.write(f"\nSignals below PO_cos threshold ({self.config.po_cos_threshold}): {len(low_po)}\n\n")
            
            # Test point insertion
            f.write("--- Test Point Insertion ---\n")
            f.write(f"Number of test points inserted: {len(candidates)}\n\n")
            
            if candidates:
                f.write("Test points inserted:\n")
                ctp_count = sum(1 for _, tp in candidates if 'CTP' in tp)
                otp_count = sum(1 for _, tp in candidates if 'OTP' in tp)
                both_count = sum(1 for _, tp in candidates if tp == 'CTP+OTP')
                
                f.write(f"  Control Test Points (CTP): {ctp_count}\n")
                f.write(f"  Observe Test Points (OTP): {otp_count}\n")
                f.write(f"  Both (CTP+OTP): {both_count}\n\n")
                
                f.write("Details:\n")
                for sig, tp_type in candidates:
                    norm_sig = self.normalize_signal_name(sig)
                    m = metrics.get(norm_sig)
                    if m:
                        entropy_str = f"{m.entropy:.4f}" if m.entropy is not None else "N/A"
                        sc_avg_str = f"{m.sc_avg:.4f}" if m.sc_avg is not None else "N/A"
                        po_cos_str = f"{m.po_cos:.4f}" if m.po_cos is not None else "N/A"
                        
                        f.write(f"  - {sig} ({tp_type}): entropy={entropy_str}, "
                               f"sc_avg={sc_avg_str}, po_cos={po_cos_str}\n")
            
            f.write("\n" + "=" * 80 + "\n")
        
        self.log(f"Summary report written to {report_path}")
        self.summary_reports.append(report_path)
    
    def run_tournament(self) -> bool:
        """Execute one complete tournament"""
        self.log(f"\n{'='*80}")
        self.log(f"STARTING TOURNAMENT {self.tournament_num}")
        self.log(f"{'='*80}\n")
        
        # Step 1: Compile design
        if not self.compile_design():
            return False
        
        # Step 2: Run simulation
        if not self.run_simulation():
            return False
        
        # Step 3: Parse VCD
        if not self.parse_vcd():
            return False
        
        # Step 4: Calculate metrics (combined entropy + spectral)
        if not self.calculate_metrics():
            return False
        
        # Step 5: Parse metrics from CSV
        metrics = self.parse_metrics()
        self.metrics_history[self.tournament_num] = metrics
        
        # Step 6: Check for rollback (if not first tournament)
        if self.tournament_num > 0:
            prev_metrics = self.metrics_history.get(self.tournament_num - 1)
            if self.rollback_bad_testpoints(prev_metrics, metrics):
                self.log("Rolled back due to bad metrics - ending tournaments")
                return True
        
        # Step 7: Identify test point candidates
        candidates = self.identify_testpoint_candidates(metrics)
        
        # Step 8: Generate summary report
        self.generate_summary_report(metrics, candidates)
        
        # Step 9: Insert test points (if any)
        if candidates:
            if not self.insert_testpoints(candidates):
                return False
        
        self.log(f"\nTournament {self.tournament_num} completed successfully\n")
        return True
    
    def should_continue(self) -> Tuple[bool, str]:
        """Determine if we should run another tournament"""
        
        if self.tournament_num >= self.config.max_tournaments:
            return False, f"Reached maximum tournaments ({self.config.max_tournaments})"
        
        if self.tournament_num == 0:
            if self.test_points_inserted.get(0):
                return True, "First tournament completed, test points inserted"
            else:
                return False, "No test points needed"
        
        prev_metrics = self.metrics_history.get(self.tournament_num - 1)
        curr_metrics = self.metrics_history.get(self.tournament_num)
        
        should_cont, change = self.compare_metrics(prev_metrics, curr_metrics)
        
        if should_cont:
            return True, f"Entropy change ({change:.3f}) exceeds threshold ({self.config.change_threshold})"
        else:
            return False, f"Entropy change ({change:.3f}) below threshold ({self.config.change_threshold})"
    
    def run(self):
        """Main execution loop"""
        self.log("ZEBRA Tournament Orchestrator Starting")
        self.log(f"Configuration: {asdict(self.config)}")
        
        while self.tournament_num < self.config.max_tournaments:
            if not self.run_tournament():
                self.log(f"Tournament {self.tournament_num} failed", "ERROR")
                break
            
            should_cont, reason = self.should_continue()
            self.log(f"Continue decision: {should_cont} - {reason}")
            
            if not should_cont:
                break
            
            self.tournament_num += 1
        
        self.generate_final_summary()
        
        self.log("\n" + "="*80)
        self.log("ZEBRA Tournament Orchestrator Completed")
        self.log("="*80)
        
        self.log_file.close()
    
    def generate_final_summary(self):
        """Generate final summary across all tournaments"""
        summary_path = os.path.join(self.config.work_dir, "final_summary.txt")
        
        with open(summary_path, 'w') as f:
            f.write("=" * 80 + "\n")
            f.write("ZEBRA - FINAL SUMMARY - ALL TOURNAMENTS\n")
            f.write("=" * 80 + "\n\n")
            
            f.write(f"Total tournaments executed: {self.tournament_num + 1}\n")
            f.write(f"Timestamp: {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}\n\n")
            
            total_tps = sum(len(tps) for tps in self.test_points_inserted.values())
            f.write(f"Total test points inserted: {total_tps}\n\n")
            
            f.write("Test points per tournament:\n")
            for t_num, tps in self.test_points_inserted.items():
                f.write(f"  Tournament {t_num}: {len(tps)} test points\n")
            f.write("\n")
            
            f.write("Metrics Evolution:\n")
            for t_num in sorted(self.metrics_history.keys()):
                metrics = self.metrics_history[t_num]
                entropies = [m.entropy for m in metrics.values() if m.entropy is not None]
                if entropies:
                    avg_ent = sum(entropies) / len(entropies)
                    min_ent = min(entropies)
                    max_ent = max(entropies)
                    f.write(f"  Tournament {t_num}: avg_entropy={avg_ent:.4f}, "
                           f"min={min_ent:.4f}, max={max_ent:.4f}\n")
            
            f.write("\n" + "=" * 80 + "\n")
        
        self.log(f"Final summary written to {summary_path}")


def main():
    parser = argparse.ArgumentParser(
        description="ZEBRA - Automated Test Point Insertion Tournament Manager",
        formatter_class=argparse.RawDescriptionHelpFormatter
    )
    
    parser.add_argument("--config", help="JSON configuration file")
    parser.add_argument("--rtl-dir", default="rtl", help="RTL directory")
    parser.add_argument("--tb-dir", default="tb", help="Testbench directory")
    parser.add_argument("--entropy-thresh", type=float, default=0.14)
    parser.add_argument("--sc-thresh", type=float, default=5.0)
    parser.add_argument("--po-thresh", type=float, default=0.5)
    parser.add_argument("--change-thresh", type=float, default=0.20)
    parser.add_argument("--max-tournaments", type=int, default=10)
    parser.add_argument("--sim-cycles", type=int, default=50000)
    parser.add_argument("--main-design", help="Main design file")
    parser.add_argument("--no-rollback", action="store_true", help="Disable rollback on bad metrics")
    
    args = parser.parse_args()
    
    print("--------------------------- ZEBRA TPI TOURNAMENT ----------------------")
    
    if args.config and os.path.exists(args.config):
        with open(args.config) as f:
            config_dict = json.load(f)
        config = TournamentConfig.from_dict(config_dict)
    else:
        config = TournamentConfig()
    
    if args.rtl_dir:
        config.rtl_dir = args.rtl_dir
    if args.tb_dir:
        config.tb_dir = args.tb_dir
    if args.main_design:
        config.main_design_file = args.main_design
    if args.no_rollback:
        config.enable_rollback = False
        
    config.entropy_threshold = args.entropy_thresh
    config.sc_avg_threshold = args.sc_thresh
    config.po_cos_threshold = args.po_thresh
    config.change_threshold = args.change_thresh
    config.max_tournaments = args.max_tournaments
    config.sim_cycles = args.sim_cycles
    
    orchestrator = TournamentOrchestrator(config)
    orchestrator.run()


if __name__ == "__main__":
    main()
