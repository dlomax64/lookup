#!/usr/bin/perl
use lib ("$ENV{HOME}/lookup", "$ENV{HOME}/lib64/perl5", "/home/audris/lib64/perl5","$ENV{HOME}/lib/perl5", "$ENV{HOME}/lib/x86_64-linux-gnu/perl", "$ENV{HOME}/share/perl5");
use strict;
use warnings;
use Compress::LZF;
use Digest::SHA qw (sha1_hex sha1);
use Time::Local;

#########################
# create code to versions database
#########################
use TokyoCabinet;

sub fromHex { 
	return pack "H*", $_[0]; 
} 

sub toHex { 
        return unpack "H*", $_[0]; 
} 

my ($prj, $rev, $tree, $parent, $aname, $cname, $alogin, $clogin, $path, $atime, $ctime, $f, $comment) = ("","","","","","","","","","","","","");
my (%c2p, %p2c, %b2c, %c2f);

#my $prj = "";
my $pre = "/fast1/All.sha1c";
my $sections = 128;
# need to update the tree_$sec.tch first ... for new data. like update0 and update1...
my (%fhos);
my (%fhoc);

for my $sec (0 .. ($sections-1)){
  tie %{$fhos{$sec}}, "TokyoCabinet::HDB", "$pre/tree_$sec.tch", TokyoCabinet::HDB::OREADER,  
        16777213, -1, -1, TokyoCabinet::TDB::TLARGE, 100000
     or die "cant open $pre/tree_$sec.tch\n";
  tie %{$fhoc{$sec}}, "TokyoCabinet::HDB", "$pre/commit_$sec.tch", TokyoCabinet::HDB::OREADER,  
        16777213, -1, -1, TokyoCabinet::TDB::TLARGE, 100000
     or die "cant open $pre/commit_$sec.tch\n";
}


sub getCT {
  my $c = $_[0];
  my $sec = hex (substr($c, 0, 2)) % $sections;
  my $cB = fromHex ($c);
  if (!defined $fhoc{$sec}{$cB}){
	 #print STDERR "no commit $c\n";
    return ("", "");
  }
  my $codeC = $fhoc{$sec}{$cB};
  my $code = safeDecomp ($codeC, $c);

  my ($tree, $parent, $auth, $cmtr, $ta, $tc) = ("","","","","","");
  my ($pre, @rest) = split(/\n\n/, $code, -1);
  for my $l (split(/\n/, $pre, -1)){
     #print "$l\n";
     if ($l =~ m/^tree (.*)$/){
		  $tree = $1;
     } 
     $parent .= ":$1" if ($l =~ m/^parent (.*)$/);
     ($auth, $ta) = ($1, $2) if ($l =~ m/^author (.*)\s([0-9]+\s[\+\-]+\d+)$/);
     ($cmtr, $tc) = ($1, $2) if ($l =~ m/^committer (.*)\s([0-9]+\s[\+\-]+\d+)$/);
  }
  $parent =~ s/^:// if defined $parent;
  return ($tree, $parent);
}

my %did = ();
my %didP = ();

my $prev = "";
my $fs="";
while(<STDIN>){
  chop();
  $rev = $_;
  next if length($rev) ne 40;    
  my %map = ();
  my %mapP = ();
  my %map1 = ();
  my %map1P = ();
  my %rename = ();


  my ($tree, $parent) = getCT ($rev);
  if ($tree eq ""){
    print STDERR "no commit $rev\n";
    next;
  }
  my $t1 = getTO ($tree);
  if ($t1 eq ""){
    print STDERR "no tree t1: $tree for $rev\n";
    next;
  }
  getTR ("m", $t1, "", \%map, \%map1); 
  if (defined $parent && $parent ne ""){
    $parent = substr ($parent, 0, 40); #ignore additional parents
    my ($treeP, $parentP) = getCT ($parent);
    if ($treeP eq ""){
      print STDERR "no parent commit: $parent for $rev\n";
      next;
    }
    my $pT1 = getTO ($treeP);
    if ($pT1 eq ""){
      print STDERR "no tree pT1: $tree for parent $parent of $rev\n";
      next;
    }
    getTR ("p", $pT1, "", \%mapP, \%map1P); 
    my ($uM, $uP) = separate (\%map, \%mapP, \%rename);
    while (my ($k, $v) = each %{$uM}){
      my @vs = keys %{$v};
      for my $v0 (@vs){
	  	  my @bs = ();
        if (defined $map1P{$v0}){
		    @bs = keys %{$map1P{$v0}};
        }
        print "$rev;$v0;$k;@bs\n" if $v->{$v0} != 040000;
      }
    }
    while (my ($k, $v) = each %{$uP}){
      my @vs = keys %{$v};
      for my $v0 (@vs){
		  my @bs = ();
        if (defined $map1{$v0}){
		    @bs = keys %{$map1{$v0}};
        }
        print "$rev;$v0;;$k\n" if $v->{$v0} != 040000 && $#bs < 0;
      }
    }
    while (my ($k, $v) = each %rename){
      #my @vs = keys %{$v};
      my @bs0 = keys %{$map1P{$k}};
      my @vs0 = join ':::', sort keys %{$map{$bs0[0]}};
      print "$rev;$k;@bs0;@vs0\n";
    }
  }else{
    while (my ($k, $v) = each %map){
      my @vs = keys %{$v};
      for my $v0 (@vs){
		  #my @ns = join ':::', keys $map1{$v0};
		  print "$rev;$v0;$k;\n" if $v->{$v0} != 040000;
      }
    }
  }
}

sub separate1 {
  my ($k, $m, $mP, $rename) = @_;
  my (%uM, %uP);
  while (my ($k, $v) = each %{$m}){
    if (!defined $mP->{$k}){
      $uM{$k}++; 
    }
  }
  while (my ($k, $v) = each %{$mP}){
    if (!defined $m->{$k}){
      $rename->{$k}++; 
    }
  }
  #my @vs = keys %uM;
  #print "uMC: $k:@vs\n" if $#vs >= 0;
  #my @vs = keys %{$rename};
  #print "uPC: $k:@vs\n" if $#vs >= 0;
}

sub separate {
  my ($m, $mP, $rename) = @_;
  my (%uM, %uP);
  my @vs;
  while (my ($k, $v) = each %{$m}){
	 if (!defined $mP->{$k}){
      $uM{$k} = $v; 
    }else{
		separate1 ($k, $m->{$k}, $mP->{$k}, $rename);
	 }
  } 
  while (my ($k, $v) = each %{$mP}){
	 if (!defined $m->{$k}){
      $uP{$k} = $v; 
    }else{
		#my (%a, %b) = separate1 ($k, $m->{$k}, $mP->{$k});
    }
  } 
  return (\%uM, \%uP);
}

sub getTR {
  my ($lab, $to, $prefix, $map, $map1) = @_;
  if (length ($to) == 0){
    return "";
  }
  while ($to) {
    if ($to =~ s/^([0-7]+) (.+?)\0(.{20})//s) {
      my ($mode, $name, $bytes) = (oct($1),$2,$3);
      my $nO = $name;
      my $bH = toHex ($bytes);
      #print "$lab;$prefix/$name;$bH;$mode\n";
      $map->{$bH}{"$prefix/$nO"} = $mode;
      $map1->{"$prefix/$nO"}{$bH} = $mode;
      if ($mode == 040000){
        #print "got tree: $prefix $bH\n";
        getTR ($lab, getTO($bH), "$prefix/$nO", $map, $map1);
      }
    }    
  }
}


sub extr {
  my $v = $_[0];
  #my $v1 = unpack "H*", $v;
  my $v1 = $v;
  my $n = length($v1);
  my @v2 = ();
  if ($n >= 20){
    for my $i (0..($n/20-1)){
      $v2[$i] = substr ($v1, $i*20, 20);
    }
  }
  return @v2;
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

sub popSeg {
  my ($f1, $map) = @_;
  my @fsegs = split(/\//, $f1, -1);
  my $pre = "/$fsegs[0]";
  $map ->{$pre} = $f1;
  for my $d (1..$#fsegs){
    $pre .= "/$fsegs[$d]";
    $map ->{$pre} = $f1;
  }
  #$map ->{$f1}{f} = 1;
}

sub getTO {
  my $t1 = $_[0];
  my $sec = hex (substr($t1, 0, 2)) % $sections;
  my $tB = fromHex ($t1);
  my $codeC = $fhos{$sec}{$tB};
  if (defined $codeC && length ($codeC) > 0){
    return safeDecomp ($codeC);
  }else{
    return "";
  }
}



sub compare {
  my ($map, $stuff) = @_;
  while (my ($k, $v) = each %{$map}){
     #print "$k;$v\n";
     if ($k eq "/$v"){
        if (defined $did{$k}){           
        }else{
           if (defined $didP{$k}){
             print "$stuff->[0];$k;$didP{$k};$stuff->[1];deleted\n";
           }else{
             print STDERR "$.;no $k;$stuff->[0];;;$stuff->[1]\n";
           }
        }
     }
  }
}
   
for my $sec (0 .. ($sections-1)){
        untie %{$fhos{$sec}};
}




