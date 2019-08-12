#!/usr/bin/perl

use strict;
use warnings;

my $str = $ARGV[0];
my $off = 0;
$off = $ARGV[1]-1 if defined $ARGV[1];

my %match;
open A, "gunzip -c $str|";
while(<A>){
        chop();
        next if $_ eq "";
        $match{$_}++;
}

my $line = 0;
while(<STDIN>){
  chop();
  $line ++;
  my @x = split(/\;/, $_, -1);
  next if !defined $x[$off] || $x[$off] eq "";
  if (defined $match{$x[$off]}){
    if (defined $ARGV[2] && $ARGV[2] eq "-n"){
      print "$line:$_\n";
    }else{
      print "$_\n";
    }
  }
}

