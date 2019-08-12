#!/usr/bin/perl -I /home/audris/lib64/perl5 -I /da3_data/lookup

use strict;
use warnings;
use Error qw(:try);
use TokyoCabinet;
use Compress::LZF;
use cmt;

my $part = $ARGV[0];

my $sections = 32;


my %c2f;
for my $s (0..($sections-1)){
  tie %{$c2f{$s}}, "TokyoCabinet::HDB", "/fast/c2fFullO.$s.tch", TokyoCabinet::HDB::OREADER | TokyoCabinet::HDB::ONOLCK,   
        16777213, -1, -1, TokyoCabinet::TDB::TLARGE, 100000
     or die "cant open fast/c2fFullO.$s.tch\n";
}

my %a2f;
tie %a2f, "TokyoCabinet::HDB", "/fast/a2fFullO.$part.tch", TokyoCabinet::HDB::OWRITER | TokyoCabinet::HDB::OCREAT,
        16777213, -1, -1, TokyoCabinet::TDB::TLARGE, 100000
     or die "cant open /fast/a2fFullO.$part.tch\n";

my %badC;
for my $c (keys %badCmt){
  $badC{fromHex ($c)}++;
}
my $line = 0;
my (@cs, %a2f1);
my $pa = "";
while (<STDIN>){
  chop();
  my ($a, $ch) = split (/\;/, $_, -1);
  my $c = fromHex ($ch);
  if ($pa ne "" && $pa ne $a){
    output ($pa);
    @cs = ();
  }
  push @cs, $c;
  $pa = $a;
  if (!(($line++)%1000000)){
    print STDERR "processed $line lines\n";
  } 
}
output ($pa);

sub output {
  my $a = $_[0];
  my %fs;
  for my $c (@cs){
    my $sec =  segB ($c, $sections);
    if (defined $c2f{$sec}{$c}){
      my @fs = split(/\;/, safeDecomp ($c2f{$sec}{$c}, $a), -1);
      for my $f (@fs){
        $fs{$f}++;
      }
    }
  }
  $a2f{$a} = safeComp (join ';', (keys %fs));
}


for my $sec (0..($sections-1)){
  untie %{$c2f{$sec}};
}
untie %a2f;



