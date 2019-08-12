#!/usr/bin/perl -I /home/audris/lib64/perl5 -I /home/audris/lib/x86_64-linux-gnu/perl
#
use strict;
use warnings;
use Error qw(:try);

use TokyoCabinet;

my $fname="$ARGV[0]";
my (%clones);
my $hdb = TokyoCabinet::HDB->new();

if(!tie(%clones, "TokyoCabinet::HDB", "$fname",
                  TokyoCabinet::HDB::OREADER | TokyoCabinet::HDB::ONOLCK)){
        print STDERR "tie error for $fname\n";
}

while (my ($c, $v) = each %clones){
  my $lk = length($c);
  my $lv = length($v);
  my $lkb = pack 'l', $lk;
  my $lvb = pack 'l', $lv;
  print "$lkb$lvb$c$v";
}
untie %clones;

