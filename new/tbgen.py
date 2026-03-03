#! /usr/bin/python
# -*- coding: utf-8 -*-

# THE BEER-WARE LICENSE" (Revision 42):
# <xfguo@xfguo.org> wrote this file. As long as you retain this notice you
# can do whatever you want with this stuff. If we meet some day, and you think
# this stuff is worth it, you can buy me a beer in return Xiongfei(Alex) Guo.

'''
Created on 2010-4-23
Modified on 2026-02-04 - Enhanced for comprehensive testbench generation with FSM detection

@author: Alex Guo
@modifier: Enhanced version with FSM detection and state-aware testing
'''

import re
import sys
import os

class TestbenchGenerator(object):
    '''
    verilog test bench auto generation with comprehensive coverage and FSM detection
    '''

    def __init__(self, vfile_name=None, ofile_name=None, cycles=50000):
        self.vfile_name = vfile_name
        self.vfile = None
        self.ofile_name = ofile_name
        self.cycles = cycles
        if(ofile_name == None):
            self.ofile = sys.stdout
        self.vcont = ""
        self.mod_name = ""
        self.pin_list = []
        self.clock_name = 'clk'
        self.reset_name = 'rst_n'
        self.reset_active_low = True
        self.input_pins = []
        self.output_pins = []
        self.inout_pins = []
        self.internal_signals = []
        
        # FSM detection
        self.has_fsm = False
        self.state_params = []
        self.state_register = None
        self.state_width = 0
        
        if vfile_name == None:
            sys.stderr.write("ERROR: You aren't specfic a input file name.\n")
            sys.exit(1)
        else:
            self.open()
        self.parser()
        self.categorize_pins()
        self.detect_fsm()
        self.open_outputfile()

    def open(self, vfile_name=None):
        if vfile_name != None:
            self.vfile_name = vfile_name
            
        try:
            self.vfile = open(self.vfile_name, 'r')
            self.vcont = self.vfile.read() 
        except Exception as e:
            print("ERROR:Open and read file error.\n ERROR:    %s" % e)
            sys.exit(1)
            
    def open_outputfile(self, ofile_name=None):
        try:
            output_dir = "/nethome/sravikanth3/research/new/tb" #testbench output path
            if not os.path.exists(output_dir):
                os.makedirs(output_dir)
            
            if(ofile_name == None):
                if(self.ofile_name == None):
                    ofname = os.path.join(output_dir, "tb_top.v")
                    self.ofile = open(ofname, 'w')
                    print("Output file: '%s'" % ofname)
                else:
                    ofname = os.path.join(output_dir, os.path.basename(self.ofile_name))
                    self.ofile = open(ofname, 'w')
                    print("Output file: '%s'." % ofname)
            else:
                ofname = os.path.join(output_dir, os.path.basename(ofile_name))
                self.ofile = open(ofname, 'w')
                print("Output file: '%s'." % ofname)
        except Exception as e:
            print("ERROR:open and write output file error. \n ERROR:    %s" % e)
            sys.exit(1)

    def get_bit_width(self, bit_range):
        """
        Convert bit range like '[3:0]' to actual width '4'
        Returns the width as a string
        """
        if not bit_range:
            return "1"
        
        # Extract numbers from [MSB:LSB]
        match = re.match(r'\[(\d+):(\d+)\]', bit_range)
        if match:
            msb = int(match.group(1))
            lsb = int(match.group(2))
            width = msb - lsb + 1
            return str(width)
        else:
            # If format doesn't match, return a safe default
            return "1"
                
    def clean_other(self, cont):
        ## clean '// ...'
        cont = re.sub(r"//[^\n^\r]*", '\n', cont)
        ## clean '/* ... */'
        cont = re.sub(r"/\*.*?\*/", '', cont, flags=re.DOTALL)
        ## clean tables
        cont = re.sub(r'    +', ' ', cont)
        return cont
        
    def parser(self):
        print("Parsing module...")
        mod_pattern = r"module[\s]+(\S*)[\s]*\([^\)]*\)[\s\S]*"  
        
        module_result = re.findall(mod_pattern, self.clean_other(self.vcont))
        if module_result:
            self.mod_name = module_result[0]
            print("  Module name: %s" % self.mod_name)
        else:
            sys.stderr.write("ERROR: Cannot find module definition.\n")
            sys.exit(1)
        
        self.parser_inoutput()
        self.find_clk_rst()
        self.extract_internal_signals()
             
    def parser_inoutput(self):
        pin_list = self.clean_other(self.vcont) 
        
        comp_pin_list_pre = []
        for i in re.findall(r'(input|output|inout)[\s]+([^;,\)]+)[\s]*[;,]', pin_list):
            comp_pin_list_pre.append((i[0], re.sub(r"^reg[\s]*", "", i[1])))
            
        comp_pin_list = []
        type_name = ['reg', 'wire', 'wire', "ERROR"]
        for i in comp_pin_list_pre:
            x = re.split(r']', i[1])
            type = 0
            if i[0] == 'input':
                type = 0
            elif i[0] == 'output':
                type = 1
            elif i[0] == 'inout':
                type = 2
            else:
                type = 3

            if len(x) == 2:
                x[1] = re.sub(r'[\s]*', '', x[1])
                comp_pin_list.append((i[0], x[1], x[0] + ']', type_name[type]))
            else:
                comp_pin_list.append((i[0], x[0], '', type_name[type]))
        
        self.pin_list = comp_pin_list
        print("  Found %d ports" % len(self.pin_list))

    def categorize_pins(self):
        """Categorize pins into inputs, outputs, and inouts"""
        for pin in self.pin_list:
            if pin[0] == 'input':
                self.input_pins.append(pin)
            elif pin[0] == 'output':
                self.output_pins.append(pin)
            elif pin[0] == 'inout':
                self.inout_pins.append(pin)

    def extract_internal_signals(self):
        """Extract internal reg and wire declarations"""
        cleaned = self.clean_other(self.vcont)
        # Find internal regs and wires
        internal_regs = re.findall(r'[\s]+(reg)[\s]+([^;]+);', cleaned)
        internal_wires = re.findall(r'[\s]+(wire)[\s]+([^;]+);', cleaned)
        
        for sig in internal_regs + internal_wires:
            sig_name = sig[1].strip()
            # Remove bit width if present
            sig_parts = re.split(r']', sig_name)
            if len(sig_parts) == 2:
                self.internal_signals.append(sig_parts[1].strip())
            else:
                self.internal_signals.append(sig_name)

    def detect_fsm(self):
        """Detect if the design contains a state machine"""
        print("\nDetecting FSM...")
        cleaned = self.clean_other(self.vcont)
        
        # 1. Look for state parameters
        param_pattern = r'(parameter|localparam)[\s]+([A-Z_][A-Z0-9_]*)[\s]*=[\s]*([0-9]+)'
        params = re.findall(param_pattern, cleaned, re.IGNORECASE)
        
        # Common state keywords to look for
        state_keywords = ['STATE', 'IDLE', 'FETCH', 'EXEC', 'STARTUP', 'STANDBY', 
                         'SEND', 'RECEIVE', 'WAIT', 'INIT', 'DONE', 'TX', 'RX',
                         'GET', 'START', 'END', 'TEST']
        
        potential_states = []
        for param in params:
            param_name = param[1]
            param_value = param[2]
            # Check if parameter name contains state keywords
            if any(keyword in param_name.upper() for keyword in state_keywords):
                potential_states.append((param_name, param_value))
        
        # 2. Look for state registers
        state_reg_names = ['state', 'stato', 'current_state', 'curr_state', 'cs', 
                          'present_state', 'ps', 'fsm_state', 'sm_state']
        
        state_reg_pattern = r'reg[\s]+(\[[^\]]+\])?[\s]*(' + '|'.join(state_reg_names) + r')'
        state_regs = re.findall(state_reg_pattern, cleaned, re.IGNORECASE)
        
        # 3. Determine if FSM exists
        if len(potential_states) >= 2 and len(state_regs) > 0:
            self.has_fsm = True
            self.state_params = potential_states
            if state_regs:
                self.state_register = state_regs[0][1] if state_regs[0][1] else state_regs[0][0]
                if state_regs[0][0]:
                    self.state_width = state_regs[0][0]
            
            print("  [+] FSM detected!")
            print("    States found: %d" % len(self.state_params))
            for state in self.state_params[:5]:
                print("      - %s = %s" % (state[0], state[1]))
            if len(self.state_params) > 5:
                print("      ... and %d more" % (len(self.state_params) - 5))
            print("    State register: %s" % self.state_register)
        else:
            print("  [-] No FSM detected")
            print("    (Found %d potential states, %d state registers)" % 
                  (len(potential_states), len(state_regs)))

    def find_clk_rst(self):
        """Find clock and reset signals"""
        for pin in self.pin_list:
            if re.match(r'[\S]*(clk|clock)[\S]*', pin[1], re.IGNORECASE):
                self.clock_name = pin[1]
                print("  Clock signal: '%s'" % pin[1])
                break

        for pin in self.pin_list:
            if re.match(r'[\S]*(rst|reset)[\S]*', pin[1], re.IGNORECASE):
                self.reset_name = pin[1]
                if re.search(r'_n$|_neg$|n$', pin[1], re.IGNORECASE):
                    self.reset_active_low = True
                else:
                    self.reset_active_low = False
                print("  Reset signal: '%s' (active %s)" % 
                      (pin[1], "low" if self.reset_active_low else "high"))
                break

    def print_module_head(self):
        """Print testbench module header"""
        self.printo("`timescale 1ns / 1ps\n\n")
        self.printo("module tb_top;\n\n")

    def print_state_parameters(self):
        """Print state parameters if FSM detected"""
        if self.has_fsm and self.state_params:
            self.printo("// State parameters (must match %s.v)\n" % self.mod_name)
            for state in self.state_params:
                self.printo("parameter %s = %s;\n" % (state[0], state[1]))
            self.printo("\n")

    def print_parameters(self):
        """Print simulation parameters"""
        self.printo("// Simulation parameters\n")
        self.printo("parameter PERIOD = 10;  // Clock period in ns\n")
        self.printo("parameter SIM_CYCLES = %d;  // Number of simulation cycles\n\n" % self.cycles)

    def print_signals(self):
        """Print signal declarations"""
        self.printo("// Clock and reset\n")
        self.printo("reg clk;\n")
        self.printo("reg rst_n;\n\n")
        
        # Input signals (excluding clock and reset)
        if self.input_pins:
            self.printo("// Input signals\n")
            for pin in self.input_pins:
                if pin[1] not in [self.clock_name, self.reset_name]:
                    self.printo("%s %s %s;\n" % (pin[3], pin[2], pin[1]))
            self.printo("\n")
        
        # Output signals
        if self.output_pins:
            self.printo("// Output signals\n")
            for pin in self.output_pins:
                self.printo("%s %s %s;\n" % (pin[3], pin[2], pin[1]))
            self.printo("\n")
        
        # Inout signals
        if self.inout_pins:
            self.printo("// Inout signals\n")
            for pin in self.inout_pins:
                self.printo("%s %s %s;\n" % (pin[3], pin[2], pin[1]))
            self.printo("\n")
        
        # Counters and file handles
        self.printo("// Loop counter\n")
        self.printo("integer i;\n\n")
        self.printo("// File for logging\n")
        self.printo("integer file;\n\n")

    def print_dut(self):
        """Print DUT instantiation"""
        self.printo("// Instantiate the DUT (Device Under Test)\n")
        self.printo("%s dut (\n" % self.mod_name)
        
        # Create port connections
        port_connections = []
        for pin in self.pin_list:
            pin_name = pin[1]
            if pin_name == self.clock_name and self.clock_name != 'clk':
                port_connections.append(("." + pin_name, "(clk)"))
            elif pin_name == self.reset_name and self.reset_name != 'rst_n':
                if self.reset_active_low:
                    port_connections.append(("." + pin_name, "(rst_n)"))
                else:
                    port_connections.append(("." + pin_name, "(~rst_n)"))
            else:
                port_connections.append(("." + pin_name, "(" + pin_name + ")"))
        
        # Print connections with alignment
        max_len = max([len(p[0]) for p in port_connections])
        for idx, conn in enumerate(port_connections):
            comma = "," if idx < len(port_connections) - 1 else ""
            self.printo("    %-*s %s%s\n" % (max_len, conn[0], conn[1], comma))
        
        self.printo(");\n\n")

    def print_clock_gen(self):
        """Print clock generation"""
        self.printo("// Clock generation - 10ns period (100MHz)\n")
        self.printo("initial begin\n")
        self.printo("    clk = 0;\n")
        self.printo("    forever #(PERIOD/2) clk = ~clk;\n")
        self.printo("end\n\n")

    def print_test_stimulus(self):
        """Print main test stimulus"""
        self.printo("// Test stimulus\n")
        self.printo("initial begin\n")
        self.printo("    // Initialize signals\n")
        self.printo("    rst_n = 0;\n")
        
        # Initialize all input signals
        for pin in self.input_pins:
            if pin[1] not in [self.clock_name, self.reset_name]:
                if pin[2]:  # Has bit width
                    bit_width = self.get_bit_width(pin[2])  # Get actual width
                    self.printo("    %s = %s'h0;\n" % (pin[1], bit_width))
                else:
                    self.printo("    %s = 1'b0;\n" % pin[1])
        
        self.printo("    \n")
        self.printo("    // Open file for logging\n")
        self.printo("    file = $fopen(\"simulation_log.txt\", \"w\");\n")
        
        # Create header for log file
        header_items = ["Cycle"]
        for pin in self.input_pins:
            if pin[1] not in [self.clock_name, self.reset_name]:
                header_items.append(pin[1])
        for pin in self.output_pins:
            header_items.append(pin[1])
        if self.has_fsm and self.state_register:
            header_items.append(self.state_register)
        
        self.printo("    $fwrite(file, \"%s\\n\");\n" % "\\t".join(header_items))
        self.printo("    \n")
        self.printo("    // Apply reset\n")
        self.printo("    #20;\n")
        self.printo("    rst_n = 1;\n")
        self.printo("    #10;\n")
        self.printo("    \n")
        self.printo("    $display(\"\\n=== Starting %d cycle simulation with random input ===\\n\");\n" % self.cycles)
        self.printo("    \n")
        self.printo("    // Run for specified cycles with random inputs\n")
        self.printo("    for (i=0; i<SIM_CYCLES; i=i+1) begin\n")
        self.printo("        @(posedge clk);\n")
        self.printo("        // Random input generation\n")
        
        # Generate random inputs
        for pin in self.input_pins:
            if pin[1] not in [self.clock_name, self.reset_name]:
                self.printo("        %s <= $random;\n" % pin[1])
        
        self.printo("        \n")
        self.printo("        // Log signals to file\n")
        self.printo("        if (file) begin\n")
        
        # Create format string for fwrite
        format_items = ["%0d"]
        value_items = ["i"]
        
        for pin in self.input_pins:
            if pin[1] not in [self.clock_name, self.reset_name]:
                format_items.append("%h")
                value_items.append(pin[1])
        for pin in self.output_pins:
            if pin[2]:
                format_items.append("%h")
            else:
                format_items.append("%b")
            value_items.append(pin[1])
        if self.has_fsm and self.state_register:
            format_items.append("%0d")
            value_items.append("dut." + self.state_register)
        
        format_str = "\\t".join(format_items) + "\\n"
        self.printo("            $fwrite(file, \"%s\", \n" % format_str)
        self.printo("                    %s);\n" % ", ".join(value_items))
        self.printo("        end\n")
        self.printo("        \n")
        
        # Add state-specific monitoring if FSM detected
        if self.has_fsm and self.state_register:
            self.printo("        // Display state transitions\n")
            for idx, state in enumerate(self.state_params[:10]):
                self.printo("        if (dut.%s == %s) begin\n" % (self.state_register, state[0]))
                self.printo("            if (i % 100 == 0)  // Display every 100 cycles in this state\n")
                self.printo("                $display(\"Time=%%0t: Cycle %%0d - State: %s\", $time, i);\n" % state[0])
                self.printo("        end\n")
                if idx < len(self.state_params) - 1 and idx < 9:
                    self.printo("        ")
            self.printo("        \n")
        
        self.printo("        // Display progress every 1000 cycles\n")
        self.printo("        if (i % 1000 == 0) begin\n")
        if self.has_fsm and self.state_register:
            self.printo("            $display(\"Time=%%0t: Cycle %%0d | State=%%0d\", $time, i, dut.%s);\n" % self.state_register)
        else:
            self.printo("            $display(\"Time=%%0t: Cycle %%0d\", $time, i);\n")
        self.printo("        end\n")
        self.printo("    end\n")
        self.printo("    \n")
        self.printo("    // Close file and finish simulation\n")
        self.printo("    if (file) $fclose(file);\n")
        self.printo("    \n")
        self.printo("    $display(\"\\n=== Simulation Complete ===\");\n")
        self.printo("    $display(\"Total cycles run: %%0d\", i);\n")
        self.printo("    $display(\"Check 'simulation_log.txt' for detailed signal log\");\n")
        self.printo("    $finish;\n")
        self.printo("end\n\n")

    def print_state_decoder(self):
        """Print state name decoder function if FSM detected"""
        if not self.has_fsm or not self.state_params:
            return
            
        self.printo("// State name decoder for display\n")
        self.printo("function [127:0] state_name;\n")
        self.printo("    input [31:0] state;\n")
        self.printo("    begin\n")
        self.printo("        case(state)\n")
        for state in self.state_params:
            self.printo("            %s: state_name = \"%s\";\n" % (state[0], state[0]))
        self.printo("            default: state_name = \"UNKNOWN\";\n")
        self.printo("        endcase\n")
        self.printo("    end\n")
        self.printo("endfunction\n\n")

    def print_monitor(self):
        """Print monitor for debugging"""
        self.printo("// Monitor for debugging\n")
        self.printo("initial begin\n")
        self.printo("    $display(\"=== %s Testbench ===\");\n" % self.mod_name)
        
        # Create monitor header
        monitor_signals = ["Time", "rst_n"]
        if self.has_fsm and self.state_register:
            monitor_signals.append(self.state_register)
        for pin in self.output_pins[:4]:
            monitor_signals.append(pin[1])
        
        self.printo("    $display(\"%s\");\n" % "\\t".join(monitor_signals))
        self.printo("    $display(\"%s\");\n" % "\\t".join(["-" * len(s) for s in monitor_signals]))
        
        # Create monitor format
        format_items = ["%0t"]
        value_items = ["$time", "rst_n"]
        
        if self.has_fsm and self.state_register:
            format_items.append("%0d")
            value_items.append("dut." + self.state_register)
        
        for pin in self.output_pins[:4]:
            if pin[2]:
                format_items.append("%h")
            else:
                format_items.append("%b")
            value_items.append(pin[1])
        
        format_str = "\\t".join(format_items)
        self.printo("    $monitor(\"%s\", \n" % format_str)
        self.printo("             %s);\n" % ", ".join(value_items))
        self.printo("end\n\n")

    def print_vcd_dump(self):
        """Print VCD dump for waveform viewing"""
        self.printo("// Generate VCD file for waveform viewing\n")
        self.printo("initial begin\n")
        self.printo("    $dumpfile(\"tb_top.vcd\");\n")
        self.printo("    $dumpvars(0, tb_top);\n")
        self.printo("    // Dump all DUT signals\n")
        self.printo("    $dumpvars(0, dut);\n")
        if self.has_fsm and self.state_register:
            self.printo("    // Explicitly dump state register\n")
            self.printo("    $dumpvars(0, dut.%s);\n" % self.state_register)
        self.printo("end\n\n")

    def print_signal_tracking(self):
        """Print signal tracking blocks"""
        if len(self.output_pins) > 0:
            self.printo("// Track output signal changes\n")
            for pin in self.output_pins[:4]:
                if pin[2]:
                    self.printo("reg %s prev_%s;\n" % (pin[2], pin[1]))
                else:
                    self.printo("reg prev_%s;\n" % pin[1])
            self.printo("\n")
            
            self.printo("initial begin\n")
            self.printo("    @(posedge rst_n);\n")
            for pin in self.output_pins[:4]:
                self.printo("    prev_%s = 0;\n" % pin[1])
            self.printo("    \n")
            self.printo("    repeat(SIM_CYCLES) begin\n")
            self.printo("        @(posedge clk);\n")
            self.printo("        \n")
            for pin in self.output_pins[:4]:
                self.printo("        if (dut.%s != prev_%s) begin\n" % (pin[1], pin[1]))
                self.printo("            $display(\"Time=%%0t: %s changed: %%h -> %%h\", $time, prev_%s, dut.%s);\n" 
                           % (pin[1], pin[1], pin[1]))
                self.printo("            prev_%s = dut.%s;\n" % (pin[1], pin[1]))
                self.printo("        end\n")
            self.printo("    end\n")
            self.printo("end\n\n")

    def print_state_tracking(self):
        """Print state transition tracking if FSM detected"""
        if not self.has_fsm or not self.state_register:
            return
            
        self.printo("// Track state transitions\n")
        if self.state_width:
            self.printo("reg %s prev_state;\n" % self.state_width)
        else:
            self.printo("reg [31:0] prev_state;\n")
        self.printo("integer state_change_count;\n\n")
        
        self.printo("initial begin\n")
        self.printo("    @(posedge rst_n);\n")
        self.printo("    prev_state = dut.%s;\n" % self.state_register)
        self.printo("    state_change_count = 0;\n")
        self.printo("    \n")
        self.printo("    repeat(SIM_CYCLES) begin\n")
        self.printo("        @(posedge clk);\n")
        self.printo("        \n")
        self.printo("        if (dut.%s != prev_state) begin\n" % self.state_register)
        self.printo("            state_change_count = state_change_count + 1;\n")
        self.printo("            $display(\"Time=%%0t: State transition #%%0d: %%s (%%0d) -> %%s (%%0d)\", \n")
        self.printo("                     $time, state_change_count, \n")
        self.printo("                     state_name(prev_state), prev_state,\n")
        self.printo("                     state_name(dut.%s), dut.%s);\n" % (self.state_register, self.state_register))
        self.printo("            prev_state = dut.%s;\n" % self.state_register)
        self.printo("        end\n")
        self.printo("    end\n")
        self.printo("    \n")
        self.printo("    #100;\n")
        self.printo("    $display(\"\\n=== State Transition Statistics ===\");\n")
        self.printo("    $display(\"Total state transitions: %%0d\", state_change_count);\n")
        self.printo("    $display(\"Final state: %%s (%%0d)\", state_name(dut.%s), dut.%s);\n" 
                   % (self.state_register, self.state_register))
        self.printo("end\n\n")

    def print_module_end(self):
        """Print module end"""
        self.printo("endmodule\n")

    def printo(self, cont):
        """Output to file"""
        self.ofile.write(cont)

    def close(self):
        """Close files"""
        if self.vfile != None:
            self.vfile.close()
        if self.ofile != sys.stdout:
            self.ofile.close()
        print("\n[+] Testbench generation complete!")
        if self.has_fsm:
            print("  Generated FSM-aware testbench with state monitoring")
        else:
            print("  Generated standard testbench")

if __name__ == "__main__":
    print('''
===============================================================================
          tbgen - Auto generate comprehensive testbenches                  
                                                                           
  Original Author: Xiongfei(Alex) Guo <xfguo@credosemi.com>               
  Enhanced: FSM detection & state-aware testing                           
  License: Beerware                                                        
===============================================================================
''')
    
    ofile_name = None
    cycles = 50000
    
    if len(sys.argv) == 1:
        sys.stderr.write("ERROR: You aren't specfic a input file name.\n")
        print("Usage: tbgen input_verilog_file_name [output_testbench_file_name] [cycles]")
        print("  input_verilog_file_name: Input Verilog RTL file")
        print("  output_testbench_file_name: Output testbench file (default: tb_top.v)")
        print("  cycles: Number of simulation cycles (default: 50000)")
        print("\nFeatures:")
        print("  * Automatic FSM detection")
        print("  * State-aware monitoring")
        print("  * Comprehensive signal logging")
        print("  * VCD waveform generation")
        print("  * Random input stimulus")
        sys.exit(1)
    elif len(sys.argv) >= 3:
        ofile_name = sys.argv[2]
    if len(sys.argv) >= 4:
        try:
            cycles = int(sys.argv[3])
            print("Simulation cycles set to: %d" % cycles)
        except:
            print("Invalid cycle count, using default: 50000")
            cycles = 50000
        
    tbg = TestbenchGenerator(sys.argv[1], ofile_name, cycles)

    # Generate testbench
    tbg.print_module_head()
    if tbg.has_fsm:
        tbg.print_state_parameters()
    tbg.print_parameters()
    tbg.print_signals()
    tbg.print_dut()
    tbg.print_clock_gen()
    tbg.print_test_stimulus()
    if tbg.has_fsm:
        tbg.print_state_decoder()
    tbg.print_monitor()
    tbg.print_vcd_dump()
    tbg.print_signal_tracking()
    if tbg.has_fsm:
        tbg.print_state_tracking()
    tbg.print_module_end()
    tbg.close()
