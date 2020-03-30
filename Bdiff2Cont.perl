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

my $sections = 128;

my $type = $ARGV[0];

my $fbase="All.sha1c/${type}_";
my $fbasei ="/data/All.blobs/${type}_";

my (%fhos);
my $sec = $ARGV[1];
my ($count, $new) = (0, 0);
my $pre = "/fast";
tie %{$fhos{$sec}}, "TokyoCabinet::HDB", "$pre/${fbase}$sec.tch", TokyoCabinet::HDB::OWRITER | TokyoCabinet::HDB::OCREAT,
   16777213, -1, -1, TokyoCabinet::TDB::TLARGE, 100000
    or die "cant open $pre/$fbase$sec.tch\n";  
open (FD, "$fbasei$sec.bin") or die "$!";
binmode(FD);
if ( -f "$fbasei$sec.idx"){
  open A, "$fbasei$sec.idx" or die ($!);
  my $boff = 0;
  while (<A>){
    chop ();
    my ($of, $len, $lc, $dhash, $hash) = split (/\;/, $_, -1);
    my $h = fromHex ($hash);
    $count ++;
#print STDERR "$count;$of\n";
    my $codeC = "";
    next if $len > 2147483647;
    if (!defined $fhos{$sec}{$h}){
      seek (FD, $of, 0) if $of != tell (FD);
      my $rl = read (FD, $codeC, $len);
      $fhos{$sec}{$h} = $codeC;
      $new ++;
    }
  }
}else{
  die "no $fbasei$sec.idx\n";
}
print "$count ${type}s looked at and $new new added\n";
untie %{$fhos{$sec}};

