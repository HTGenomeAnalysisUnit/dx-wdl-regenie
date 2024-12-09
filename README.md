# Regenie WDL workflow

This is a WDL workflow for running [Regenie](https://rgcgithub.github.io/regenie/) on a set of VCF files. The workflow is designed to run on the DNANexus/RAP platform, but can be run locally as well.

This workflow use **regenie v3.1.4** from `ghcr.io/rgcgithub/regenie/regenie:v3.1.4.gz` official docker image. More recent versions results in much longer runtimes at step2 for some unknown reason. We are investigating this with the regenie developers.

## Steps

1. Run regenie step1 on input bed/bim/fam files
2. Run regenie step2 in parallel for each BGEN input, using output from step1
3. Merge results from step2 by phenotype
4. Reorganize output files and publish them to destination folder

## Inputs

- step1 input are plink datasets, defined as `{ "prefix": "file", "bed": "file.bed", "bim": "file.bim", "fam": "file.fam" }`
- step2 input are bgen/sample datasets, defined as `{ "prefix": "file", "bgen": "file.bgen", "sample": "file.sample" }`
- a tab-separated phenotype file
- a tab-separated covariate file
- optionally, you can provide a snplist (`step1_qc_snplist`) and list of samples (`step1_qc_keep`) to subset the step1 input 
- configurable options: step1/step2 threads/mem, ref-first, maxCatCovars, binary pheno.

See `regenie_inputs.json` for the complete list of parameters.

## How to run on DNANexus

The workflow can be run on DNANexus using the following command:

```bash
dx run /workflows/regenie/regenie_gwas \
	-f input_confgiuration.json \
	--destination /workflows/regenie/out \
	--priority high
```

### Prepare input JSON

An example of the json configuration file is provided in [example/example_input.json](example/example_input.json). Adapt this file to your needs. 

Keep in mind that all input files must be provided as DNANexus link objects. This means they have to be indicated by DNANexus file ID and project ID (when the file is not in the same project as the workflow).

Example for a file in the same project:

```json
{ "$dnanexus_link": "file-Gx6JqFQJ08pQqgF9b577b5XQ" }
```

Example for a file in a different project:

```json
{ "$dnanexus_link": { "project": "project-Gx6JqFQJ08pQqgF9b577b5XQ", "id": "file-Gx6JqFQJ08pQqgF9b577b5XQ" } }
```

You can get the file ID of a specific file by running `dx describe /path/to/file`.