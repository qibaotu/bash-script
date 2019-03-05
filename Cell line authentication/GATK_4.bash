#!/bin/sh
#SBATCH -J gatk4          # Job name
#SBATCH -o myjob.%j.out   # define stdout filename; %j expands to jobid
#SBATCH -e myjob.%j.err   # define stderr filename; skip to combine stdout and stderr

#SBATCH --mail-user=Juan.Xie@sdstate.edu
#SBATCH --mail-type=ALL

#SBATCH -N 1              # Number of nodes, not cores (16 cores/node)
#SBATCH -p defq
#SBATCH -t 120:00:00       # max time
#SBATCH --ntasks-per-node 20  
#SBATCH --ntasks-per-node 20  # cores 
#SBATCH --array=1-500%50

nCores=10

cd /gpfs/scratch/juan.xie/BreastCancer

ID=$( cat /gpfs/scratch/juan.xie/IDs_single2 | sed -n ${SLURM_ARRAY_TASK_ID}p)

#ID="SRR1313065"
# file is SRR102717.fastq

if [ ! -d "${ID}" ]
then 
  mkdir ${ID}
fi


# prefetch $ID
cd ${ID}
mv /gpfs/scratch/juan.xie/DATA/sra/$ID.sra . 
fastq-dump --split-3 $ID.sra 

rm $ID.sra

genomeDir=/gpfs/scratch/juan.xie/resources/star_index_hg38
genomeFastaFiles=/gpfs/scratch/juan.xie/resources/hg38/Homo_sapiens_assembly38.fasta
sjdbGTFfile=/gpfs/scratch/juan.xie/resources/hg38/gencode.v29.annotation.gtf
dbsnp_vcf=/gpfs/scratch/juan.xie/resources/hg38/dbsnp_146.hg38.vcf
picard=/gpfs/home/juan.xie/miniconda3/pkgs/picard-2.18.27-0/share/picard-2.18.27-0/picard.jar
## picard Add read groups, sort, mark duplicates and create index

mkdir tmp
TMP_DIR=tmp


time STAR --runThreadN 12 \
	--genomeDir $genomeDir \
	--readFilesIn ${ID}.fastq \
	--outFileNamePrefix $ID \
	--twopassMode Basic

time gatk AddOrReplaceReadGroups \
        -I ${ID}Aligned.out.sam \
        -O ${ID}_rg_added_sorted.bam \
        -SO coordinate \
        -RGID $ID \
        -RGLB rna \
        -RGPL illumina \
        -RGPU hiseq \
        -RGSM SRR2481145 \
		-TMP_DIR $TMP_DIR

rm ${ID}Aligned.out.sam
#

time gatk MarkDuplicates \
        -I ${ID}_rg_added_sorted.bam \
        -O ${ID}_dedup.bam  \
        -CREATE_INDEX true \
        -VALIDATION_STRINGENCY= SILENT \
        -M ${ID}_dedup.metrics \
		-TMP_DIR $TMP_DIR

rm ${ID}_rg_added_sorted.bam

### variant calling
# Split’N’Trim and reassign mapping qualities
time gatk SplitNCigarReads \
        -R $genomeFastaFiles \
        -I ${ID}_dedup.bam \
		-O ${ID}_dedup_split.bam \
		--tmp-dir $TMP_DIR
		
rm ${ID}_dedup.bam

# optional: BQSR, base recalibration
time gatk BaseRecalibrator \
        -R $genomeFastaFiles \
        -I ${ID}_dedup_split.bam \
        --known-sites /gpfs/scratch/juan.xie/resources/hg38/Mills_and_1000G_gold_standard.indels.hg38.vcf.gz \
	    --known-sites /gpfs/scratch/juan.xie/resources/hg38/1000G_phase1.snps.high_confidence.hg38.vcf.gz \
	    --known-sites /gpfs/scratch/juan.xie/resources/hg38/dbsnp_146.hg38.vcf.gz \
	    -O ${ID}_recal_data.table \
		--tmp-dir $TMP_DIR

		
time gatk ApplyBQSR \
        -R $genomeFastaFiles \
        -I ${ID}_dedup_split.bam \
        --bqsr-recal-file ${ID}_recal_data.table \
        -O ${ID}_BQSR.bam \
		--tmp-dir $TMP_DIR

		
rm ${ID}_dedup_split.bam
		
## now can do variant calling
time gatk HaplotypeCaller \
        -R $genomeFastaFiles \
        -I ${ID}_BQSR.bam \
        --dont-use-soft-clipped-bases \
        -stand-call-conf 20.0 \
        -O ${ID}.vcf

## variant filtering
time gatk SelectVariants \
     -R $genomeFastaFiles \
     -V ${ID}.vcf \
     --select-type-to-include SNP \
     -O ${ID}.SNP.vcf


time gatk VariantFiltration \
		-R $genomeFastaFiles \
        -V ${ID}.SNP.vcf \
        -window 35 \
        -cluster 3 \
        --filter-expression "FS >30.0 || QD <2.0" \
        --filter-name "my_filter" \
        -O ${ID}_filtered.vcf


