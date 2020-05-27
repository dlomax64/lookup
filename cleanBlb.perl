#!/usr/bin/perl
use lib ("$ENV{HOME}/lookup", "$ENV{HOME}/lib64/perl5","$ENV{HOME}/lib/perl5", "$ENV{HOME}/lib/x86_64-linux-gnu/perl", "$ENV{HOME}/share/perl");

use strict;
use warnings;


my %m;
while(<STDIN>){
  my @x=split(/;/);
  if (!defined $m{$x[2]}){
    $m{$x[2]}++;
    if ($x[1] eq "blob"){
      next if defined $x[3] && $x[3] =~ m/\.(JPEG|ppm|wav|beam|tif|dds|gsm|pyc|bz2|PNG|JPG|pickle|woff2|bmp|pdf|mp3|elc|o|a|so|gz|png|jpg|zip|class|jar|bin|gif|tar|tgz|ttf|jpeg|ogg|exe|dll)$/;
    }
    print;
  }
}
