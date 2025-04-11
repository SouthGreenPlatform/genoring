GenoRing Tools Module
=====================

Contains multiple bioinformatics tools that can be used by GenoRing and its
module *in backend mode* to perform tasks on data files.

In the future, there might be more services and service access may be changed to
increase security level (parameters check, authentication).


Services
--------

Available services are (http://genoring-genoringtools/cgi-bin/...):
- bgzip
- busco
- faidx
- gff3sort
- gt
- samtools
- tabix
- vcftools

Except faidx that takes 2 parameters "fasta" and "output", other services only
take one parameter "param" with all the command line parameters.

Ex.:
http://genoring-genoringtools/cgi-bin/tabix?param=-p%20gff%20%2Fdata%2Fgenoring%2Fsrc%2Fother%2Fsome.gff3.gz

All services output a JSON response with the following keys:
  {
    'error' => '000 The error code with a single line text',
    'output' => 'multi-line text printed to STDOUT and STDERR.',
    'message' => 'Error message or other type of message provided by this script',
    'command' => 'The executed command line with its parameters',
    # Additional keys like file URIs, tokens, etc. may be added by some services.
  }

Nb.: Error code is part of the JSON answer if it is different from "200", but is
also always returned as the HTTP response code so it can be checked without
parsing the JSON data.


Security
--------
This service does not expose by default any port and could only be queried
within the Docker network it is part of, by other Docker containers of the same
network. However, since it does not support authentication at the moment and it
should only be used in specific cases, the service will only be running in
"backend" mode.

The "backend" mode can be used when the GenoRing administrator needs to perform
modifications on the GenoRing website. The Drupal CMS will remain online but in
"maintenance" mode which means only administrators can log in and access the
full site interface while other users would only see a maintenance page.
To log in, administrators can use the URL "https://your.site.com/user/login".

To start GenoRing in backend mode, stop GenoRing and restart it using the
command line:

    perl genoring.pl backend

Once done with backend operations, you can switch back to production:

    perl genoring.pl stop
    perl genoring.pl start
