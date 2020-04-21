# 1. Overview
This software will take a bitstream and patch it with new memory contents to create a new bitstream.

More correctly, it will patch a .fasm file representing a bitstream to create a new .fasm file. 
It relies on prjxray to actually convert between .bit and .fasm representations.

It works on designs that have come from Vivado and relies on a Tcl script to extract the needed 
metadata to understand which memory primitives in the bitstream correspond to which "chunks" 
of the original Verilog-specified memory.

Typically, the memory contents in Verilog are included using $readmemb() 
$readmemh() call in Verilog to read the memory initialization contents from a text file. 
This flow expects that and will allow you to supply a different memory contents file. 
It will then patch that file contents into the BRAM primitives in the bitstream.

The tools relies on having a .mdd file to describe the contents of the memories in the 
compiled designs.  In a Vivado flow, the .mdd file can be created using the 
_testing/gen.tcl_ script.  For other flows, a mechanism will be needed to generate such files
from the tools in that other flow.

Since designs will typically have multiple BRAM-based memories, the tools expect the name of the 
memory to be patched.  The tool supports either hierarchical or flattened designs.

# 2. Installation

## 2.1 Linux, Python, and Vivado Versions
* At the current time, symbiflow/prjxray requires Vivado version 2017.2.  
* This Vivado version supports Ubuntu 16.04. Recent attempts to install it on an Ubuntu 18.04 system caused some problems.
* Ubuntu 16.04 has python 3.5 natively installed.  While we have successfully upgraded that to python 3.6 or later, that has caused issues with prjxray installation.

Thus, the recommended system consists of:
* Ubuntu 16.04 with its native python 3.5
* Vivado 2017.2

## 2.2 Installing prjxray and prjxray-bram-patch
After cloning both projects, follow the instructions on the prjxray github site for fully installing and configuring prjxray.  

There is nothing needed to be done to prjxray-bram-patch project once it is cloned.

## 2.3 Startup Scripts
In .bashrc, put in the following lines:

    # Adjust paths below as necessary
    export XRAY_VIVADO_SETTINGS=${HOME}/Xilinx_2017.2/Vivado/2017.2/settings64.sh
    export MEM_PATCH_DIR=${HOME}/prjxray-bram-patch
    source ${HOME}/prjxray/settings/artix7.sh
    
When the above executes, if you don't have Vivado installed, you will get errors.  But, that is OK - you can still run the patch tools without Vivado (you only need Vivado to originally create the design).

## 2.4 Sample Designs and the Test Database
There are a few sample designs in the "samples" directory.

Additionally, a large collection of sample designs have been created and typically live in $MEM_PATCH_DIR/testing/tests/master.  
They are not needed for just doing patching but are used for testing of the patcher.  And, they are large and so are not included here but can be made available if desired.

# 3. Doing a Simple Patch

Imagine that a design has been synthesized and implemented in Vivado.  The steps to patch its memory include the following:

#### Step 1: Generate .mdd File
While still in Vivado, source the Tcl script "testing/mdd_make.tcl".  Then, call: 

    mddMake("original.mdd")

from within it to generate a .mdd file.  This file will contain the metadata needed to describe how the memory in the original design was broken up across a collection of BRAM cells.  

#### Step 2: Create New Memory Initialization File 
Based on the format of the original **$readmemb()** or **$readmemh()** file you used in your original Verilog, create a new memory initialization file.

At this point you should have the following files available (your filenames will be different):
    
    newMemContents.init
    original.bit
    original.mdd

#### Step 3: Generate a .fasm File From .bit File
Next, you convert your .bit file to a .fasm file using the following: 

    $XRAY_BIT2FASM original.bit > orig.fasm

#### Step 4: Patch the .fasm File
To replace the old memory contents in the bitstream with new contents, run the patch program using the following:

    python patch_mem orig.fasm newMemContents.init original.mdd patched.fasm

#### Step 5: Generate New .fasm File to New .bit File
Finally, you convert the new .fasm file to a .bit file using:

    $XRAY_FASM2FRAMES patched.fasm patched.frm
    $XRAY_TOOLS_DIR/xc7frames2bit \
        --part_name $XRAY_PART \
        --part_file $XRAY_PART_YAML \
        --frm_file patched.frm \
        --output_file patched.bit

# 4. What Are MDD Files?
When large memories are created by the Vivado tools, they are chopped up and mapped onto a collection of BRAM primitives on the FPGA.  The patching tool requires information on how that mapping was done so that memory initialization file contents can be appropriately divided up for patching to the bitstream.  

The MDD file contains the information needed to do that mapping.  It is generated by the Tcl script: **testing/mdd_make.tcl**.  If you are not using Vivado, you will need to create such an MDD file some other way.

The current MDD file contains information on mapped BRAM primitives. It contains a number of BRAM properties that are not currently used and thus could possibly be reduced in the future.

# 5. Test infrastructure
In order to verify that the patcher works for all size/shapes/configurations of memories, a test infrastructure is included in the _"testing"_ directory.  The main two steps for this are (1) generation of tests and (2) the actual running of the tests.

## 5.1 Generation
This entails generating Verilog code which gets synthesized and implemented to a bitstream for each size of memory desired. 

### File: generate_tests.py
At the top level of the project directory, this is the main driver.  It simply generates needed designs for all sizes by calling the program **testing/generate_tests_script.sh**.  The size of memories to generate designs for are given in a series of lists at the top of the code.  Or, you can specify a memory size on the command line and generate just that.

### File: testing/generate_tests_script.sh
This script creates a single memory test case of ${DEPTHNAME} words by ${WIDTH} bits wide.   The test case is placed into the location: "tests/master/${DEPTHNAME}b$WIDTH".

1. It first creates the needed directory (referred to as _DIR_ in the discussion below).
1. It then creates two randomly-filled memory initialization files called DIR/init/init.mem and DIR/init/alt.mem
1. Next, it creates a customized SystemVerilog design in DIR/vivado which implements the memory and a top level design and which reads the memory's contents from DIR/init/init.mem.
1. Vivado is then called and the design is compiled through to bitstream.
1. Finally the bitstream is converted to a fasm file called: DIR/real.fasm

## 5.2 Testing
The program **run_tests.py** is used to actually do the testing.  The basic flow is as follows:
1. It keeps lists of tests that have (a) passed, (b) failed, or were (c) incomplete.
1. There is lots of flexibility provided to control which designs are tested:
  * There are lists to specify sizes and shapes of memories to test.
  * If the SKIP_PASSED flag is set to true, only those that have not yet passed will be tested).  
  * There is also a ONE_TEST_ONLY variable which makes it easy to do a single test.  It overrides both the SKIP_PASSED flag setting as well as the lists of sizes to test. In short, if it is set then that one test will simply be run.
  * Finally, you can specify a single test to be run on the command line.

The bitstream for a given test is originally created in the generation step using the DIR/init/init.mem file contents.  A FASM file for that bitstream is then created (DIR/real.fasm).  

Then, in the testing step, the file DIR/alt.fasm is patched with the contents of the DIR/init/init.mem file.  
and the resulting DIR/patched.fasm file is then compared to the DIR/real.fasm file.  If their contents match, this indicates that the patcher successfully was able to patch an arbitrary FASM file with the contents of DIR/init/init.mem.

