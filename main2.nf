params.dorado_path = '~/project/dorado/bin/dorado'


process basecall {

	input: 
	path pod5_dir
	val bam_file_name
      
	output:
	file "${bam_file_name}"
	
        publishDir 'results/basecall', mode: 'copy'
	
        script:
	"""
	${params.dorado_path} basecaller fast "${pod5_dir}" --no-trim > "${bam_file_name}"
	"""
} 

process samtools_filter {

        input:
        path bam_file // this is the output of basecall
        val minimum
        val maximum
        
        output:
        file "${bam_file.baseName}_${minimum}_${maximum}.bam"
        
        publishDir 'results/filtered', mode: 'copy'
        
        script:
        def filtered_bam = "${bam_file.baseName}_${params.minimum}_${params.maximum}.bam"
        """
        samtools view -h \\
        -e 'length(seq)>=${minimum} && length(seq)<=${maximum}' \\
        -o ${filtered_bam} \\
        ${bam_file}
        """
}


process demux {

        input:
	path barcode_arrangement
	path barcode_sequences
	val kit_name
	file filtered_bam // this is the output of samtools_filter

	output:
	path demux
	
        publishDir 'results', mode: 'copy'

	script:
	"""
	${params.dorado_path} demux \\
	--barcode-arrangement ${barcode_arrangement} \\
        --barcode-sequences ${barcode_sequences} \\
        --kit-name ${kit_name} \\
        --output-dir demux \\
        ${filtered_bam}
	"""
}

process bam_to_fastq {

	input:
    	path demux

    	output:
    	path "${demux}/fastqs"
    	path "${demux}/bams"

	publishDir 'results', mode: 'copy'


	script:
	"""
	mkdir -p ${demux}/fastqs ${demux}/bams

	for file in ${demux}/*.bam; do 
		base=\$(basename "\$file" .bam)
    		samtools fastq "\$file" > "${demux}/fastqs/\${base}.fastq"
    		mv "\$file" "${demux}/bams"
    	done
    	
    	find ${demux}/fastqs -type f -name "*.fastq" -exec gzip {} \\;

    	
    	"""
}



workflow {
	pod5_dir_ch = Channel.fromPath(params.pod5_dir)
	bam_file_name_ch = Channel.value(params.bam_file_name)
	
	basecall_out = basecall(pod5_dir_ch, bam_file_name_ch)
	samtools_filter_out = samtools_filter(basecall_out, params.minimum, params.maximum)
	
	demux_out = demux(
          file(params.barcode_arrangement),
          file(params.barcode_sequences),
          params.kit_name,
          samtools_filter_out
          )
          
	bam_to_fastq(demux_out)

}



