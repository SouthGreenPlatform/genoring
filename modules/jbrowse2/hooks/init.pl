#!/usr/bin/env perl

use strict;
use warnings;

++$|; #no buffering

if (!-d './volumes/proxy/genoring') {
  mkdir './volumes/proxy/genoring';
}

if (!-e './volumes/proxy/genoring/jbrowse2.conf') {
  copy('./modules/jbrowse2/res/nginx/jbrowse2.conf', './volumes/proxy/genoring/jbrowse2.conf');
}
