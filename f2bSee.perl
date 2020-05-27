#!/usr/bin/perl
use lib ("$ENV{HOME}/lookup", "$ENV{HOME}/lib64/perl5","$ENV{HOME}/lib/perl5", "$ENV{HOME}/lib/x86_64-linux-gnu/perl", "$ENV{HOME}/share/perl");
use strict;
use warnings;
use Error qw(:try);

use Digest::MD5 qw(md5 md5_hex md5_base64);
use TokyoCabinet;
use Compress::LZF;

my $fname="$ARGV[0]";
my (%clones);
my $hdb = TokyoCabinet::HDB->new();

if(!tie(%clones, "TokyoCabinet::HDB", "$fname",
                  TokyoCabinet::HDB::OREADER)){
        print STDERR "tie error for $fname\n";
}

sub safeDecomp {
        my $codeC = $_[0];
        try {
                my $code = decompress ($codeC);
                return $code;
        } catch Error with {
                my $ex = shift;
                print STDERR "Error: $ex\n";
                return "";
        }
}


my $offset = 0;
my $justBlobs = 0;
$justBlobs = $ARGV[1] if defined $ARGV[1];

while (<STDIN>){
  chop ();
  my $k = $_;
  if (! defined $clones{$k}){
    print STDERR "$k\n";
    next;
  }
  my $vs = $clones{$k};
  my $l = length($vs);
  if (! $justBlobs){
    print "$k;$l";
    for my $i (0..($l/20-1)){
      print ";".(unpack "H*", substr($vs, $i*20, 20));
    }
    print "\n";
  }else{
    for my $i (0..($l/20-1)){
      print "".(unpack "H*", substr($vs, $i*20, 20))."\n";
    }
  }
} 
untie %clones;
