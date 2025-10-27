#!/usr/local/bin/perl

use strict;
use warnings;
use utf8;
use CGI qw/:standard/;

my $query = new CGI;
# If POSTed data is not of type application/x-www-form-urlencoded or
# multipart/form-data:
# my $post_data = $query->param('POSTDATA');

my $error = $query->cgi_error;
if ($error) {
  print
    $query->header(-status=>$error),
    $query->start_html('Problems'),
    $query->h2('Request not processed'),
    $query->strong($error);
  exit 0;
}

print
  $query->header,
  $query->start_html('JBrowse'),
  $query->h1('Not implemented yet but will load a track'),
  $query->p(<<"__PARAGRAPH__"),
Things remaining to implement:<br/>
<pre>
- Get genome id GENOME_ID.
- Get track name TRACK.
- Get FASTA, GFF3 and BAM file path.
- Make sure file exists.
- Load files.
mkdir -p /data/jbrowse/$GENOME_ID
cd /data/jbrowse/$GENOME_ID
ln -s /data/genoring/$GENOME_ID/$FASTA_FILE /data/jbrowse/$GENOME_ID/$FASTA_FILE
printf "[GENERAL]\nrefSeqs=${FASTA_FILE}.fai\n[tracks.refseq]\nurlTemplate=${FASTA_FILE}\nstoreClass=JBrowse/Store/SeqFeature/IndexedFasta\ntype=Sequence\n" > tracks.conf

SAM
printf "[tracks.alignments]\nurlTemplate=${BAM_FILE}\nstoreClass=JBrowse/Store/SeqFeature/BAM\ntype=Alignments2\n"
# or CRAM
# samtools index $CRAM_FILE
# printf "[tracks.alignments]\nurlTemplate=${CRAM_FILE}\nstoreClass=JBrowse/Store/SeqFeature/CRAM\ntype=Alignments2\n"

Search indexation.
bin/generate-names.pl
</pre>
__PARAGRAPH__
  $query->end_html;
