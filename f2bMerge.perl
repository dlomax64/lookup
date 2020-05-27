#!/usr/bin/perl
use lib ("$ENV{HOME}/lookup", "$ENV{HOME}/lib64/perl5","$ENV{HOME}/lib/perl5", "$ENV{HOME}/lib/x86_64-linux-gnu/perl", "$ENV{HOME}/share/perl5");

use strict;
use warnings;
use Compress::LZF;
use TokyoCabinet;
use Time::Local;



my $outN = $ARGV[0];
my %out;
tie %out, "TokyoCabinet::HDB", "$outN.tch", TokyoCabinet::HDB::OWRITER |  TokyoCabinet::HDB::OCREAT,
  16777213, -1, -1, TokyoCabinet::TDB::TLARGE, 100000
  or die "cant open $outN.tch\n";


sub get {
  my ($k, $v, $res) = @_;
  my $l = length($v);
  for my $i (0..($l/20)){
    $res->{substr($v, $i*20, 20)}++;
  }
}

my %in;
my %res;
my $lines = 0;

my $j  = 0;
while (<STDIN>){
  chop();
  my $fname = $_;
  print STDERR "processing $fname\n";
  tie %in, "TokyoCabinet::HDB", "$fname", TokyoCabinet::HDB::OREADER,
     16777213, -1, -1, TokyoCabinet::TDB::TLARGE, 100000
     or die "cant open $fname\n";
  while (my ($k, $v) = each %in){
    print STDERR "$lines done\n" if (!(($lines++)%100000000));
    get ($k, $v, \%{$res{$k}});
  }
  untie %in;
}

print STDERR "writing $lines\n";
$lines = 0;
while (my ($k, $v) = each %res){
  $lines++;
  $out{$k} = join "", sort keys %{$v};  
}
print STDERR "done $lines\n";

untie %out;

