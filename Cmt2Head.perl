#!/usr/bin/perl
use lib ("$ENV{HOME}/lookup", "$ENV{HOME}/lib64/perl5","$ENV{HOME}/lib/perl5", "$ENV{HOME}/lib/x86_64-linux-gnu/perl", "$ENV{HOME}/share/perl");
use strict;
use warnings;
use Error qw(:try);

use TokyoCabinet;
use Compress::LZF;

sub toHex { 
        return unpack "H*", $_[0]; 
} 

sub fromHex { 
        return pack "H*", $_[0]; 
} 

BEGIN { $SIG{'__WARN__'} = sub { if (0) { print STDERR $_[0]; } } };

my $split = 32;

my (%c2h, %c2cc);
my $sec = $ARGV[0];
my $ver = $ARGV[1];

for my $s (0..($split-1)){
  tie %{$c2h{$s}}, "TokyoCabinet::HDB", "/fast/c2hFull$ver.$s.tch", TokyoCabinet::HDB::OWRITER | TokyoCabinet::HDB::OCREAT | TokyoCabinet::HDB::ONOLCK,
    16777213, -1, -1, TokyoCabinet::TDB::TLARGE, 100000
    or die "cant open /fast/c2hFull$ver.$s.tch\n";
}

for my $s (0..($split-1)){ 
  tie %{$c2cc{$s}}, "TokyoCabinet::HDB", "/fast/c2ccFull$ver.$s.tch", TokyoCabinet::HDB::OREADER | TokyoCabinet::HDB::ONOLCK,
      16777213, -1, -1, TokyoCabinet::TDB::TLARGE, 100000
     or die "cant open /fast/c2ccFull$ver.$s.tch\n";
}
my $ncalc = 0;
my $nlook = 0;
my $mdepth x= 0;
open A, 'cut -d\; -f4'." /data/All.blobs/commit_$sec.idx /data/All.blobs/commit_".($sec+32).".idx /data/All.blobs/commit_".($sec+64).".idx /data/All.blobs/commit_".($sec+96).".idx|";
while (<A>){
  chop();
  my $ch = $_;
  my $c = fromHex ($ch);
  my $s = (unpack "C", substr ($c, 0, 1)) % $split;
  $nlook ++;
  if (!defined $c2h{$s}{$c}){	  
     #my $res = $c2h{$s}{$c};
     #my $h = substr($res, 0, 20);
     #my $d1 = unpack "w", substr($res, 20, length($res) - 20);
     #print "F;$ch;".(toHex($h)).";$d1\n";
     #}else{
    if (defined $c2cc{$s}{$c}){
      my $v = substr($c2cc{$s}{$c}, 0, 20);
      my ($ch, $h, $d) = findHead ($ch, $v, 1);
      my $dp = pack 'w', $d;
      $c2h{$s}{$c} = $h.$dp;
      $mdepth = $d if $d > $mdepth;
      print "F:$ch;".(toHex($v)).";".(toHex($h)).";$d;looked=$nlook;calculated=$ncalc;maxdep=$mdepth\n" if !(($ncalc++)%500000);
    }else{
      #print "F:$ch;$ch;$ch;0\n;"
    }
  }
}
print "looked=$nlook;calculated=$ncalc;maxdep=$mdepth\n";

for my $s (0..($split-1)){ 
  untie %{$c2h{$s}};
  untie %{$c2cc{$s}};
};

sub findHead {
  my ($fr, $cc, $d) = @_;
    
  my $s = (unpack "C", substr ($cc, 0, 1)) % $split;
  my $v1 = defined $c2cc{$s}{$cc} ? substr($c2cc{$s}{$cc}, 0, 20)  : "";
  if ($v1 eq ""){
    my $dp = pack 'w', 0;
    $c2h{$s}{$cc} = $cc.$dp;
    return ($fr, $cc, $d);
  }
  my $s1 = (unpack "C", substr ($v1, 0, 1)) % $split;
  #print "".(toHex($v1)).";".(defined $c2h{$s1}{$v1})."\n";
  if (defined $c2h{$s1}{$v1}){
    my $res = $c2h{$s1}{$v1};
    my $h = substr($res, 0, 20);
    my $d1 = unpack "w", substr($res, 20, length($res) - 20);
    #print "--$fr;".(toHex($v1)).";".(toHex($h)).";d+d1=".($d+$d1).";d1=$d1\n";
    my $dp = pack 'w', $d1+1;
    $c2h{$s}{$cc} = $h.$dp;
    return ($fr, $h, $d1+$d+1);
  }
  
  #print "- $fr;".(toHex($cc)).";".(toHex($v1)).";$d\n";
  my ($fr1, $h, $d1) = findHead ($fr, $v1, $d+1);
  #print "+ $fr1;".(toHex($cc)).";".(toHex($v1)).";$d;$d1\n";
  if (!defined ($c2h{$s}{$cc})){
    my $dp = pack 'w', $d1-$d;
    $c2h{$s}{$cc} = $h.$dp;
  }
  ($fr1, $h, $d1);
}



