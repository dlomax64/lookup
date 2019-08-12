#!/usr/bin/perl -I /home/audris/lib64/perl5 -I /home/audris/lib/x86_64-linux-gnu/perl
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

#BEGIN { $SIG{'__WARN__'} = sub { print STDERR $_[0]; } };

my $split = 32;

my (%c2ta);
my $ver = $ARGV[0];

for my $s (0..($split-1)){ 
  tie %{$c2ta{$s}}, "TokyoCabinet::HDB", "/fast/c2taFull$ver.$s.tch", TokyoCabinet::HDB::OREADER| TokyoCabinet::HDB::ONOLCK,
      16777213, -1, -1, TokyoCabinet::TDB::TLARGE, 100000
     or die "cant open /fast/c2taFull$ver.$s.tch\n";
}
my $bp = "";
my ($bh, $ch) = ("","");
my %as = (); 
while (<STDIN>){
  chop();
  ($bh, $ch) = split(/\;/, $_, -1);
  if ($bp ne "" && $bp ne $bh){
    output (\%as);
    %as = (); 
  }
  my $c = fromHex ($ch);
  my $s = (unpack "C", substr ($c, 0, 1)) % $split;
  if (defined $c2ta{$s}{$c}){
    my ($t, $a) = split (/;/, $c2ta{$s}{$c});
    $as{$t}{"$ch;$a"}++;
  }else{
    print STDERR "no time for $ch in $bh\n";
  }
  $bp = $bh;
}
output (\%as);

sub output {
  my $asp = $_[0];
  my %as = %{$asp};
  my $f = (sort { $a+0 <=> $b +0 } keys %as)[0];
  my @aa = sort keys %{$as{$f}};
  print STDERR "same time $bh;$ch;@aa\n" if $#aa>0;
  my ($ch0, $au) = split (/;/, $aa[0], -1);
  print "$bp;$f;$au;$ch0\n";  
}

for my $s (0..($split-1)){ 
  untie %{$c2ta{$s}};
};




