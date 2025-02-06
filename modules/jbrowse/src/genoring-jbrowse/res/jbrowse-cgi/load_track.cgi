#!/bin/bash
#
# Example Bash CGI script.
#
# Caveat: Remember the empty line after echoing headers
#

# httputils creates the associative arrays POST_PARAMS and GET_PARAMS
declare -A GET_PARAMS
declare -A POST_PARAMS

read_POST_vars() {
  if [[ "$REQUEST_METHOD" = "POST" ]] && [[ ! -z "$CONTENT_LENGTH" ]]; then
    QUERY_STRING_POST=$(dd bs="${CONTENT_LENGTH}" count=1 status=none)
  fi
}

parse_POST_params() {
  local q p k v

  if [[ ! "${QUERY_STRING_POST}" ]]; then
    return
  fi

  q="${QUERY_STRING_POST}&"

  while [[ ! -z "$q" ]]; do
    p="${q%%&*}"  # get first part of query string
    k="${p%%=*}"  # get the key (variable name) from it
    v="${p#*=}"   # get the value from it
    q="${q#$p&*}" # strip first part from query string

    POST_PARAMS["${k}"]="${v}"
  done
}

parse_GET_params() {
  local q p k v

  if [[ ! "${QUERY_STRING}" ]]; then
    return
  fi

  q="${QUERY_STRING}&"

  while [[ ! -z "$q" ]]; do
    p="${q%%&*}"  # get first part of query string
    k="${p%%=*}"  # get the key (variable name) from it
    v="${p#*=}"   # get the value from it
    q="${q#$p&*}" # strip first part from query string

    GET_PARAMS["${k}"]="${v}"
  done
}

read_POST_vars
parse_POST_params
parse_GET_params

POST_vars_to_str() {
  local __resultvar=$1
  local q
  for param in "${!POST_PARAMS[@]}"; do
    q="${q} \"${param}\": \"${POST_PARAMS[$param]}\"," 
  done
  eval $__resultvar="'$q'"
}

do_POST() {
  POST_vars_to_str result
  echo "Status: 200 OK"
  echo ""
  cat <<JSON
{
    $result
}
JSON
}
do_GET() {
  echo "Status: 405 Method Not Allowed"
  echo ""
  cat <<JSON
{
    "query_string": "$QUERY_STRING"
}
JSON
}

# Print out available ENV vars
#/usr/bin/env

# Common headers goes here
echo "Content-Type: application/json"

case $REQUEST_METHOD in
  POST)
    do_POST
    ;;
  GET)
    do_GET
    ;;
  *)
    echo "No handle for $REQUEST_METHOD"
    exit 0
    ;;
esac

# Get genome id.
# GENOME_ID
# Get track name.
# TRACK
# Get FASTA, GFF3 and BAM file path.
# FASTA_FILE GFF3_FILE BAM_FILE
# Make sure file exists.
# Load files.
# # FASTA
# mkdir -p /data/jbrowse/$GENOME_ID
# cd /data/jbrowse/$GENOME_ID
# ln -s /data/genoring/$GENOME_ID/$FASTA_FILE /data/jbrowse/$GENOME_ID/$FASTA_FILE
# samtools faidx $FASTA_FILE
# printf "[GENERAL]\nrefSeqs=${FASTA_FILE}.fai\n[tracks.refseq]\nurlTemplate=${FASTA_FILE}\nstoreClass=JBrowse/Store/SeqFeature/IndexedFasta\ntype=Sequence\n" > tracks.conf

# # GFF3
# gt gff3 -sortlines -tidy $GFF3_FILE > ${GFF3_FILE}.sorted.gff3
# # or (https://github.com/billzt/gff3sort)
# # perl /opt/gff3sort/gff3sort.pl --precise $GFF3_FILE >${GFF3_FILE}.sorted.gff3
# bgzip ${GFF3_FILE}.sorted.gff3
# tabix -p gff ${GFF3_FILE}.sorted.gff3.gz
# printf "[tracks.genes]\nurlTemplate=${GFF3_FILE}.sorted.gff3.gz\nstoreClass=JBrowse/Store/SeqFeature/GFF3Tabix\ntype=CanvasFeatures\n"

# SAM
# samtools index $BAM_FILE
# printf "[tracks.alignments]\nurlTemplate=${BAM_FILE}\nstoreClass=JBrowse/Store/SeqFeature/BAM\ntype=Alignments2\n"
# # or CRAM
# # samtools index $CRAM_FILE
# # printf "[tracks.alignments]\nurlTemplate=${CRAM_FILE}\nstoreClass=JBrowse/Store/SeqFeature/CRAM\ntype=Alignments2\n"

# Search indexation.
# bin/generate-names.pl
