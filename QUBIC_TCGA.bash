#!/bin/bash
#SBATCH -N 1
#SBATCH -p PM --mem=128GB
#SBATCH --ntasks-per-node 28
#SBATCH -t 96:00:00
# echo commands to stdout
set -x

cd /pylon5/ci4s87p/xiej/NCdata/QUBIC/qubic1.0/

for f in $(seq 0.25 0.05 1.0);
	do
	for k in $(seq 150 10 200);
		do
		for c in $(seq 0.8 0.05 1.0);
			do
			time ./qubic -i /pylon5/ci4s87p/xiej/NCdata/QUBIC/tcga_transpose -f $f -k $k -c $c -o 100
			mv $"/pylon5/ci4s87p/xiej/NCdata/QUBIC/tcga_transpose.blocks" $"/pylon5/ci4s87p/xiej/NCdata/QUBIC/tcga_1.0_f_"$f"_k_"$k"_c_"$c"_o100.blocks"
		done
	done
done








