#!/usr/bin/env python3
"""
testpoint_inserter.py - Automatic Test Point Insertion for Verilog RTL

Inserts control test points (CTP) and observe test points (OTP) into Verilog RTL.
Supports multi-file RTL designs and hierarchical signal references.

FIXED: Now ignores test point signals to prevent inserting TPs on TPs.

Usage:
    python3 testpoint_inserter.py --rtl-dir rtl --candidates candidates.json
"""

import argparse
import json
import os
import re
import shutil
from pathlib import Path
from typing import List, Dict, Tuple, Optional, Set
from dataclasses import dataclass
from collections import defaultdict


@dataclass
class TestPoint:
    """Represents a test point to be inserted"""
    signal_name: str
    tp_type: str  # "CTP", "OTP", or "CTP+OTP"
    module_file: Optional[str] = None
    line_number: Optional[int] = None


@dataclass
class SignalLocation:
    """Location information for a signal"""
    signal_name: str
    module_name: str
    filepath: str
    sig_type: str  # "reg", "wire", "input", "output", "inout"
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
        self.ports = {}  # {signal_name: (direction, bit_width, line_number)}
        self.signals = {}  # {signal_name: (type, bit_width, line_number)}
        self.all_signals = {}  # Combined ports and signals
        
        self._parse()
    
    def _parse(self):
        """Parse the Verilog file"""
        # Find module name
        module_match = re.search(r'module\s+(\w+)', self.content)
        if module_match:
            self.module_name = module_match.group(1)
        
        # Parse port declarations
        self._parse_ports()
        
        # Parse internal signal declarations
        self._parse_signals()
        
        # Combine all signals
        self.all_signals = {**self.ports, **self.signals}
    
    def _parse_ports(self):
        """Parse input/output/inout port declarations"""
        for i, line in enumerate(self.lines):
            # Match port declarations: input/output/inout [width] name
            patterns = [
                r'(input|output|inout)\s+(reg|wire)?\s*(\[[^\]]+\])?\s*(\w+)',
                r'(input|output|inout)\s+(\[[^\]]+\])?\s*(\w+)',
            ]
            
            for pattern in patterns:
                match = re.search(pattern, line)
                if match:
                    groups = match.groups()
                    direction = groups[0]
                    
                    # Extract bit width and signal name
                    if len(groups) == 4:
                        bit_width = groups[2] if groups[2] else ""
                        sig_name = groups[3]
                    else:
                        bit_width = groups[1] if groups[1] and '[' in groups[1] else ""
                        sig_name = groups[2]
                    
                    # Handle multiple signals on same line
                    remaining = line[match.end():]
                    signals_on_line = [sig_name]
                    
                    # Check for comma-separated signals
                    for extra_sig in re.findall(r',\s*(\w+)', remaining):
                        signals_on_line.append(extra_sig)
                    
                    for sig in signals_on_line:
                        self.ports[sig] = (direction, bit_width, i)
                    break
    
    def _parse_signals(self):
        """Parse internal reg/wire declarations"""
        for i, line in enumerate(self.lines):
            # Match signal declarations: reg/wire [width] name
            match = re.match(r'\s*(reg|wire)\s+(\[[^\]]+\])?\s*(\w+)', line)
            if match:
                sig_type = match.group(1)
                bit_width = match.group(2) if match.group(2) else ""
                sig_name = match.group(3)
                
                # Skip if it's already a port
                if sig_name not in self.ports:
                    # Handle multiple signals on same line
                    remaining = line[match.end():]
                    signals_on_line = [sig_name]
                    
                    for extra_sig in re.findall(r',\s*(\w+)', remaining):
                        signals_on_line.append(extra_sig)
                    
                    for sig in signals_on_line:
                        if sig not in self.ports:
                            self.signals[sig] = (sig_type, bit_width, i)
    
    def find_signal(self, signal_name: str) -> Optional[SignalLocation]:
        """Find a signal in this module"""
        # Handle hierarchical names (e.g., dut.signal_name)
        if '.' in signal_name:
            parts = signal_name.split('.')
            sig_name = parts[-1]
        else:
            sig_name = signal_name
        
        # Check ports first
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
        
        # Check internal signals
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
        
        # Find the end of signal declarations (before always/assign blocks)
        for i in range(sig_loc.decl_line + 1, len(self.lines)):
            line = self.lines[i].strip()
            
            # Skip empty lines and comments
            if not line or line.startswith('//'):
                continue
            
            # Insert before first behavioral block
            if line.startswith('always') or line.startswith('assign') or line.startswith('initial'):
                return i
        
        # If no behavioral block found, insert before endmodule
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
        self.parsers = {}  # {filepath: VerilogParser}
        self.module_map = {}  # {module_name: filepath}
        self.signal_locations = {}  # {signal_name: [SignalLocation]}
        self.tp_counter = 0
        self.modified_files = set()
        
        # Track inserted test points to avoid duplicates
        self.inserted_tps = set()  # Set of signal names that already have TPs
        
        # Parse all Verilog files
        self._parse_all_files()
        
        # Build signal location index
        self._build_signal_index()
    
    def _is_test_point_signal(self, signal_name: str) -> bool:
        """
        Check if a signal is a test point signal.
        Test point signals should NOT have test points inserted on them.
        """
        sig_lower = signal_name.lower()
        
        # Patterns that indicate this is a test point signal
        tp_patterns = [
            'tp_ctrl_',
            'tp_obs_',
            '_ctp',
            '_otp',
            'testpoint',
            'test_point'
        ]
        
        for pattern in tp_patterns:
            if pattern in sig_lower:
                return True
        
        return False
    
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
                # Skip test point signals from indexing
                if self._is_test_point_signal(sig_name):
                    continue
                    
                loc = parser.find_signal(sig_name)
                if loc:
                    if sig_name not in self.signal_locations:
                        self.signal_locations[sig_name] = []
                    self.signal_locations[sig_name].append(loc)
    
    def locate_signal(self, signal_name: str) -> Optional[SignalLocation]:
        """Locate which file and module contains the signal"""
        
        # CRITICAL: Check if this is a test point signal
        if self._is_test_point_signal(signal_name):
            print(f"  [SKIP] {signal_name} is a test point signal, ignoring")
            return None
        
        # Handle hierarchical names (e.g., dut.signal_name, tb_top.dut.signal)
        if '.' in signal_name:
            parts = signal_name.split('.')
            
            # Try to identify module from hierarchy
            # Common patterns: dut.signal, tb_top.dut.signal
            module_hint = None
            sig_name = parts[-1]
            
            if len(parts) >= 2:
                # Look for non-testbench module names
                for part in reversed(parts[:-1]):
                    if not part.startswith('tb_') and part != 'tb_top':
                        module_hint = part
                        break
            
            # Search in hinted module first
            if module_hint and module_hint in self.module_map:
                filepath = self.module_map[module_hint]
                parser = self.parsers[filepath]
                loc = parser.find_signal(sig_name)
                if loc:
                    return loc
        else:
            sig_name = signal_name
        
        # Search in signal index
        if sig_name in self.signal_locations:
            # Return first non-testbench location
            for loc in self.signal_locations[sig_name]:
                if not loc.module_name.startswith('tb_'):
                    return loc
            # If all are testbench, return first
            return self.signal_locations[sig_name][0]
        
        # Fallback: search all parsers
        for filepath, parser in self.parsers.items():
            loc = parser.find_signal(sig_name)
            if loc and not loc.module_name.startswith('tb_'):
                return loc
        
        return None
    
    def insert_control_testpoint(self, location: SignalLocation) -> bool:
        """Insert a control test point (CTP)"""
        
        # Check if already inserted
        if location.signal_name in self.inserted_tps:
            print(f"  [SKIP] CTP already exists for {location.signal_name}")
            return True
        
        parser = self.parsers[location.filepath]
        insertion_point = parser.find_insertion_point(location.signal_name)
        
        if insertion_point is None:
            print(f"  [WARNING] Could not find insertion point for {location.signal_name}")
            return False
        
        # Generate test point name
        tp_name = f"tp_ctrl_{self.tp_counter}"
        tp_enable = f"{tp_name}_enable"
        tp_value = f"{tp_name}_value"
        ctp_signal = f"{location.signal_name}_ctp"
        self.tp_counter += 1
        
        # Determine bit width
        width_str = location.bit_width if location.bit_width else ""
        
        # Generate test point logic
        tp_lines = [
            f"\n// === Control Test Point for {location.signal_name} ===\n",
            f"reg {width_str} {tp_enable};\n",
            f"reg {width_str} {tp_value};\n",
            f"wire {width_str} {ctp_signal} = {tp_enable} ? {tp_value} : {location.signal_name};\n",
        ]
        
        # Initialize test point control signals
        init_lines = [
            f"// Initialize CTP for {location.signal_name}\n",
            f"initial begin\n",
            f"    {tp_enable} = 0;\n",
            f"    {tp_value} = 0;\n",
            f"end\n",
            f"\n"
        ]
        
        # Insert the lines
        for line in reversed(tp_lines + init_lines):
            parser.lines.insert(insertion_point, line)
        
        self.modified_files.add(location.filepath)
        self.inserted_tps.add(location.signal_name)
        
        print(f"  [OK] Inserted CTP for {location.signal_name} in {Path(location.filepath).name}::{location.module_name}")
        print(f"       Control signal: {ctp_signal}")
        return True
    
    def insert_observe_testpoint(self, location: SignalLocation) -> bool:
        """Insert an observe test point (OTP)"""
        
        # Check if already inserted (using different marker)
        otp_marker = f"{location.signal_name}_otp"
        if otp_marker in self.inserted_tps:
            print(f"  [SKIP] OTP already exists for {location.signal_name}")
            return True
        
        parser = self.parsers[location.filepath]
        insertion_point = parser.find_insertion_point(location.signal_name)
        
        if insertion_point is None:
            print(f"  [WARNING] Could not find insertion point for {location.signal_name}")
            return False
        
        # Generate test point name
        tp_name = f"tp_obs_{self.tp_counter}"
        self.tp_counter += 1
        
        # Determine bit width
        width_str = location.bit_width if location.bit_width else ""
        
        # Generate test point logic
        # OTP: Create an observable wire that tracks the signal
        tp_lines = [
            f"\n// === Observe Test Point for {location.signal_name} ===\n",
            f"wire {width_str} {tp_name} = {location.signal_name};\n",
            f"// This signal can be monitored for observability\n",
            f"\n"
        ]
        
        # Insert the lines
        for line in reversed(tp_lines):
            parser.lines.insert(insertion_point, line)
        
        self.modified_files.add(location.filepath)
        self.inserted_tps.add(otp_marker)
        
        print(f"  [OK] Inserted OTP for {location.signal_name} in {Path(location.filepath).name}::{location.module_name}")
        return True
    
    def insert_testpoint(self, testpoint: TestPoint) -> bool:
        """Insert a test point based on its type"""
        
        # Locate the signal
        location = self.locate_signal(testpoint.signal_name)
        if not location:
            print(f"  [ERROR] Could not locate signal: {testpoint.signal_name}")
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
    
    def insert_all(self, testpoints: List[TestPoint]) -> int:
        """Insert all test points and return count of successful insertions"""
        
        print(f"\n{'='*80}")
        print(f"Inserting {len(testpoints)} test points")
        print(f"{'='*80}\n")
        
        # Filter out test point signals
        filtered_testpoints = []
        for tp in testpoints:
            if self._is_test_point_signal(tp.signal_name):
                print(f"[FILTER] Skipping test point signal: {tp.signal_name}")
            else:
                filtered_testpoints.append(tp)
        
        print(f"\nAfter filtering: {len(filtered_testpoints)} valid test points\n")
        
        success_count = 0
        failed = []
        
        for idx, tp in enumerate(filtered_testpoints, 1):
            print(f"[{idx}/{len(filtered_testpoints)}] Processing: {tp.signal_name} ({tp.tp_type})")
            if self.insert_testpoint(tp):
                success_count += 1
            else:
                failed.append(tp.signal_name)
        
        # Write all modified files
        if self.modified_files:
            self.write_modified_files()
        
        # Summary
        print(f"\n{'='*80}")
        print(f"Test Point Insertion Summary")
        print(f"{'='*80}")
        print(f"  Total requested: {len(testpoints)}")
        print(f"  Filtered out (TP signals): {len(testpoints) - len(filtered_testpoints)}")
        print(f"  Successfully inserted: {success_count}")
        print(f"  Failed: {len(failed)}")
        
        if failed:
            print(f"\nFailed signals:")
            for sig in failed:
                print(f"    - {sig}")
        
        print(f"\nModified files ({len(self.modified_files)}):")
        for filepath in sorted(self.modified_files):
            print(f"    - {Path(filepath).name}")
        
        print(f"{'='*80}\n")
        
        return success_count


def main():
    parser = argparse.ArgumentParser(
        description="Insert test points into Verilog RTL (supports multi-file designs, prevents TP-on-TP)"
    )
    parser.add_argument("--rtl-dir", required=True, help="RTL directory")
    parser.add_argument("--candidates", required=True, help="JSON file with test point candidates")
    parser.add_argument("--backup", action="store_true", help="Create backup before modification")
    
    args = parser.parse_args()
    
    # Validate inputs
    if not os.path.exists(args.rtl_dir):
        print(f"ERROR: RTL directory not found: {args.rtl_dir}")
        return 1
    
    if not os.path.exists(args.candidates):
        print(f"ERROR: Candidates file not found: {args.candidates}")
        return 1
    
    # Create backup if requested
    if args.backup:
        from datetime import datetime
        backup_dir = args.rtl_dir + "_backup_" + datetime.now().strftime("%Y%m%d_%H%M%S")
        shutil.copytree(args.rtl_dir, backup_dir)
        print(f"[BACKUP] Created backup at {backup_dir}\n")
    
    # Load candidates
    with open(args.candidates) as f:
        candidates_data = json.load(f)
    
    testpoints = [
        TestPoint(signal_name=c["signal"], tp_type=c["type"])
        for c in candidates_data
    ]
    
    # Insert test points
    inserter = TestPointInserter(args.rtl_dir)
    success_count = inserter.insert_all(testpoints)
    
    return 0 if success_count > 0 else 1


if __name__ == "__main__":
    from datetime import datetime
    exit(main())
