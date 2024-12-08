# Regenie WDL workflow

This is a WDL workflow for running [Regenie](https://rgcgithub.github.io/regenie/) on a set of VCF files. The workflow is designed to run on the DNANexus/RAP platform, but can be run locally as well.

## Steps

1. Run regenie step1 on inpit bed/bim/fam files
2. Run regenie step2 in parallel for each BGEN input, using output from step1
3. Merge results from step2 by phenotype

## Inputs

- step1 input are plink datasets, defined as `{ "prefix": "file", "bed": "file.bed", "bim": "file.bim", "fam": "file.fam" }`
- step2 input are bgen/sample datasets, defined as `{ "prefix": "file", "bgen": "file.bgen", "sample": "file.sample" }`
- a tab-separated phenotype file
- a tab-separated covariate file
- configurable options: step1/step2 threads, ref-first, maxCatCovars, binary pheno.

See regenie_inputs.json for the complete list of parameters.

## How to run on DNANexus

An example of the json configuration file is provided in exmaple/example_input.json. The workflow can be run on DNANexus using the following command:

```bash
dx run /workflows/regenie/regenie_gwas \
	-f input_confgiuration.json \
	--destination /workflows/regenie/regenie_gwas/out \
	--priority high
```

Keep in mind that all input files must be provided as DNANexus link objects. This mean they have to be indicated by DNANexus file ID and project ID (when the file is not in the same project as the workflow).

Example for a file in the same project:

```json
{ "$dnanexus_link": "file-Gx6JqFQJ08pQqgF9b577b5XQ" }
```

Example for a file in a different project:

```json
{ "$dnanexus_link": { "project": "project-Gx6JqFQJ08pQqgF9b577b5XQ", "id": "file-Gx6JqFQJ08pQqgF9b577b5XQ" } }
```
