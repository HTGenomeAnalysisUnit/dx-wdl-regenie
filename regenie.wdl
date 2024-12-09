version 1.0

struct BedDataset {
	String prefix
	File bed
	File bim
	File fam
}

struct BgenDataset {
	String prefix
	File bgen
	File sample
}

workflow regenie_gwas {
	input {
		Int step1_cpus = 16
		Int step2_cpus = 16
		Int step1_mem = 32
		Int step2_mem = 32
		Boolean ref_first = false
		String output_tag = "output"
		BedDataset step1dataset
		File? step1_qc_snplist
		File? step1_qc_keep
		File pheno_file
		File covar_file
		String phenos 
		Boolean binary_trait = false
		String covars
		String? catCovars
		Int maxCatLevels = 10
		Int step2_minMAC = 100
		Array[BgenDataset] step2Datasets
	}

	call step1 {
		input: 
			step1dataset=step1dataset,
			pheno_file=pheno_file,
			covar_file=covar_file,
			step1_qc_snplist=step1_qc_snplist,
			step1_qc_keep=step1_qc_keep,
			phenos=phenos, covars=covars,
			catCovars=catCovars,
			output_tag=output_tag,
			step1_cpus=step1_cpus,
			step1_mem=step1_mem,
			binary_trait=binary_trait,
			maxCatLevels=maxCatLevels
	}

    scatter (step2dataset in step2Datasets) {
    	call step2 {
			input: 
				step2dataset=step2dataset,
				step1results=step1.step1_out,
				pheno_file=pheno_file,
				covar_file=covar_file,
				phenos=phenos,
				covars=covars,
				catCovars=catCovars,
				output_tag=output_tag,
				step2_cpus=step2_cpus,
				step2_mem=step2_mem,
				step2_minMAC=step2_minMAC,
				binary_trait=binary_trait,
				maxCatLevels=maxCatLevels,
				ref_first=ref_first
		}
    }

	call merge_by_pheno {
		input: 
			step2_results=flatten(step2.step2_out), 
			output_tag=output_tag,
			phenos=phenos
	}

	output {
		Array[File] step2_results = merge_by_pheno.pheno_results
		Array[File] step2_logs = step2.step2_log
		Array[File] step1_results = step1.step1_out
		File step1_log = step1.step1_log
	}

    meta {
		author: "Edoardo Giacopuzzi"
		email: "edoardo.giacopuzzi@fht.org"
		description: "a simple workflow to run regenie analysis on the RAP"
    }

}

task step1 {
	input {
		BedDataset step1dataset
		File pheno_file
		File covar_file
		File? step1_qc_snplist
		File? step1_qc_keep
		String phenos
		String covars
		String? catCovars
		String output_tag
		Int step1_cpus
		Int step1_mem
		Boolean binary_trait
		Int maxCatLevels
	}

	command <<<
		bed_file="~{step1dataset.bed}"
		prefix=$(echo "$bed_file" | sed -e "s/\.bed$//")
		echo "== Prefix: $prefix =="

		echo "== Running regenie step 1 =="
		regenie --step 1 \
			--bed ${prefix} \
			--phenoFile ~{pheno_file} \
			--covarFile ~{covar_file} \
			~{if defined(step1_qc_snplist) then "--extract ~{step1_qc_snplist}" else ""} \
			~{if defined(step1_qc_keep) then "--keep ~{step1_qc_keep}" else ""} \
			--phenoColList ~{phenos} \
			--covarColList ~{covars} \
			~{if defined(catCovars) then "--catCovarList ${catCovars}" else ""} \
			--maxCatLevels ~{maxCatLevels} \
			--apply-rint \
			--out ~{output_tag}-regenie_step1 \
			~{if binary_trait then "--bt" else ""} \
			--bsize 1000 --lowmem --threads ~{step1_cpus} --gz 
		
		sed -i "s|$PWD/||g" ~{output_tag}-regenie_step1_pred.list
	>>>

	output {
		Array[File] step1_out = glob("~{output_tag}-regenie_step1_*")
		File step1_log = "~{output_tag}-regenie_step1.log"
	}

	runtime {
    	docker: "quay.io/biocontainers/regenie:3.1.1--h2b233e7_0"
		dx_instance_type: "mem1_ssd1_v2_x~{step1_cpus}"
    	cpu: step1_cpus
    	memory: step1_mem + "GB"
    }

	meta {
		title: "regenie step 1"
		summary: "Run regenie step 1"
		description: "Run regenie step 1 on a bed/bim/fam dataset. This expects input file to be properly QCed."
	}
}

task step2 {
	input {
		BgenDataset step2dataset
		Array[File] step1results
		File pheno_file
		File covar_file
		String phenos
		String covars
		String? catCovars
		String output_tag
		Int step2_cpus
		Int step2_mem
		Int step2_minMAC
		Boolean binary_trait
		Int maxCatLevels
		Boolean ref_first
	}

	command <<<		
		for file in ~{sep=" " step1results}; do
			echo "Moving $file to current directory"
			mv $file .
		done
		
		echo "== Files in this folder =="
		ls -lh

		echo "== Running regenie step 2 =="
		regenie --step 2 \
			--bgen ~{step2dataset.bgen} \
			--sample ~{step2dataset.sample} \
			--pred ~{output_tag}-regenie_step1_pred.list \
			--phenoFile ~{pheno_file} \
			--covarFile ~{covar_file} \
			--phenoColList ~{phenos} \
			--covarColList ~{covars} \
			~{if defined(catCovars) then "--catCovarList ~{catCovars}" else ""} \
			--maxCatLevels ~{maxCatLevels} \
			--out "~{output_tag}-~{step2dataset.prefix}" \
			--minMAC ~{step2_minMAC} \
			--apply-rint \
			~{if binary_trait then "--bt --firth --approx" else ""} \
			~{if ref_first then "--ref-first" else ""} \
			--bsize 200 --threads ~{step2_cpus} --gz 
	>>>

	output {
		Array[File] step2_out = glob("~{output_tag}*.regenie.gz")
		File step2_log = "~{output_tag}-~{step2dataset.prefix}.log"
	}

	runtime {
    	docker: "quay.io/biocontainers/regenie:3.1.1--h2b233e7_0"
		dx_instance_type: "mem1_ssd1_v2_x~{step2_cpus}"
    	cpu: step2_cpus
    	memory: step2_mem + "GB"
    }

	meta {
		title: "regenie step 2"
		summary: "Run regenie step 2 on a bgen dataset"
		description: "Run regenie step 2 on a bgen dataset."
	}
}

task merge_by_pheno {
	input {
		Array[File] step2_results
		String output_tag
		String phenos
	}

	command <<<
		set -euo pipefail
		
		inputfiles_directory=$(dirname ~{step2_results[0]})
		current_directory=$PWD

		echo "== Files in input folder =="
		echo "Current directory: $current_directory"
		echo "Input files directory: $inputfiles_directory"
		ls -lh $inputfiles_directory

		echo "== Running merge by pheno =="
		# Get a list of unique phenotypes from the filenames
		cd $inputfiles_directory
		phenos=$(echo "~{phenos}" | tr ',' ' ')

		# Loop through each phenotype and concatenate the files
		cd $current_directory
		for pheno in $phenos; do
			echo "Processing phenotype: $pheno"
			temp_file="temp_${pheno}.regenie"
			
			echo "Files for phenotype $pheno:"
			ls $inputfiles_directory/*$pheno.regenie.gz

			# Extract the header from the first file
			first_file=$(ls $inputfiles_directory/*$pheno.regenie.gz | head -n 1)
			zcat $first_file | head -n 1 > $temp_file
			echo "Header saved to $temp_file"

			# Concatenate the rest of the files, skipping the header
			for file in $inputfiles_directory/*.$pheno.regenie.gz; do
				zcat $file | tail -n +2 >> $temp_file
			done
			
			# Compress the concatenated file
			echo "Compressing the concatenated file"
			gzip -c $temp_file > "~{output_tag}-${pheno}.merged.regenie.gz"
			
			# Remove the temporary file
			rm $temp_file
		done
	>>>

	output {
		Array[File] pheno_results = glob("*.merged.regenie.gz")
	}

	runtime {
		docker: "quay.io/biocontainers/regenie:4.0--h90dfdf2_1"
		dx_instance_type: "mem1_ssd1_v2_x8"
	}

	meta {
		title: "Merge results by phenotype"
		summary: "Merge regenie step2 results by phenotype"
		description: "Take regenie step2 results and merge them by phenotype creating a single file gzipped file for each phenotype."
	}
}
