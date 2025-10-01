params.using_custom = true
params.dorado_path = "${workflow.projectDir}/dorado/bin/dorado"

params.output_bam = 'run_output.bam'

// talked about keeping arrangement and sequence files on the backend
params.barcode_arrangement = '/home/exouser/MuthLab_Nanopore_Analysis_Pipeline/data/Example_Data/Example_Data_Custom_Barcodes/code/7.21.25_NBD_custom_arrangement.toml'
params.barcode_sequences = '/home/exouser/MuthLab_Nanopore_Analysis_Pipeline/data/Example_Data/Example_Data_Custom_Barcodes/code/7.21.25_NBD_custom_96_barcodes.fasta'

params.run_name = params.run_name ?: "${workflow.start.format('MM-dd-yyyy_HH.mm.ss')}_run"
params.output_dir = "pipeline_results/${params.run_name}"


process basecall_custom {

	input:
    	val model_acc
	val kit_name
	val output_bam		
	path pod5_dir
	path barcode_arrangement
	path barcode_sequences

	output:
	file "${output_bam}"
	
	publishDir "${params.output_dir}", mode: 'copy'
	
	script:
	"""
	${params.dorado_path} basecaller ${model_acc} ${pod5_dir} \\
	--barcode-arrangement ${barcode_arrangement} \\
	--barcode-sequences  ${barcode_sequences} \\
	--kit-name ${kit_name} > ${output_bam}
	"""
}

process basecall_kit {

	input:
	val model_acc
	val kit_name
	val output_bam 	
	path pod5_dir	
	
	output:
	file "${output_bam}"

	publishDir "${params.output_dir}", mode: 'copy'

	script:
	"""
	${params.dorado_path} basecaller ${model_acc} ${pod5_dir} \\
	--kit-name ${kit_name} > ${output_bam}
	"""
}

process samtools_filter {
        input:
        file output_bam
        val min
        val max

        output:
        file "*.bam"	
                 
        publishDir "${params.output_dir}", mode: 'copy'
        
        script:        
    """
    if [ "$max" != ".na" ]; then
        samtools view \\
            -h \\
            -e 'length(seq)>=${min} && length(seq)<=${max}' \\
            -o ${output_bam.simpleName}_${min}_${max}.bam \\
            ${output_bam}
    else
        samtools view \\
            -h \\
            -e 'length(seq)>=${min}' \\
            -o ${output_bam.simpleName}_${min}.bam \\
            ${output_bam}
    fi
    """

}

process demux {
    input:
	file output_bam

	output:
	path 'bams'
	
    	publishDir "${params.output_dir}", mode: 'copy'

	script:
	"""
	${params.dorado_path} demux \\
	--output-dir bams \\
	--no-classify \\
	${output_bam}
	"""
}

process bam_to_fastq { 
	input: 
	path bam_dir 
	
	output: 
	path "fastqs" 
	
	publishDir "${params.output_dir}", mode: 'copy'
	
	script: 
	""" 
	mkdir -p fastqs 

	for file in ${bam_dir}/*.bam; do
		base=\$(basename "\$file" .bam) 
		new_name=\$(echo "\$base" | rev | cut -d'_' -f1 | rev)

		cp "\$file" "${params.output_dir}/bams/\${new_name}.bam"

		samtools fastq "${params.output_dir}/bams/\${new_name}.bam" > fastqs/\${new_name}.fastq

	done 

	find fastqs -type f -name "*.fastq" -exec gzip {} \\;  	
	"""
}

process create_visualizations {
	input:
	path fastq_dir

	output:
    path 'visualizations/LengthvsQualityScatterPlot_dot.html'
    path 'visualizations/NanoStats.txt'
    path 'visualizations/NanoComp_lengths_violin.html'
    path 'visualizations/Non_weightedHistogramReadlength.html'
    path 'visualizations/NanoComp_quals_violin.html'

	publishDir "${params.output_dir}", mode: 'copy'

	script:
	"""
	mkdir -p visualizations
	
	if [ -f "${fastq_dir}/unclassified.fastq.gz" ]; then
    		rm "${fastq_dir}/unclassified.fastq.gz"
    	fi
	
	NAMES=""
for file in fastqs/*.fastq.gz; do
    basename=\$(basename "\$file" .fastq.gz)
    barcode_num=\$(echo "\$basename" | grep -o 'barcode[0-9]*' | sed 's/barcode//')

    if [ -z "\$NAMES" ]; then
        NAMES="\$barcode_num"
    else
        NAMES="\$NAMES \$barcode_num"
    fi
done

	
	NanoPlot \\
	--fastq ${fastq_dir}/*.fastq.gz \\
	--outdir visualizations \\
	--plots dot \\
	--no_static \\
	--no_supplementary

    NanoComp \\
        --fastq ${fastq_dir}/*.fastq.gz \\
        --outdir visualizations \\
        --plot violin \\
        --names \$NAMES

    """
}

workflow visualize { 
	main: 
	fastq_files = Channel.fromPath("${params.fastq_dir}", type: 'dir') 
	create_visualizations(fastq_files) 
}

workflow {
	if (params.using_custom) {
		basecall_out = basecall_custom(params.model_acc, 
			params.kit_name, 
			params.output_bam, 
			params.pod5_dir, 
			params.barcode_arrangement, 
			params.barcode_sequences)
 	}  else {
 		basecall_out = basecall_kit(params.model_acc, 
 			params.kit_name, 
 			params.output_bam, 
 			params.output_dir)
 		}
 			
	samtools_filter_out = samtools_filter(basecall_out, params.min, params.max)
	demux_out = demux(samtools_filter_out)
	bam_to_fastq_out = bam_to_fastq(demux_out)
	create_visualizations(bam_to_fastq_out)     
}
