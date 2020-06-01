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
my (%c2p1);
my $nsec = 8;
$nsec = $ARGV[1] if defined $ARGV[1];

my $lines = 0;
my $nn = $ARGV[0];
my $f0 = "";
my $cnn = 0;
my $nc = 0;
while (<STDIN>){
  chop();
  $lines ++;
  my ($hsha, $f, $b, $p) = split (/\;/, $_);
  if ($hsha !~ m|^[0-9a-f]{40}$|){
    print STDERR "bad sha:$_\n";
    next;
  }
  my $sha = fromHex ($hsha);
  $p =~ s/.*github.com_(.*_.*)/$1/;
  $p =~ s/^bitbucket.org_/bb_/;
  $p =~ s/\.git$//;
  $p =~ s|/*$||;
  $p =~ s/\;/SEMICOLON/g;
  $p = "EMPTY" if $p eq "";
  $nc++ if !defined $c2p1{$p}; 
  $c2p1{$p}{$sha}++;
  print STDERR "$lines done $nc projects\n" if (!($lines%100000000));
}

print STDERR "read $lines and dumping $nc projects\n";
$lines = 0;
outputTC ($nn);
print STDERR "dumped $lines\n";

sub output {
  my $n = $_[0];
  open A, '>:raw', "$n"; 
  while (my ($k, $v) = each %c2p1){
    my @shas = sort keys %{$v};
    my $nshas = $#shas+1;
    my $nsha = pack "L", $nshas;
    my $lp = pack "S", length($k);
    print A $lp;
    print A $k;
    print A $nsha;
    print A "".(join '', @shas);
  }
}



sub outputTC {
  my $n = $_[0];
  my %c2p;
  for my $sec (0..($nsec -1)){
    my $fname = "$ARGV[0].$sec.tch";
    $fname = "$ARGV[0]" if $nsec == 1;
    tie %{$c2p{$sec}}, "TokyoCabinet::HDB", "$fname", TokyoCabinet::HDB::OWRITER | TokyoCabinet::HDB::OCREAT,   
        16777213, -1, -1, TokyoCabinet::TDB::TLARGE, 100000
      or die "cant open $fname\n";
  }
  while (my ($c, $v) = each %c2p1){
    $lines ++;
    print STDERR "$lines done out of $nc\n" if (!($lines%100000000));
    my $ps = join '', sort keys %{$v};
    #my $psC = safeComp ($ps);
    my $sec = (unpack "C", substr ($c, 0, 1))%$nsec;
    $c2p{$sec}{$c} = $ps;
  }
  for my $sec (0..15){
    untie %{$c2p{$sec}};
  }
}
