#!/usr/bin/perl -I /home/audris/lib64/perl5

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

my %p2c;
tie %p2c, "TokyoCabinet::HDB", $ARGV[0], TokyoCabinet::HDB::OREADER,
        16777213, -1, -1, TokyoCabinet::TDB::TLARGE, 100000
     or die "cant open $ARGV[0]\n";


my $nsec = 1;
my $doSec = 0;
if (defined $ARGV[2]){
  $nsec = $ARGV[2]+0;
  $doSec = $ARGV[3]+0;
}
my %c2p;
my $lines = 0;
my $nc = 0;
while (my ($prj, $v) = each %p2c){
  $prj =~ s/\;/SEMICOLON/g;
  my $ns = length($v)/20;
  for my $i (0..($ns-1)){
    my $c = substr ($v, 20*$i, 20);
    if ($nsec > 1){
      my $sec = (unpack "C", substr ($c, 0, 1))%$nsec;
      $nc ++ if !defined $c2p{$c};
      $c2p{$c}{$prj} ++ if $sec == $doSec;
    }else{
      $c2p{$c}{$prj} ++;
      $nc ++ if !defined $c2p{$c};
    }
  }
  $lines ++;
  print STDERR "$lines done $nc\n" if (!($lines%10000000)); 
  #last if $lines > 100000; 
}  
untie %p2c;

my %c2p1;
tie %c2p1, "TokyoCabinet::HDB", $ARGV[1], TokyoCabinet::HDB::OWRITER | TokyoCabinet::HDB::OCREAT,   
        16777213, -1, -1, TokyoCabinet::TDB::TLARGE, 100000
     or die "cant open $ARGV[1]\n";

sub safeComp {
  my $code = $_[0];
  try {
    my $codeC = compress ($code);
    return $codeC;
  } catch Error with {
    my $ex = shift;
    print STDERR "Error: $ex\n$code\n";
    return "";
  }
}

print STDERR "writing $lines\n";
$lines = 0;
while (my ($c, $v) = each %c2p){
  $lines ++;
  print STDERR "$lines done out of $nc\n" if (!($lines%1000000));
  my $ps = join ';', keys %{$v};
  my $psC = safeComp ($ps);
  $c2p1{$c} = $psC;
}

untie %c2p1;




