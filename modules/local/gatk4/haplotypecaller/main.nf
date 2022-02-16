// Import generic module functions
include { initOptions; saveFiles; getSoftwareName; getProcessName } from './functions'

params.options = [:]
options        = initOptions(params.options)

process GATK4_HAPLOTYPECALLER {
    tag "$meta.id"
    label 'process_medium'
    publishDir "${params.outdir}",
        mode: params.publish_dir_mode,
        saveAs: { filename -> saveFiles(filename:filename, options:params.options, publish_dir:getSoftwareName(task.process), meta:meta, publish_by_meta:['id']) }

    conda (params.enable_conda ? "bioconda::gatk4=4.2.3.0" : null)
    if (workflow.containerEngine == 'singularity' && !params.singularity_pull_docker_container) {
        container "https://depot.galaxyproject.org/singularity/gatk4:4.2.3.0--hdfd78af_0"
    } else {
        container "quay.io/biocontainers/gatk4:4.2.3.0--hdfd78af_0"
    }

    input:
    tuple val(meta), path(bam), path(bai), path(interval)
    path dbsnp
    path dbsnp_tbi
    path dict
    path fasta
    path fai
    val no_intervals

    output:
    tuple val(meta), path("*.vcf.gz")                   , emit: vcf
    tuple val(meta), path(interval), path("*.vcf.gz")   , emit: interval_vcf
    path "versions.yml"                                 , emit: versions

    script:
    def args = task.ext.args ?: ''
    def prefix    = options.suffix ? "${interval.baseName}_${meta.id}${options.suffix}" : "${interval.baseName}_${meta.id}"
    def avail_mem       = 3
    if (!task.memory) {
        log.info '[GATK HaplotypeCaller] Available memory not known - defaulting to 3GB. Specify process memory requirements to change this.'
    } else {
        avail_mem = task.memory.giga
    }
    def interval_option = no_intervals ? "" : "-L ${interval}"
    def dbsnp_option = dbsnp ? "-D ${dbsnp}" : ""
    """
    gatk \\
        --java-options "-Xmx${avail_mem}g" \\
        HaplotypeCaller \\
        -R $fasta \\
        -I $bam \\
        ${dbsnp_option} \\
        ${interval_option} \\
        -O ${prefix}.vcf.gz \\
        $args \\
        --tmp-dir .

    cat <<-END_VERSIONS > versions.yml
    ${getProcessName(task.process)}:
        ${getSoftwareName(task.process)}: \$(echo \$(gatk --version 2>&1) | sed 's/^.*(GATK) v//; s/ .*\$//')
    END_VERSIONS
    """
}
