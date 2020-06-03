#!/usr/bin/perl
use lib ("$ENV{HOME}/lookup", "$ENV{HOME}/lib64/perl5", "/home/audris/lib64/perl5","$ENV{HOME}/lib/perl5", "$ENV{HOME}/lib/x86_64-linux-gnu/perl", "$ENV{HOME}/share/perl5");

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

my $fbase="All.sha1c/commit_";

my (%fhos, %fhoc);
my $pre = "/fast1";
tie %fhoc, "TokyoCabinet::HDB", "$pre/${fbase}author.tch", TokyoCabinet::HDB::OWRITER | TokyoCabinet::HDB::OCREAT,
        16777213, -1, -1, TokyoCabinet::TDB::TLARGE, 100000
     or die "cant open $pre/${fbase}child.tch\n";
for my $sec (0..127){
  tie %{$fhos{$sec}}, "TokyoCabinet::HDB", "$pre/${fbase}$sec.tch", TokyoCabinet::HDB::OREADER,
        16777213, -1, -1, TokyoCabinet::TDB::TLARGE, 100000
     or die "cant open $pre/${fbase}$sec.tch\n";

  while (my ($sha, $v) = each %{$fhos{$sec}}){
    my ($tree, $parent, $auth, $cmtr, $ta, $tc, @rest) = extrCmt ($v);
    #my $hsha = toHex ($sha);
    $auth =~ s/;/SEMICOLON/g;
    $cmtr =~ s/;/SEMICOLON/g;
    $fhoc{$sha} = "$auth;$cmtr;$ta;$tc";
    #print "$sha;$auth;$cmtr;$ta;$tc\n";
  }
  untie %{$fhos{$sec}};
}
untie %fhoc;

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

sub extrCmt {
  my $codeC = $_[0];
  my $code = safeDecomp ($codeC);

  my ($tree, $parent, $auth, $cmtr, $ta, $tc) = ("","","","","","");
  my ($pre, @rest) = split(/\n\n/, $code, -1);
  for my $l (split(/\n/, $pre, -1)){
     $tree = $1 if ($l =~ m/^tree (.*)$/);
     $parent .= ":$1" if ($l =~ m/^parent (.*)$/);
     ($auth, $ta) = ($1, $2) if ($l =~ m/^author (.*)\s([0-9]+\s[\+\-]*\d+)$/);
     ($cmtr, $tc) = ($1, $2) if ($l =~ m/^committer (.*)\s([0-9]+\s[\+\-]*\d+)$/);
  }
  $parent =~ s/^:// if defined $parent;
  return ($tree, $parent, $auth, $cmtr, $ta, $tc, @rest);
}

