#PBS -N ISA
# To request 36 hours of wall clock time
#PBS -l walltime=150:00:00
 
# To request a single node with 12 core
#PBS -l nodes=12:ppn=1
#The environment variable $PBS_O_WORKDIR specify the directory from which you submitted the job
set -x

cd /home/xiej/Juan/Experiment/ISA/Ecoli_RNAseq
. ${MODULESHOME}/init/sh
module load bio/R/3.4.1

Rscript ISA_ecoli.R





