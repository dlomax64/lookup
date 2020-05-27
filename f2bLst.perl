#!/usr/bin/perl
use lib ("$ENV{HOME}/lookup", "$ENV{HOME}/lib64/perl5","$ENV{HOME}/lib/perl5", "$ENV{HOME}/lib/x86_64-linux-gnu/perl", "$ENV{HOME}/share/perl5");
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
while (my ($codeC, $vs) = each %clones){
	my $lC = length($codeC);
	my $l = length($vs);
        $codeC =~ s/;/SEMICOLON/g;
        $codeC =~ s/\r/CRCRCR/g;
        $codeC =~ s/\n/NEWLINE/g;
	print "$lC\;$l\;$codeC";
        for my $i (0..($l/20-1)){
          print ";".(unpack "H*", substr($vs, $i*20, 20));
        }
        print "\n";
}
untie %clones;
