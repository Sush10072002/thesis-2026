#!/usr/bin/env python3
"""
testpoint_inserter.py - Automatic Test Point Insertion for Verilog RTL

FIXED: 
- Prevents duplicate insertions
- Better signal location handling
- Tracks what was actually inserted
"""

import argparse
import json
import os
import re
import shutil
from pathlib import Path
from typing import List, Dict, Tuple, Optional, Set
from dataclasses import dataclass


@dataclass
class TestPoint:
    """Represents a test point to be inserted"""
    signal_name: str
    tp_type: str
    module_file: Optional[str] = None
    line_number: Optional[int] = None


@dataclass
class SignalLocation:
    """Location information for a signal"""
    signal_name: str
    module_name: str
    filepath: str
    sig_type: str
    bit_width: str
    decl_line: int
    is_port: bool = False


class VerilogParser:
    """Parse Verilog files to locate signals and insertion points"""
    
    def __init__(self, filepath: str):
        self.filepath = filepath
        with open(filepath, 'r') as f:
            self.content = f.read()
            f.seek(0)
            self.lines = f.readlines()
        
        self.module_name = None
        self.ports = {}
        self.signals = {}
        self.all_signals = {}
        
        self._parse()
    
    def _parse(self):
        """Parse the Verilog file"""
        module_match = re.search(r'module\s+(\w+)', self.content)
        if module_match:
            self.module_name = module_match.group(1)
        
        self._parse_ports()
        self._parse_signals()
        self.all_signals = {**self.ports, **self.signals}
    
    def _parse_ports(self):
        """Parse input/output/inout port declarations"""
        for i, line in enumerate(self.lines):
            patterns = [
                r'(input|output|inout)\s+(reg|wire)?\s*(\[[^\]]+\])?\s*(\w+)',
                r'(input|output|inout)\s+(\[[^\]]+\])?\s*(\w+)',
            ]
            
            for pattern in patterns:
                match = re.search(pattern, line)
                if match:
                    groups = match.groups()
                    direction = groups[0]
                    
                    if len(groups) == 4:
                        bit_width = groups[2] if groups[2] else ""
                        sig_name = groups[3]
                    else:
                        bit_width = groups[1] if groups[1] and '[' in groups[1] else ""
                        sig_name = groups[2]
                    
                    remaining = line[match.end():]
                    signals_on_line = [sig_name]
                    
                    for extra_sig in re.findall(r',\s*(\w+)', remaining):
                        signals_on_line.append(extra_sig)
                    
                    for sig in signals_on_line:
                        self.ports[sig] = (direction, bit_width, i)
                    break
    
    def _parse_signals(self):
        """Parse internal reg/wire declarations"""
        for i, line in enumerate(self.lines):
            # Match both 'reg' and 'reg signed'
            match = re.match(r'\s*(reg|wire)\s+(signed\s+)?(\[[^\]]+\])?\s*(\w+)', line)
            if match:
                sig_type = match.group(1)
                bit_width = match.group(3) if match.group(3) else ""
                sig_name = match.group(4)
                
                if sig_name not in self.ports:
                    remaining = line[match.end():]
                    signals_on_line = [sig_name]
                    
                    # Handle comma-separated signals
                    for extra_match in re.finditer(r',\s*(\w+)', remaining):
                        signals_on_line.append(extra_match.group(1))
                    
                    for sig in signals_on_line:
                        if sig not in self.ports:
                            self.signals[sig] = (sig_type, bit_width, i)
    
    def find_signal(self, signal_name: str) -> Optional[SignalLocation]:
        """Find a signal in this module"""
        if '.' in signal_name:
            parts = signal_name.split('.')
            sig_name = parts[-1]
        else:
            sig_name = signal_name
        
        if sig_name in self.ports:
            direction, bit_width, line_num = self.ports[sig_name]
            return SignalLocation(
                signal_name=sig_name,
                module_name=self.module_name,
                filepath=self.filepath,
                sig_type=direction,
                bit_width=bit_width,
                decl_line=line_num,
                is_port=True
            )
        
        if sig_name in self.signals:
            sig_type, bit_width, line_num = self.signals[sig_name]
            return SignalLocation(
                signal_name=sig_name,
                module_name=self.module_name,
                filepath=self.filepath,
                sig_type=sig_type,
                bit_width=bit_width,
                decl_line=line_num,
                is_port=False
            )
        
        return None
    
    def find_insertion_point(self, signal_name: str) -> Optional[int]:
        """Find the best line to insert test point logic"""
        sig_loc = self.find_signal(signal_name)
        if not sig_loc:
            return None
        
        for i in range(sig_loc.decl_line + 1, len(self.lines)):
            line = self.lines[i].strip()
            
            if not line or line.startswith('//'):
                continue
            
            if line.startswith('always') or line.startswith('assign') or line.startswith('initial'):
                return i
        
        for i in range(len(self.lines) - 1, -1, -1):
            if 'endmodule' in self.lines[i]:
                return i
        
        return None
    
    def write(self, filepath: str = None):
        """Write modified content back to file"""
        target = filepath or self.filepath
        with open(target, 'w') as f:
            f.writelines(self.lines)


class TestPointInserter:
    """Insert test points into Verilog RTL files"""
    
    def __init__(self, rtl_dir: str):
        self.rtl_dir = rtl_dir
        self.parsers = {}
        self.module_map = {}
        self.signal_locations = {}
        self.tp_counter = 0
        self.modified_files = set()
        self.inserted_tps = {}  # {signal_name: (tp_type, counter_used)}
        
        self._parse_all_files()
        self._build_signal_index()
    
    def _is_test_point_signal(self, signal_name: str) -> bool:
        """Check if a signal is a test point signal"""
        sig_lower = signal_name.lower()
        tp_patterns = ['tp_ctrl_', 'tp_obs_', '_ctp', '_otp', 'testpoint', 'test_point']
        return any(pattern in sig_lower for pattern in tp_patterns)
    
    def _normalize_signal_name(self, signal_name: str) -> str:
        """Normalize signal name by removing hierarchy prefixes"""
        if '.' in signal_name:
            parts = signal_name.split('.')
            return parts[-1]
        return signal_name
    
    def _parse_all_files(self):
        """Parse all Verilog files in RTL directory"""
        verilog_files = list(Path(self.rtl_dir).glob("*.v"))
        
        print(f"\n{'='*80}")
        print(f"Parsing {len(verilog_files)} Verilog files")
        print(f"{'='*80}\n")
        
        for vfile in verilog_files:
            parser = VerilogParser(str(vfile))
            self.parsers[str(vfile)] = parser
            
            if parser.module_name:
                self.module_map[parser.module_name] = str(vfile)
                print(f"  [OK] Parsed {vfile.name}: module {parser.module_name} "
                      f"({len(parser.ports)} ports, {len(parser.signals)} signals)")
            else:
                print(f"  [WARNING] No module found in {vfile.name}")
    
    def _build_signal_index(self):
        """Build an index of all signals across all modules"""
        for filepath, parser in self.parsers.items():
            for sig_name in parser.all_signals:
                if self._is_test_point_signal(sig_name):
                    continue
                    
                loc = parser.find_signal(sig_name)
                if loc:
                    if sig_name not in self.signal_locations:
                        self.signal_locations[sig_name] = []
                    self.signal_locations[sig_name].append(loc)
    
    def locate_signal(self, signal_name: str) -> Optional[SignalLocation]:
        """Locate which file and module contains the signal"""
        
        # Normalize the signal name
        norm_name = self._normalize_signal_name(signal_name)
        
        # Check if this is a test point signal
        if self._is_test_point_signal(norm_name):
            print(f"  [SKIP] {signal_name} is a test point signal")
            return None
        
        # Search in signal index
        if norm_name in self.signal_locations:
            for loc in self.signal_locations[norm_name]:
                if not loc.module_name.startswith('tb_'):
                    return loc
            return self.signal_locations[norm_name][0] if self.signal_locations[norm_name] else None
        
        # Fallback: search all parsers
        for filepath, parser in self.parsers.items():
            loc = parser.find_signal(norm_name)
            if loc and not loc.module_name.startswith('tb_'):
                return loc
        
        return None
    
    def insert_control_testpoint(self, location: SignalLocation) -> bool:
        """Insert a control test point (CTP)"""
        
        # Check if already inserted
        if location.signal_name in self.inserted_tps:
            prev_type, prev_counter = self.inserted_tps[location.signal_name]
            print(f"  [SKIP] CTP already exists for {location.signal_name} (tp_ctrl_{prev_counter})")
            return True
        
        parser = self.parsers[location.filepath]
        insertion_point = parser.find_insertion_point(location.signal_name)
        
        if insertion_point is None:
            print(f"  [WARNING] Could not find insertion point for {location.signal_name}")
            return False
        
        # Use current counter value
        current_tp_num = self.tp_counter
        tp_enable = f"tp_ctrl_{current_tp_num}_enable"
        tp_value = f"tp_ctrl_{current_tp_num}_value"
        ctp_signal = f"{location.signal_name}_ctp"
        
        # Increment counter for next TP
        self.tp_counter += 1
        
        # Determine bit width (handle 'signed' keyword)
        width_str = location.bit_width if location.bit_width else ""
        
        # Generate test point logic
        tp_lines = [
            f"\n// === Control Test Point #{current_tp_num} for {location.signal_name} ===\n",
            f"reg {width_str} {tp_enable};\n",
            f"reg {width_str} {tp_value};\n",
            f"wire {width_str} {ctp_signal} = {tp_enable} ? {tp_value} : {location.signal_name};\n",
            f"\n",
            f"initial begin\n",
            f"    {tp_enable} = 0;\n",
            f"    {tp_value} = 0;\n",
            f"end\n",
            f"\n"
        ]
        
        # Insert the lines
        for line in reversed(tp_lines):
            parser.lines.insert(insertion_point, line)
        
        self.modified_files.add(location.filepath)
        self.inserted_tps[location.signal_name] = ("CTP", current_tp_num)
        
        print(f"  [OK] Inserted CTP #{current_tp_num} for {location.signal_name} in {Path(location.filepath).name}")
        print(f"       Signals: {tp_enable}, {tp_value}, {ctp_signal}")
        return True
    
    def insert_observe_testpoint(self, location: SignalLocation) -> bool:
        """Insert an observe test point (OTP)"""
        
        otp_marker = f"{location.signal_name}_otp"
        if otp_marker in self.inserted_tps:
            prev_type, prev_counter = self.inserted_tps[otp_marker]
            print(f"  [SKIP] OTP already exists for {location.signal_name} (tp_obs_{prev_counter})")
            return True
        
        parser = self.parsers[location.filepath]
        insertion_point = parser.find_insertion_point(location.signal_name)
        
        if insertion_point is None:
            print(f"  [WARNING] Could not find insertion point for {location.signal_name}")
            return False
        
        current_tp_num = self.tp_counter
        tp_name = f"tp_obs_{current_tp_num}"
        self.tp_counter += 1
        
        width_str = location.bit_width if location.bit_width else ""
        
        tp_lines = [
            f"\n// === Observe Test Point #{current_tp_num} for {location.signal_name} ===\n",
            f"wire {width_str} {tp_name} = {location.signal_name};\n",
            f"\n"
        ]
        
        for line in reversed(tp_lines):
            parser.lines.insert(insertion_point, line)
        
        self.modified_files.add(location.filepath)
        self.inserted_tps[otp_marker] = ("OTP", current_tp_num)
        
        print(f"  [OK] Inserted OTP #{current_tp_num} for {location.signal_name} in {Path(location.filepath).name}")
        return True
    
    def insert_testpoint(self, testpoint: TestPoint) -> bool:
        """Insert a test point based on its type"""
        
        location = self.locate_signal(testpoint.signal_name)
        if not location:
            print(f"  [ERROR] Could not locate signal: {testpoint.signal_name}")
            print(f"         Available signals: {list(self.signal_locations.keys())[:10]}...")
            return False
        
        success = True
        
        if "CTP" in testpoint.tp_type:
            if not self.insert_control_testpoint(location):
                success = False
        
        if "OTP" in testpoint.tp_type:
            if not self.insert_observe_testpoint(location):
                success = False
        
        return success
    
    def write_modified_files(self):
        """Write all modified Verilog files back to disk"""
        print(f"\n{'='*80}")
        print(f"Writing {len(self.modified_files)} modified files")
        print(f"{'='*80}\n")
        
        for filepath in self.modified_files:
            parser = self.parsers[filepath]
            parser.write()
            print(f"  [WRITE] {Path(filepath).name}")
    
    def get_insertion_summary(self) -> Dict:
        """Get summary of what was inserted"""
        summary = {
            "total_inserted": len(self.inserted_tps),
            "ctp_count": sum(1 for tp_type, _ in self.inserted_tps.values() if tp_type == "CTP"),
            "otp_count": sum(1 for tp_type, _ in self.inserted_tps.values() if tp_type == "OTP"),
            "signals": list(self.inserted_tps.keys()),
            "modified_files": list(self.modified_files)
        }
        return summary
    
    def insert_all(self, testpoints: List[TestPoint]) -> int:
        """Insert all test points and return count of successful insertions"""
        
        print(f"\n{'='*80}")
        print(f"Inserting {len(testpoints)} test points")
        print(f"{'='*80}\n")
        
        # Filter out test point signals
        filtered_testpoints = []
        for tp in testpoints:
            norm_name = self._normalize_signal_name(tp.signal_name)
            if self._is_test_point_signal(norm_name):
                print(f"[FILTER] Skipping test point signal: {tp.signal_name}")
            else:
                filtered_testpoints.append(tp)
        
        print(f"\nAfter filtering: {len(filtered_testpoints)} valid test points\n")
        
        success_count = 0
        failed = []
        
        for idx, tp in enumerate(filtered_testpoints, 1):
            print(f"\n[{idx}/{len(filtered_testpoints)}] Processing: {tp.signal_name} ({tp.tp_type})")
            if self.insert_testpoint(tp):
                success_count += 1
            else:
                failed.append(tp.signal_name)
        
        # Write all modified files
        if self.modified_files:
            self.write_modified_files()
        
        # Get insertion summary
        summary = self.get_insertion_summary()
        
        # Summary
        print(f"\n{'='*80}")
        print(f"Test Point Insertion Summary")
        print(f"{'='*80}")
        print(f"  Total requested: {len(testpoints)}")
        print(f"  Filtered out (TP signals): {len(testpoints) - len(filtered_testpoints)}")
        print(f"  Successfully inserted: {success_count}")
        print(f"  Failed: {len(failed)}")
        print(f"  CTPs inserted: {summary['ctp_count']}")
        print(f"  OTPs inserted: {summary['otp_count']}")
        
        if failed:
            print(f"\nFailed signals:")
            for sig in failed:
                print(f"    - {sig}")
        
        print(f"\nSignals with test points:")
        for sig in summary['signals']:
            if not sig.endswith('_otp'):
                tp_type, tp_num = self.inserted_tps[sig]
                print(f"    - {sig}: {tp_type} #{tp_num}")
        
        print(f"\nModified files ({len(self.modified_files)}):")
        for filepath in sorted(self.modified_files):
            print(f"    - {Path(filepath).name}")
        
        print(f"{'='*80}\n")
        
        # Write summary to JSON
        summary_file = "testpoint_insertion_summary.json"
        with open(summary_file, 'w') as f:
            json.dump(summary, f, indent=2)
        print(f"Wrote insertion summary to {summary_file}\n")
        
        return success_count


def main():
    parser = argparse.ArgumentParser(
        description="Insert test points into Verilog RTL"
    )
    parser.add_argument("--rtl-dir", required=True, help="RTL directory")
    parser.add_argument("--candidates", required=True, help="JSON file with test point candidates")
    parser.add_argument("--backup", action="store_true", help="Create backup before modification")
    
    args = parser.parse_args()
    
    if not os.path.exists(args.rtl_dir):
        print(f"ERROR: RTL directory not found: {args.rtl_dir}")
        return 1
    
    if not os.path.exists(args.candidates):
        print(f"ERROR: Candidates file not found: {args.candidates}")
        return 1
    
    if args.backup:
        from datetime import datetime
        backup_dir = args.rtl_dir + "_backup_" + datetime.now().strftime("%Y%m%d_%H%M%S")
        shutil.copytree(args.rtl_dir, backup_dir)
        print(f"[BACKUP] Created backup at {backup_dir}\n")
    
    with open(args.candidates) as f:
        candidates_data = json.load(f)
    
    testpoints = [
        TestPoint(signal_name=c["signal"], tp_type=c["type"])
        for c in candidates_data
    ]
    
    inserter = TestPointInserter(args.rtl_dir)
    success_count = inserter.insert_all(testpoints)
    
    return 0 if success_count > 0 else 1


if __name__ == "__main__":
    from datetime import datetime
    exit(main())
