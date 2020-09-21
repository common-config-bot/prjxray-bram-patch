# The runTest.sh script will run a single test against the design generated here.

# This script, however, will just patch 128b1/real.fasm with some new contents 
# (in this case it will patch 128b1/real.fasm with the contents of 128b1/init/alt.mem), 
# calling the result 128b1/new.fasm (and if you diff them it should match 128b1/alt.fasm due to the patching).

python $MEM_PATCH_DIR/patch_mem.py 128b1/real.fasm 128b1/init/alt.mem 128b1/mapping.mdd 128b1/new.fasm mem/ram
