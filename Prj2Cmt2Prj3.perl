#!/usr/bin/perl
use lib ("$ENV{HOME}/lookup", "$ENV{HOME}/lib64/perl5","$ENV{HOME}/lib/perl5", "$ENV{HOME}/lib/x86_64-linux-gnu/perl", "$ENV{HOME}/share/perl");
use strict;
use warnings;
use Error qw(:try);

use TokyoCabinet;
use Compress::LZF;
use cmt;


my $split = 32;

my %p2c;
for my $sec (0..($split-1)){
  my $fname = "p2cFullN.$sec.tch";
  tie %{$p2c{$sec}}, "TokyoCabinet::HDB", "$fname", TokyoCabinet::HDB::OREADER,   
        16777213, -1, -1, TokyoCabinet::TDB::TLARGE, 100000
      or die "cant open $fname\n";
}


my %c2p;
for my $sec (0..($split-1)){
  my $fname = "c2pFullN.$sec.tch";
  tie %{$c2p{$sec}}, "TokyoCabinet::HDB", "$fname", TokyoCabinet::HDB::OREADER,
         16777213, -1, -1, TokyoCabinet::TDB::TLARGE, 100000
      or die "cant open $fname\n";
}
my %badC;
open A, "zcat largeCmt|";
while (<A>){
  chop();
  my $c = fromHex ($_);
  $badC{$c}++;
}
open A, "zcat /data/emptycs|";
while (<A>){
  chop();
  my $c = fromHex ($_);
  $badC{$c}++;
}

my %p0;
open A, "$ARGV[0]";
while (<A>){
  chop();
  $p0{$_}++;
}
my %pc = ();
my %cp = ();
my %ps = ();
my %psE = ();
my %cs2 = ();
my %csE = ();
my %empty;
for my $p1 (keys %p0){
  my $sec1 = 0;
  $sec1 = sHash ($p1, $split);
  if (defined $p2c{$sec1}{$p1}){
    list ($p2c{$sec1}{$p1}, \%{$pc{$p1}}, \%empty);
    for my $c (keys %{$pc{$p1}}) { $csE{$c}++};
  }
}
print STDERR "ncsE=".(scalar(keys %csE))."\n";

for my $c (keys %csE){
  my $secc = segB ($c, $split);
  if (defined $c2p{$secc}{$c}){
    list1 ($c2p{$secc}{$c}, \%{$cp{$c}}, \%empty);
    for my $p (keys %{$cp{$c}}) { $psE{$p}++};
  }
}
print STDERR "npsE=".(scalar(keys %psE))."\n";

sub diff {
  my $p1 = $_[0];
  my $n = 0;
  my $np = 0;
  
  my %extra = ();
  for my $c (keys %{$pc{$p1}}){
    my @ps = keys %{$cp{$c}};
    my $nn = 0;
    for my $p (@ps){
      if ($p ne $p1){
        if (!defined $p0{$p}){
	  $extra{$p}++;
	} else {
	  $nn++;
        }
      }
    }
    $n ++ if $nn == 0;
  }
  ($n, scalar (keys %extra));
} 

for my $p1 (keys %p0){
  my ($dC, $dP) = diff ($p1);
  print "$p1;$dC;$dP\n";
}
exit();

for my $p1 (keys %p0){
  my %psL = ();
  for my $c (keys %{$pc{$p1}}){
    if (!defined $csE{$c}){
      my $secc = segB ($c, $split);
       if (defined $c2p{$secc}{$c}){
         list1 ($c2p{$secc}{$c}, \%psL, \%psE);
       }
     }
     $csE{$c}++;
   }
   my $delta = scalar (keys %psL);
    for my $p (keys %psL){ $psE{$p}++; }
    my $npsE = scalar (keys %psE);	
    #my $ncs2 = scalar (@cs3);
    #print STDERR "$p1;uCs=$ncs2;uPs=$delta;csE=".(scalar (keys %csE)).";psE=$npsE\n";
  }
  #}

my @na = keys %csE;
my %csA = ();
my %psA = ();
my %pIn;
while (<STDIN>){
  chop();  
  my ($p, @x) = split(/\;/, $_, -1);
  $pIn{$p}++;

}

for my $p (keys %pIn){
  next if !defined $psE{$p};
  %cs2 = ();
  my $sec = 0;
  my $n = 0;
  $sec = sHash ($p, $split);
  if (defined $p2c{$sec}{$p}){
    $n = listA ($p2c{$sec}{$p}, \%cs2, \%csE, \%csA);
  }
  my @nb = keys %cs2;
  print "0;$p;$n;$ARGV[0];$#na;$#nb\n" if $#nb >= 0;
}

print STDERR "done ncsA=".(scalar(keys %csA))."\n";
my $ndone = 0;
for my $c (keys %csA){
  my $secc = segB ($c, $split);
  list1 ($c2p{$secc}{$c}, \%psA, \%psE) if defined $c2p{$secc}{$c};
  $ndone ++;
  print STDERR "$ndone npsA=".(scalar(keys %psA))."\n" if !($ndone%1000);
}
print STDERR "done npsA=".(scalar(keys %psA))."\n";
my %csA1;
for my $p (keys %pIn){
  next if !defined $psA{$p};
  %cs2 = ();
  my $sec = 0;
  my $n = 0;
  $sec = sHash ($p, $split);
  if (defined $p2c{$sec}{$p}){
    $n = listA ($p2c{$sec}{$p}, \%cs2, \%csA, \%csA1);
  }
  my @nb = keys %cs2;
  print "1;$p;$n;$ARGV[0];$#na;$#nb\n" if $#nb >= 0;
}
print STDERR "done1\n";

my $n = 0;
for my $c (keys %csA1){
  $n ++ if !defined $csA{$c} && !defined $csE{$c};
}
print STDERR "ncsA1=$n\n";

for my $sec (0..($split-1)){
  untie %{$p2c{$sec}};
  untie %{$c2p{$sec}};
}

sub listA {
  my ($v, $cs, $csE, $csA) = @_;
  my $ns = length($v)/20;
  #print STDERR "$ns\n";
  for my $i (0..($ns-1)){
    my $c = substr ($v, 20*$i, 20);
    if (defined $csE ->{$c}){
      $cs ->{$c}++;
    }else{	    
      $csA ->{$c}++;
    }
  }
  $ns;
}

sub list {
  my ($v, $cs, $csE) = @_;
  my $ns = length($v)/20;
  #print STDERR "$ns\n";
  for my $i (0..($ns-1)){
    my $c = substr ($v, 20*$i, 20);
    next if defined $badC{$c};
    $cs ->{$c}++ if !defined $csE ->{$c};
  }
}

sub list1 {
  my ($v, $p, $pE) = @_;
  my $v1 = safeDecomp ($v);
  my @ps = split(/\;/, $v1, -1);
  next if $#ps <= 0;
  for my $p0 (@ps) { $p ->{$p0}++ if !defined $pE ->{$p0}; };
}


