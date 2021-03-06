#!/usr/bin/perl
# autoInstaller for lotus
# Copyright (C) 2014  Falk Hildebrand

#This program is free software: you can redistribute it and/or modify
#it under the terms of the GNU General Public License as published by
#the Free Software Foundation, either version 3 of the License, or
#(at your option) any later version.
#This program is distributed in the hope that it will be useful,
#but WITHOUT ANY WARRANTY; without even the implied warranty of
#MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
#GNU General Public License for more details.
#You should have received a copy of the GNU General Public License
#along with this program.  If not, see <http://www.gnu.org/licenses/>.

# contact
# ------
# Falk.Hildebrand [at] gmail.com
# 

use strict;
use warnings;
use Getopt::Long qw( GetOptions );
use Cwd 'abs_path';
use Net::FTP;
my $FILEfetch = eval
{
  require File::Fetch;
  File::Fetch->import();
  1;
};
use File::Copy qw(move);
my $LWPsimple = eval
{
  require LWP::Simple;
  LWP::Simple->import();
  1;
};
my $WGETpres=1;
#if (`command -v wget` eq ""){
if (`whereis wget` eq ""){
	$WGETpres=0;
}

sub addInfoLtS;sub finishAI;
sub getGG;sub getSLV;sub getHITdb; sub getPR2db;sub getbeetax;
sub getS2;
sub getInfoLtS;
sub getInstallVer;
sub compile_sdm;
sub compile_LCA;
sub compile_rtk;
sub checkLtsVer;


my $forceUpdate=0;
if (@ARGV > 0 && $ARGV[0] eq "-forceUpdate"){$forceUpdate=1};
#die "$ARGV[0] $forceUpdate\n";

my $isMac = 1;
if ($^O =~ m/linux/ || $^O =~ m/MSWin/){
	$isMac = 0;
}

my $ldir = abs_path($0);
$ldir =~ s/[^\/]*$//;
#die ($ldir."\n");
my $bdir = $ldir."/bin/";
my $ddir = $ldir."/DB/";
my $finalWarning="";
my $onlyDbinstall = 0;
#options on programs to install..
my $installBlast = 0; my @refDBinstall = 0 x 10; my $ITSready = 0;my $getUTAX=0;

#autoinstaller, test if install was done before
my @txt;
open I,"<","$ldir/lOTUs.cfg" or die $!;
while (my $line = <I>){	push(@txt,$line);}
close I;
my $exe = ""; my $callret;
#print "$ldir/lOTUs.cfg";
my $UID = getInfoLtS("UID",\@txt);
my $uspath = getInfoLtS("usearch",\@txt);

#useach binary linking
my $usearchInstall ="";
if (@ARGV > 0 && $ARGV[0] eq "-link_usearch"){
	$usearchInstall =$ARGV[1];
}


my ($lver,$sver) = getInstallVer("");
if ($forceUpdate==0){
	print "\n\t####################################\n\t LotuS $lver Auto Installer script.\n\t####################################\n\n";
} else {
	print "\n\nRerunning updates due to updated autoupdate.pl script\n\n";
}
if ( ($UID ne "??" && -f $uspath) || $forceUpdate || $usearchInstall ne ""){#set UID, means lotus was installed here
	my $inp="";
	if (!$forceUpdate && $usearchInstall eq ""){
		while ($inp !~ m/\d/){
			print "Detected previous installation of LotuS, do you want to \n (1) search & install updates\n (2) fully reinstall lotus (no LotuS update will be downloaded)\n";
			print " (3) reinstall only databases (no LotuS update will be downloaded, no compilations)?\n";
			print " (4) set the path to you usearch binary (can also be updated)?\n";
			print "Answer: \n";
			$inp = <>;
		}
		chomp($inp);
	}
	if ($inp eq "4"){
		print "Enter the full (absolute) path to your usearch binary:\n";
		while ($usearchInstall eq ""){
			$usearchInstall = <>; chomp $usearchInstall;
			if (!-f $usearchInstall){
				$usearchInstall="";
				print "No valid path, please re-enter (or abort with Ctrl-c):\n";
			}
		}
	}
	if ($usearchInstall ne ""){
		print "Setting usearch binary (required for lotus) to \n";
		if (!-f $usearchInstall){print "Could not find file $ARGV[1]\nPlease ensure this file really exists\n"; exit (33);}
		@txt = addInfoLtS("usearch",$usearchInstall,\@txt,1);
		print "Successfully added usearch into LotuS. Now LotuS is ready to run.\n";
		finishAI("none");
		exit(0);
	}
	my $rerun = 0;
	if ($inp eq "1" || $forceUpdate){
		my ($lsv,$msgEnd) = checkLtsVer($lver);
		#higher version? reinstall lotus.pl, autoinstall.pl, sdm
		if ($lsv ne $lver || $forceUpdate){
			print "New LotuS version available: updating from $lver to $lsv\n";
			getS2("http://psbweb05.psb.ugent.be/lotus/lotus/updates/$lsv/files.tar.gz","files.tar.gz");
			system("tar -xzf files.tar.gz");
			if (-s "autoInstall.pl" != -s "updates/autoInstall.pl" && !$forceUpdate){#at this point call autoupdate again
				$rerun=1; print "Updated autoinstall.pl..\nAttempting to rerun autinstall.pl\n";
				system("rm autoInstall.pl\ncp updates/autoInstall.pl . \n");
				if (system("perl autoInstall.pl -forceUpdate")==0){
					print "sucessfully secondary autoupdating, all steps finished, lotus pipeline is ready to be used.\nTo install new databases/programs that were not installed in the first lotus installation, please rerun installation (skipping the check for updates step).\n"; 
					exit(0);
				} else {print "Failed to rerun autoinstall.pl, please rerun manually after install\n";}
			}
			system("rm autoInstall.pl\ncp updates/autoInstall.pl . \nrm lotus.pl\ncp updates/lotus.pl .;rm -rf sdm_src;mv updates/sdm_src . ;rm -rf LCA_src;mv updates/LCA_src . ;rm -rf rtk_src;mv updates/rtk_src ."); 
			my $nsdmp = compile_sdm("sdm_src"); 
			@txt = addInfoLtS("sdm",$nsdmp,\@txt,1);
			$nsdmp = compile_LCA("LCA_src");
			@txt = addInfoLtS("LCA",$nsdmp,\@txt,1);
			$nsdmp = compile_rtk("rtk_src");
			@txt = addInfoLtS("rtk",$nsdmp,\@txt,1);
			($lver,$sver) = getInstallVer("sdm_src");
			system("rm -rf updates files.tar.gz");
			if (length($msgEnd) >4){print "Additional information for this update:\n$msgEnd\n";}
			print "\nUpdated LotuS to version $lver\n\n";
			if ($rerun){print "\nAutoinstaller was updated.\nTo install new databases/programs that were not installed in the first lotus installation, please rerun installation (skipping the check for updates step).\nIt is necessary to run \"perl autoInstall.pl -forceUpdate\" to apply update!\n";}
			finishAI("u");
			exit(0);
		} else {
			print "You have the actual lotus version installed.\n"; exit(0);
		}
	} elsif($inp eq "3"){
		$onlyDbinstall = 1;
	}
}
#auto update END




#debug section
#


#die();




if ($onlyDbinstall){
	print "Installing LotuS tax databases anew.. \nplease choose which databases to install in the following dialogs\n\n";
}else{
	print "Total space required will be 0.3 - 2.3 Gb. \nSome programs require a recent version of the C++ compiler gcc. Please update (esp. Mac users) your gcc if there are compilation problems.\nWARNING: removes all files in $bdir and $ddir, rewrittes the local lotus.cfg file.\n Continue (y/n)?\n Answer: ";
	while (<>){
		chomp($_);
		if ($_ eq "y" || $_ eq "Y" || $_ eq "yes"){
			last;
		} else {
			exit(0);
		}
	}
	#print "\nThis is an experimental installer. Please send feedback and bug reports to: falk.hildebrand [at] gmail.com\n\n";
	if ($isMac){print "Mac system detected, installing corresponding mac software.\n";}

#decide on blast
	print "\n\nFor similarity based taxonomic assignments LotuS can either use \n (1) Blastn (slow but very sensitve)\n (2) Lambda (fast, a little less sensitive than Blastn)\n (3) both, decide at runtime which to use or\n (0) none\n Answer:";
	while (<>){
		chomp($_);
		if ($_ == 1 || $_ == 3 ||$_ == 2 ||$_ == 0){
			$installBlast = $_;
			last;
		}
	}

}
#system("rm -rf $bdir");
mkdir $bdir unless (-d $bdir);
#system("rm -rf $ddir");
mkdir $ddir unless (-d $ddir);
($lver,$sver) = getInstallVer("$ldir/sdm_src");

#if (length(`ldconfig -p | grep zlib`) < 3){


#decide on some options

print "\n\nDo you want to install a reference database 16S database for similarity based 16S annotations?\n";
print " (1) greengenes (~1 GB)\n (2) SILVA (~2.5 GB), contains LSU as well as SSU\n (3) HITdb (~100 MB) 16S bacterial database specialized on the gut environment.\n";
print " (4) PR2 (~100 MB) a LSU database spezialized on Ocean samples.\n";
print " (5) beeTax (~2 MB) database specialized (and named) on taxonomy specific to the bee gut.\n";
print " (8) HITdb + SILVA + greengenes + PR2 + beeTax (one has to be select for each LotuS run)\n (0) no database\n";
print "Answer:";
while (<>){
	chomp($_); 
	if ($_ == 1 ||$_ == 4 || $_ == 3 ||$_ == 2 ||$_ == 5 ||$_ == 0 ||$_ == 8){
		$refDBinstall[$_] = 1;
		last;
	}
}
#SILVA license
if ($refDBinstall[2] || $refDBinstall[8]){
	print "Please read and accept the SILVA license: https://www.arb-silva.de/fileadmin/silva_databases/LICENSE.txt\n Accepted it (y/n)? \n";
	while (<>){
		chomp($_);
		if ($_ eq "y" || $_ eq "Y" || $_ eq "yes"){
			last;
		} elsif ($_ eq "n" || $_ eq "N") {
			print " You need to accept the SILVA license before the install can finish\n"; exit(0);
		}
	}
}

print "\n\nDo you want to\n (1) install databases and programs required to process ITS data (including fungi ITS UNITE database)\n (0) no ITS related packages\n Answer:";

while (<>){
	chomp($_); 
	if ($_ == 1 ||$_ == 0){
		$ITSready = $_;
		last;
	}
}

#UTAX ref DBs..
print "\n\nDo you want to\n (1) install utax taxonomic classification databases (16S, ITS)?\n (0) no utax related databases\n Answer:";
while (<>){
	chomp($_);
	if ($_ == 1 ||$_ == 0){
		$getUTAX = $_;
		last;
	}
}



#uparse pseudo
my $usearch_reset=0;
if (!-e $uspath){
	$usearch_reset=1;
	$exe = $bdir."usearch_bin";
	@txt = addInfoLtS("usearch",$exe,\@txt,0);
}

if ($usearch_reset==1){
	print "\n\n#######################################################################################";
	print "\nUSEARCH ver 7, 8 or 9 has to be installed manually (due to licensing). Please download & install from http://www.drive5.com/usearch/download.html  \n";
	print "If you have already installed it on this system, please enter the absolute path to usearch below.\nOr continue by entering \"0\" (you have to add it later via \"./autoInstall.pl -link_usearch [path to usearch]\"\n\nAnswer:";
	#print "Once downloaded, rename the binary userachXXX to usearch_bin, make it executable (chmod +x usearch_bin) and copy/link it to this directory:\n$bdir \n";
	#print "\nLotuS is almost ready to run (usearch).\n\n";
	my $inu = "";
	while ( 1){
		$inu = <>; chomp $inu;
		if ($inu eq "0"){$inu="";last;
		} elsif (!-f $inu){print "Not a valid file! try again:\n";
		} else {last;}
	}
	@txt = addInfoLtS("usearch",$inu,\@txt,1) if ($inu ne "");
	
} else {
	print "Found valid usearch bin at $uspath\n";
	print "\nLotuS is ready to run.\n\n";

}

print "Several Software packages have to be downloaded and this can take some time. Please be patient & grab a tea.\n\n";


if ($UID eq "??"){
	$UID=int(rand(99999999));
	@txt = addInfoLtS("UID",$UID,\@txt,0);
}

#-------BIG DB INSTALL
if ($refDBinstall[2] || $refDBinstall[8]){
	@txt = getSLV(\@txt);
}
if ($refDBinstall[1] || $refDBinstall [8]){
	@txt = getGG(\@txt);
}

if ($refDBinstall [3] || $refDBinstall [8]){
	@txt = getHITdb(\@txt);
}
if ($refDBinstall [4] || $refDBinstall [8]){
	@txt = getPR2db(\@txt);
}
if ($refDBinstall [5] || $refDBinstall [8]){
	@txt = getbeetax(\@txt);
}

if ($refDBinstall[0]){
	print "No Ref DB will be installed.\n";
}

if ($getUTAX){
	print "Downloading UTAX ref databases..\n";
	my $tarUTN = "$ddir/utax_16s.tar.gz";
	getS2("http://drive5.com/utax/data/utax_rdp_16s_tainset15.tar.gz",$tarUTN);
	system "tar -xzf $tarUTN -C $ddir;rm $tarUTN";
	$tarUTN="$ddir/utax_ITS.tar.gz";
	getS2("http://drive5.com/utax/data/utax_unite_v7.tar.gz",$tarUTN);
	system "tar -xzf $tarUTN -C $ddir;rm $tarUTN";
	@txt = addInfoLtS("TAX_REFDB_SSU_UTAX","$ddir/utaxref/rdp_16s_trainset15/",\@txt,2);
	@txt = addInfoLtS("TAX_REFDB_ITS_UTAX","$ddir/utaxref/unite_v7/",\@txt,2);
	#die "X\n";
	
}


if ($ITSready){
	#ITS DB
	my $tarUN = "$ddir/qITSfa.zip";
	getS2("http://psbweb05.psb.ugent.be/lotus/packs/DB/UNITE/sh_refs_qiime_ver8_99_s_all_02.02.2019.fasta.zip",$tarUN);
	#getS2("http://psbweb05.psb.ugent.be/lotus/packs/DB/sh_qiime_release_02.03.2015.zip",$tarUN);
	system("rm -r $ddir/UNITE;unzip -o $tarUN -d $ddir/UNITE/");
	@txt = addInfoLtS("TAX_REFDB_ITS_UNITE","$ddir/UNITE/sh_refs_qiime_ver8_99_s_all_02.02.2019.fasta",\@txt,1);
	getS2("http://psbweb05.psb.ugent.be/lotus/packs/DB/UNITE/sh_taxonomy_qiime_ver8_99_s_all_02.02.2019.txt.zip",$tarUN);
	system("unzip -o $tarUN -d $ddir/UNITE/;rm -rf $ddir/UNITE/__MACOSX/");
	@txt = addInfoLtS("TAX_RANK_ITS_UNITE","$ddir/UNITE/sh_taxonomy_qiime_ver8_99_s_all_02.02.2019.txt",\@txt,1);
	unlink($tarUN);
	

	#itsx
	print "Downloading ITSX to detect valid ITS regions..\n";
	my $tarUTN = "$bdir/ITSx_1.0.11.tar.gz";
	getS2("http://psbweb05.psb.ugent.be/lotus/packs/ITSx_1.0.11.tar.gz",$tarUTN);
	system "tar -xzf $tarUTN -C $bdir;rm $tarUTN";
	unlink($tarUTN);
	@txt = addInfoLtS("itsx","$bdir/ITSx_1.0.11/./ITSx",\@txt,1);
	@txt = addInfoLtS("hmmsearch","$bdir/ITSx_1.0.11/bin/./hmmscan",\@txt,1);

}
#die "@txt\n";
# phiX ref genome
my $phiXf = "$ddir/phiX.fasta";
getS2("http://psbweb05.psb.ugent.be/lotus/packs/DB/phiX.fasta",$phiXf);
@txt = addInfoLtS("REFDB_PHIX",$phiXf,\@txt,1);
#-------BIG DB INSTALL END

#-------------- install chimera check DBs
#db gold #exchanged for rdp_gold since 1.30
#my $goldDB = "http://drive5.com/uchime/gold.fa";
my $goldDB = "http://psbweb05.psb.ugent.be/lotus/packs/rdp_gold.fa.gz";
my $DB = "$ddir/rdp_gold.fa"; system "rm -f $DB";
#system("wget -O $DB $goldDB");
getS2($goldDB,$DB.".gz");
system("gunzip $DB.gz");
@txt = addInfoLtS("UCHIME_REFDB",$DB,\@txt,1);

#ITS chimera check ref DB
if ($ITSready){
	my $itsDB = "http://psbweb05.psb.ugent.be/lotus/packs/DB/uchime_reference_dataset_11.03.2015.zip";
	getS2($itsDB,"$ddir/uchITS.zip");
	system "rm -r $ddir/ITS_chimera/";
	if (system("unzip -o $ddir/uchITS.zip -d $ddir/ITS_chimera") != 0){ die "Failed to unzip $ddir/uchITS.zip";}
	unlink("$ddir/uchITS.zip");
	#die "$ddir/ITS_chimera/uchime_sh_refs_dynamic_original_985_11.03.2015.fasta";
	@txt = addInfoLtS("UCHIME_REFDB_ITS","$ddir/ITS_chimera/uchime_sh_refs_dynamic_original_985_11.03.2015.fasta",\@txt,1);
	@txt = addInfoLtS("UCHIME_REFDB_ITS1","$ddir/ITS_chimera/ITS1_ITS2_datasets/uchime_sh_refs_dynamic_develop_985_11.03.2015.ITS1.fasta",\@txt,1);
	@txt = addInfoLtS("UCHIME_REFDB_ITS2","$ddir/ITS_chimera/ITS1_ITS2_datasets/uchime_sh_refs_dynamic_develop_985_11.03.2015.ITS2.fasta",\@txt,1);
}


#db Silva 119 clustered to 93% for LSUs
my $LTUrefDB = "http://psbweb05.psb.ugent.be/lotus/packs/SILVA_119_LSU_93.ref.fasta.gz";
$DB = "$ddir/SLV_119_LSU.fa"; system "rm -f $DB";
getS2($LTUrefDB,$DB.".gz");
system("gunzip $DB.gz");
@txt = addInfoLtS("UCHIME_REFDB_LSU",$DB,\@txt,1);



#-----------  exit prog here, if set
#-----------------------
if ($onlyDbinstall){
	finishAI("d");
	print "\n\nInstalled databases\nExiting autoinstaller..\n";
	exit(0);
}

#only binary installs after this point
my $nsdmp = compile_sdm("$ldir/sdm_src");
@txt = addInfoLtS("sdm",$nsdmp,\@txt,1);
$nsdmp = compile_LCA("$ldir/LCA_src");
@txt = addInfoLtS("LCA",$nsdmp,\@txt,1);

$nsdmp = compile_rtk("rtk_src");
@txt = addInfoLtS("rtk",$nsdmp,\@txt,1);


#-------BLAST LAMBDA INSTALL
if ($installBlast == 1 || $installBlast == 3){
	#Blast
	print "Downloading blast executables...\n";
	my $blfil = "ncbi-blast-2.2.29+-x64-linux.tar.gz";
	if ($isMac){
		$blfil = "ncbi-blast-2.2.29+-universal-macosx.tar.gz";
	}

	$exe = "$bdir/blast.tar.gz";
	getS2("http://psbweb05.psb.ugent.be/lotus/packs/".$blfil,$exe);
		
	#my $path = "blast/executables/blast+/2.2.29/";
	#my $host = "ftp.ncbi.nlm.nih.gov";my $ftp = Net::FTP->new($host, Debug => 0, Passive => 1) or die "Can't open $host\n";
	#$ftp->login() or die "Cannot login ", $ftp->message;$ftp->cwd($path);$ftp->binary();$ftp->get($blfil,$exe) or die "Failed Blast download: ", $ftp->message;$ftp->quit;
	#sleep(5);
	system("tar -xzf $exe -C $bdir");
	unlink($exe);
	$exe = "$bdir/ncbi-blast-2.2.29+/bin/blastn";
	@txt = addInfoLtS("blastn",$exe,\@txt,1);
	$exe = "$bdir/ncbi-blast-2.2.29+/bin/makeblastdb";
	@txt = addInfoLtS("makeBlastDB",$exe,\@txt,1);
}
if ($installBlast == 2 || $installBlast == 3){
	print "Downloading lambda executables... \n";
	my $lmdD = "http://psbweb05.psb.ugent.be/lotus/packs/lambda/lambda-v0.9.1-linux_x86-64.tar.gz";
	if ($isMac){
		$lmdD = "http://psbweb05.psb.ugent.be/lotus/packs/lambda/lambda-v0.9.1-darwin_x86-64.tar.gz";
	}

	$exe = "$bdir/lambda.tar.gz";
	getS2($lmdD,$exe);
	system("tar -xzf $exe -C $bdir\nmv $bdir/bin $bdir/lambda");
	unlink($exe);
	$exe = "$bdir/lambda/lambda_indexer";
	@txt = addInfoLtS("lambda_index",$exe,\@txt,1);
	$exe = "$bdir/lambda/lambda";
	@txt = addInfoLtS("lambda",$exe,\@txt,1);
}
if ($installBlast == 0){
	print "\nNo similarity comparison program will be installed.\n";
}

#-------BLAST LAMBDA INSTALL END


#swarm
print "Downloading swarm executables..\n";
my $swarmdir = $bdir."swarm-master/";
my $sexe = "$swarmdir/bin/swarm";
my $tars = "$bdir/swarm.zip";
#
my $swarmtar = "http://psbweb05.psb.ugent.be/lotus/packs/swarm2.1.13.zip";#"https://github.com/torognes/swarm/archive/master.zip";#"http://psbweb05.psb.ugent.be/lotus/packs/swarm206d.tgz";
getS2($swarmtar,$tars);
system("unzip -o -d $bdir $tars");
unlink($tars);
my $callrets = system("make -C $swarmdir/src/");
#die($sexe."\n");

if (0 && $callrets != 0){
	print "\n\n=================\nProblem while compiling swarm.\n"; $finalWarning.="swarm did not compile. The -CL 2 option will not be available to LotuS unless you reinstall swarm manually (lotus.cfg).\n";
}
if (-e $sexe){ #not essential
	system("chmod +x $sexe");
	@txt = addInfoLtS("swarm",$sexe,\@txt,1);
} else {
	print "Swarm exe did not exist at $sexe\n Therefore swarm was not installed.\n";
}
#vsearch
print "Downloading vsearch executables..\n";
my $vexe = "$bdir/vsearch-2.0.4";
if ($isMac){
	getS2("http://psbweb05.psb.ugent.be/lotus/packs/vsearch/vsearch-2.0.4-osx-x86_64/bin/vsearch",$vexe);
} else {
	getS2("http://psbweb05.psb.ugent.be/lotus/packs/vsearch/vsearch-2.0.4-linux-x86_64/bin/vsearch",$vexe);
}
if (-e $vexe){ #not essential
	system("chmod +x $vexe");
	@txt = addInfoLtS("vsearch",$vexe,\@txt,1);
} else {
	print "vsearch exe did not exist at $vexe\n Therefore vsearch was not installed (fallback to usearch).\n";
}



#infernal
print "Downloading infernal executables..\n";
my $iexe = "$bdir/inf112.tar.gz";
if ($isMac){
	getS2("http://psbweb05.psb.ugent.be/lotus/packs/infernal/infernal-1.1.2-macosx-intel.tar.gz",$iexe);
} else {
	getS2("http://psbweb05.psb.ugent.be/lotus/packs/infernal/infernal-1.1.2-linux-intel-gcc.tar.gz",$iexe);
}
	system("tar -xzf $iexe -C $bdir");
	$iexe = "$bdir/infernal-1.1.2-linux-intel-gcc/binaries/";
if (-d $iexe){ #not essential
	@txt = addInfoLtS("infernal",$iexe,\@txt,2);
} else {
	print "infernal binary dir did not exist at $iexe\n Therefore infernal was not installed (fallback to de novo clustal omega).\n";
}
system "rm -f $iexe" if (-e $iexe);


#die "$vexe\n";
#dnaclust
print "Downloading dnaclust executables..\n";
my $dtar = "$bdir/dnaclust.zip";
my $dexe = "$bdir/dnaclust_linux_release3/dnaclust";
if ($isMac){
	getS2("http://psbweb05.psb.ugent.be/lotus/packs/dnaclust/dnaclust_OSX_release3.zip",$dtar);
	$dexe = "$bdir/dnaclust_OSX_release3/dnaclust";
} else {
	getS2("http://psbweb05.psb.ugent.be/lotus/packs/dnaclust/dnaclust_linux_release3.zip",$dtar);
}
system("unzip -o -q $dtar -d $bdir");
unlink($dtar);

if (-e $dexe){ #not essential
	system("chmod +x $dexe;chmod +x $dexe-ref");
	@txt = addInfoLtS("dnaclust",$dexe,\@txt,1);
} else {
	print "dnaclust exe did not exist at $dexe\n Therefore dnaclust was not installed (please use other clustering algorithm or manually install).\n";
}

#dnaclust
#http://psbweb05.psb.ugent.be/lotus/packs/dnaclust_linux_release3.zip
#http://psbweb05.psb.ugent.be/lotus/packs/dnaclust_OSX_release3.zip
# dnaclust
#system("chmod +x $exe\nchmod +x $exe-ref\n");
#@txt = addInfoLtS("dnaclust",$exe,\@txt,1);


#fasttree
print "Downloading FastTree executables..\n";
$exe = "$bdir/FastTreeMP";
my $exe1 = "$bdir/FastTree.c";
#system("wget -O $exe $fastt");
#my $fastt = "http://www.microbesonline.org/fasttree/FastTreeMP";
#if ($isMac){}
my $fastt = "http://psbweb05.psb.ugent.be/lotus/packs/FastTree.c"; #http://www.microbesonline.org/fasttree/
getS2($fastt,$exe1);
$callret = system("gcc -DOPENMP -fopenmp -O3 -finline-functions -funroll-loops -Wall -o $exe $exe1 -lm");
if ($callret != 0){
	print "\n\n=================\nProblem while compiling fasttree, trying fasttree without multithread and SSE support (might be slower, but if it's working..)\n";
	$finalWarning .= "fasttree compiled without multithreading support (you can not use the -thr LotuS option.\n";
	$exe = "$bdir/FastTree";
	$callret = system("gcc -DNO_SSE -O3 -finline-functions -funroll-loops -Wall -o $exe $exe1 -lm");}
if ($callret != 0){print "\n\n=================\nfasttree compilation failed. This is most likely an issue with your gcc version or the openMP libraries. See info on:\nhttp://www.microbesonline.org/fasttree/#Install\n"; exit(4);}

system("chmod +x $exe");
@txt = addInfoLtS("fasttree",$exe,\@txt,1);


#flash
my $flashdir = $bdir."FLASH-1.2.10";
my $fexe = "$flashdir/flash";
my $tar = "$bdir/Flash.tar.gz";
my $flashTar = "http://psbweb05.psb.ugent.be/lotus/packs/FLASH-1.2.10.tar.gz";#"http://sourceforge.net/projects/flashpage/files/FLASH-1.2.10.tar.gz/download";
getS2($flashTar,$tar);
system("tar -xzf $tar -C $bdir");
unlink($tar);
$callret = system("make -C $flashdir");
if ($callret != 0){
	print "\n\n=================\nProblem while compiling FLASH.\n"; $finalWarning.="Flash did not compile. This means you can not use paired reads with LotuS.\n";
}
system("chmod +x $fexe");
@txt = addInfoLtS("flashBin",$fexe,\@txt,1);



#cd-hit
my $cdhitdir = $bdir."cdhit-master/";
my $cexe = "$cdhitdir/cd-hit-est";
$tar = "$bdir/cdhit.zip";
#my $cdhitTar = "https://cdhit.googlecode.com/files/cd-hit-v4.6.1-2012-08-27.tgz";
my $cdhitTar = "http://psbweb05.psb.ugent.be/lotus/packs/cd-hit_git.zip";#"https://github.com/weizhongli/cdhit/archive/master.zip";
getS2($cdhitTar,$tar);
#system("tar -xzf $tar -C $bdir");
system("unzip -o -q $tar -d $bdir");
unlink($tar);
$callret = system("make -C $cdhitdir");
if ($callret != 0){
	print "\n\n=================\nProblem while compiling CD-HIT.\n"; $finalWarning.="CD-HIT did not compile. The -UP 3 option will not be available to LotuS unless you reinstall cd-hit-est manually (lotus.cfg). \n";
} else {
	system("chmod +x $cexe");
	@txt = addInfoLtS("cd-hit",$cexe,\@txt,1);
}


my $rdpf = "http://psbweb05.psb.ugent.be/lotus/packs/rdp_classifier_2.12.zip"; #"http://downloads.sourceforge.net/project/rdp-classifier/rdp-classifier/rdp_classifier_2.6.zip?r=http%3A%2F%2Fsourceforge.net%2Fprojects%2Frdp-classifier%2F&ts=1391590725&use_mirror=netcologne";
#RDP classifier
$exe = "$bdir/rdp.zip";
#system("wget -O $exe $rdpf");
getS2($rdpf,$exe);
#die("unzip $exe -d $bdir");
system("unzip -o -q $exe -d $bdir");
unlink($exe);
$exe = $bdir."rdp_classifier_2.12/dist/classifier.jar";
@txt = addInfoLtS("RDPjar",$exe,\@txt,1);



#clustalO
my $clo = "http://psbweb05.psb.ugent.be/lotus/packs/clustalo-1.2.0-Ubuntu-x86_64";#"http://www.clustal.org/omega/clustalo-1.2.0-Ubuntu-x86_64";
if ($isMac){
	$clo = "http://www.clustal.org/omega/clustal-omega-1.2.0-macosx";
}
$exe = "$bdir/clustalo-1.2.0-Ubuntu-x86_64";
#system("wget -O $exe $clo");
getS2($clo,$exe);
system("chmod +x $exe");
@txt = addInfoLtS("clustalo",$exe,\@txt,1);


print "\n\nInstallation script finished. Please read the readme on the software used in this pipeline. Excecute autoinstall.pl again, to upgrade LotuS to a newer version (if available).\n";

finishAI("");



#After install on your system, open\n   ".$ldir."lOTUs.cfg\nand search for the entry \"usearch {XX}\".\nReplace {XX} with the absolute path to your usearch install, e.g. /User/Thomas/bin/usearch/usearch7.0.1001_i86linux32\n LotuS is ready to run.\n";

sub finishAI($){
	my ($vTag) = @_;
	#write new cfg file
	open O,">","$ldir/lOTUs.cfg" or die $!;
	foreach (@txt){	print O $_;}
	close O;
	return if ($vTag eq "none");
	if ($LWPsimple){
		my $external_php = get("http://psbweb05.psb.ugent.be/lotus/in.php?ID=$UID&VERSION=$vTag$lver&SDMV=$sver") || print "";
	}
	if ($finalWarning ne ""){
		print "################################\nWarnings occured during LotuS installation:\n".$finalWarning."\n################################\n";
	}
}
sub getInstallVer($){
	my ($sdmsrc) = @_;
	my $lver=0.1;
	open Q,"<","$ldir/lotus.pl" or die("Can't find LotuS main script file (lotus.pl)\n");
	while(<Q>){if (m/my.*selfID\s*=\s*\"LotuS\s(.*)\".*/){$lver=$1;last;}}
	close Q;
	my $sver=0.1;
	if ($sdmsrc ne ""){
	my $sdmF = "$sdmsrc/IO.h";
	open Q,"<",$sdmF or die("Can't open sdm file $sdmF\n");
	#static const float sdm_version = 0.71f;
	while(<Q>){if (m/static\s+const\s+float\s+sdm_version\s*=\s*(.*)f;/){$sver=$1;last;}}
	close Q;
	}
	return ($lver,$sver);
}

sub addInfoLtS($ $ $ $){
	my ($cmd,$ex,$aref,$reqF) = @_;
	print "Installing $cmd:\n$ex\n";
	if ($reqF ==1 && ! -f $ex){print "Can't find required file $ex\nPlease check if the package was correctly downloaded.\nAborting..\n"; exit(5);}
	if ($reqF ==2 && ! -d $ex){print "Can't find required directory $ex\nPlease check if the package was correctly downloaded.\nAborting..\n"; exit(5);}
	my @txt = @{$aref};
	my $ss = quotemeta $cmd;
	my $i=0; my $tagset=0;
	while ($txt[$i] !~ m/^$ss\s/){
		#print $txt[$i]."\n";
		$i++;
		if ($i >= @txt){
			#die ("Could not find the entry \"$cmd\" in lotus configuration file. Aborting Installer..\n")
			print "Could not find the entry \"$cmd\" in lotus configuration file. Inserting anew..\n";
			push(@txt,""); last;
		}
	}
	$txt[$i] = $cmd." ".$ex."\n";
	$i++;
	while ($i<@txt){ if ($txt[$i] =~ m/^$ss\s/){splice(@txt,$i,1) ; $i--;} $i++; last if ($i>=@txt); }
	print "done.\n";
	#DEBUG
	#print $txt[$i]."\n";
	return @txt;
}
sub getInfoLtS($ $){
	my ($cmd,$aref) = @_;
	my @txt = @{$aref};
	my $ss = quotemeta $cmd;
	my $i=0;
	while ($txt[$i] !~ m/^$ss/){
#		print $txt[$i]."\n";
		$i++;
		die ("Could not find the entry \"$cmd\" in lotus configuration file. Aborting Installer..\n") if ($i > @txt)
	}
	chomp $txt[$i];
	if ($txt[$i] =~ m/^$ss\s(.*)/){
		return $1;
	} else {
		return "??";
	}
}
sub parse_hitdb($ $){
	my ($Dpre,$Dn) = @_;
	my @tdesign = (" k__"," p__"," c__"," o__"," f__"," g__"," s__");
	open I,"<$Dpre"; open O,">$Dn";
	while (my $l = <I>){
		chomp $l;
		my @spl = split /\t/,$l;
		#print $spl[1]."\n";
		my @spl2 = split /;/,$spl[1];
		my $nline = "";
		if ($spl2[0] =~ m/Euryarchaeota|Crenarchaeota/){
			$nline = $spl[0]."\tk__Archaea;";
		} else {
			$nline = $spl[0]."\tk__Bacteria;";
		}
		for (my $i=1;$i<@tdesign;$i++){
			
			if (@spl2 >= $i && $spl2[$i-1] ne ""){ 
				my $tag = $spl2[$i-1]; chomp $tag;
				$nline .= $tdesign[$i].$tag;
			} else {
				$nline .= $tdesign[$i]."?";
			}
			$nline .=";" unless ($i == (@tdesign-1));
		}
		print O $nline."\n";
	}
	close I; close O;
}

sub parse_PR2($ $){
	my ($DBin, $tout) = @_;
	open T,">$tout" or die "Can;t open PR2 taxout $tout\n";
	open I,"<$DBin" or die "Can;t open PR2 fasta $DBin\n";
	open F,">$DBin.tmp" or die "Can;t open PR2 fasta tmp $DBin.tmp\n";
	while (my $l = <I>){
		chomp $l;
		if ($l =~ m/^>/){
			 my @spl = split /\|/,$l;
			$spl[0] =~ s/^>//;
			print F ">".$spl[0]."\n";
			print T $spl[0]."\tk__".$spl[1].";p__".$spl[2].";c__".$spl[4].";o__".$spl[5].";f__".$spl[6].";g__".$spl[7].";s__".$spl[8]."\n";
		} else {
			$l =~ s/U/T/g;
			$l =~ s/u/t/g;
			$l =~ s/[^ACTGactg]/N/g;
			print F $l."\n";
		}
	}
	close T; close I; close F;
	system "rm $DBin; mv $DBin.tmp $DBin";
}

sub getbeetax($){
	my ($aref) = @_;
	my @txt = @{$aref};
	print "Downloading bee specific database and taxonomy.\n";
	system "rm -rf $ddir/beeTax/;mkdir -p $ddir/beeTax/";
	my $DB = "$ddir/beeTax/beeTax.fna"; my $DBtax = "$ddir/beeTax/beeTax.txt";
	#getS2("http://5.196.17.195/pr2/download/representative_sequence_of_each_cluster/gb203_pr2_all_10_28_99p.fasta.tar.gz",$DB.".tar.gz");
	getS2("http://psbweb05.psb.ugent.be/lotus/packs/DB/beeTax_Engel/beEngel.fna",$DB);
	getS2("http://psbweb05.psb.ugent.be/lotus/packs/DB/beeTax_Engel/beEngel.txt",$DBtax);
	#parse_PR2($DB,$DBtax); #unlink ($DBtax.".pre");
	@txt = addInfoLtS("TAX_REFDB_BEE",$DB,\@txt,1);
	@txt = addInfoLtS("TAX_RANK_BEE",$DBtax,\@txt,1);
	return (@txt);
}

sub getPR2db($){
	my ($aref) = @_;
	my @txt = @{$aref};
	print "Downloading PR2 99% clustered database.\n";
	system "rm -rf $ddir/PR2/;mkdir -p $ddir/PR2/";
	my $DB = "$ddir/PR2/PR2_pack"; my $DBtax = "$ddir/PR2/PR2_taxonomy.txt";
	#getS2("http://5.196.17.195/pr2/download/representative_sequence_of_each_cluster/gb203_pr2_all_10_28_99p.fasta.tar.gz",$DB.".tar.gz");
	getS2("http://psbweb05.psb.ugent.be/lotus/packs/DB/gb203PR2.tar.gz",$DB.".tar.gz");
	
	system "tar -xzf $DB.tar.gz -C $ddir/PR2;rm $DB.tar.gz";
	$DB = "$ddir/PR2/gb203_pr2_all_10_28_99p.fasta";
	#parse_PR2($DB,$DBtax); #unlink ($DBtax.".pre");
	@txt = addInfoLtS("TAX_REFDB_PR2",$DB,\@txt,1);
	@txt = addInfoLtS("TAX_RANK_PR2",$DBtax,\@txt,1);
	return (@txt);
}
sub getHITdb($){
	my ($aref) = @_;
	my @txt = @{$aref};
	print "Downloading HITdb April 2015 release..\n";
	system "rm -rf $ddir/HITdb/; mkdir -p $ddir/HITdb/";
	my $DB = "$ddir/HITdb/HITdb_sequences.fna"; my $DBtax = "$ddir/HITdb/HITdb_taxonomy.txt";
	getS2("http://psbweb05.psb.ugent.be/lotus/packs/hitdb/HITdb_sequences.fna",$DB);
	getS2("http://psbweb05.psb.ugent.be/lotus/packs/hitdb/HITdb_taxonomy_qiime.txt",$DBtax.".pre");
	parse_hitdb($DBtax.".pre",$DBtax); unlink ($DBtax.".pre");
	@txt = addInfoLtS("TAX_REFDB_HITdb",$DB,\@txt,1);
	@txt = addInfoLtS("TAX_RANK_HITdb",$DBtax,\@txt,1);
	return (@txt);
}
sub getGG($){
	my ($aref) = @_;
	my @txt = @{$aref};
	#greengenes ------------------------
	my $gg1 = "http://psbweb05.psb.ugent.be/lotus/packs/gg_13_5.fasta.gz";
	my $gg2 = "http://psbweb05.psb.ugent.be/lotus/packs/gg_13_5_taxonomy.gz";
	my $DB = "$ddir/gg_13_5.fasta";
	system "rm -f $DB"."*";
	#system("wget -O $DB.gz $gg1");
	print "Downloading Greengenes may 2013 release..\n";
	getS2($gg1,"$DB.gz");
	sleep(10);
	system("gunzip -c $DB.gz > $DB");
	unlink("$DB.gz");
	@txt = addInfoLtS("TAX_REFDB_GG",$DB,\@txt,1);
	$DB = "$ddir/gg_13_5_taxonomy";
	#system("wget -O $DB.gz $gg2");
	getS2($gg2,"$DB.gz");
	sleep(3);
	system("gunzip -c $DB.gz > $DB");
	unlink("$DB.gz");
	@txt = addInfoLtS("TAX_RANK_GG",$DB,\@txt,1);
	return @txt;
}
sub getSLV($){
	my ($aref) = @_;
	my @txt = @{$aref};
	my $locSLBdl = 0;
	#SILVA -----------------------------------
	#TAX_REFDB_SLV  TAX_REFDB_SLV
	#changed to ver 119
	#changed to 123
	#changed to 128
	#changed to 132
#	my $baseSP = "http://www.arb-silva.de/fileadmin/silva_databases/release_123_1/Exports";
	my $SLVver = "138";
	#my $baseSP = "http://www.arb-silva.de/fileadmin/silva_databases/release_$SLVver/Exports";
	my $baseSP = "https://ftp.arb-silva.de/release_$SLVver/Exports";
#	my $baseSN = "SILVA_123.1";my $baseLN = "SLV_123.1";	my $SLVver = "123.1";
	my $baseSN = "SILVA_$SLVver";	my $baseLN = "SLV_$SLVver";	
	
	my $DB2 = "$ddir/$baseLN"."_SSU.tax";
	$DB = "$ddir/$baseLN"."_SSU.fasta";
	system "rm -f $DB"."*";
	print "Downloading SILVA SSU release $SLVver..\n";
	if ($locSLBdl){ #in case silva server doesn't work again..
		my $SlvAltFna = "http://psbweb05.psb.ugent.be/lotus/packs/DB/SLV/SLV_132_SSU.fasta.gz";
		getS2($SlvAltFna,"$DB.gz");
		system("gunzip -c $DB.gz > $DB;rm -f $DB.gz"); 
		my $SlvAltTax = "http://psbweb05.psb.ugent.be/lotus/packs/DB/SLV/SLV_132_SSU.tax.gz";
		getS2($SlvAltTax,"$DB2.gz");
		system("gunzip -c $DB2.gz > $DB2;rm -f $DB2.gz"); 
	} else {
		my $SLV = $baseSP."/".$baseSN."_SSURef_NR99_tax_silva.fasta.gz";
		getS2($SLV,"$DB.gz");
		#print "$SLV\n";
		system("gunzip -c $DB.gz > $ddir/SSUsilva.fasta;rm -f $DB.gz"); 
		getS2($baseSP."/taxonomy/tax_slv_ssu_$SLVver.txt.gz","$ddir/SLVtaxSSU.csv.gz");
		#print "$baseSP/taxonomy/tax_slv_ssu_$SLVver.txt.gz\n";
		system("gunzip -c $ddir/SLVtaxSSU.csv.gz > $ddir/SLVtaxSSU.csv;rm -f $ddir/SLVtaxSSU.csv.gz"); 
		prepareSILVA("$ddir/SSUsilva.fasta",$DB,$DB2,"$ddir/SLVtaxSSU.csv","");
		unlink("$ddir/SSUsilva.fasta");
	}
	
	@txt = addInfoLtS("TAX_REFDB_SSU_SLV",$DB,\@txt,1);
	@txt = addInfoLtS("TAX_RANK_SSU_SLV",$DB2,\@txt,1);
#------------------------------ LSU SLV DB --------------------------
	$DB = "$ddir/$baseLN"."_LSU.fasta";
	$DB2 = "$ddir/$baseLN"."_LSU.tax";
	print "Downloading SILVA LSU release $SLVver..\n";
	system "rm -f $DB"."*";
	$locSLBdl=1; $SLVver="132";#change this to local (132 release), since SIVLA doesn't have that yet..
	if ($locSLBdl){ #in case silva server doesn't work again..
		my $SlvAltFna = "http://psbweb05.psb.ugent.be/lotus/packs/DB/SLV/SLV_132_LSU.fasta.gz";
		getS2($SlvAltFna,"$DB.gz");
		system("gunzip -c $DB.gz > $DB;rm -f $DB.gz"); 
		my $SlvAltTax = "http://psbweb05.psb.ugent.be/lotus/packs/DB/SLV/SLV_132_LSU.tax.gz";
		getS2($SlvAltTax,"$DB2.gz");
		system("gunzip -c $DB2.gz > $DB2;rm -f $DB2.gz"); 
	} else {
		my $SLV = $baseSP."/".$baseSN."_LSURef_tax_silva.fasta.gz";
		getS2($SLV,"$DB.gz");
		getS2($baseSP."/taxonomy/tax_slv_lsu_$SLVver.txt.gz","$ddir/SLVtaxLSU.csv");
		system("gunzip -c $DB.gz > $ddir/LSUSILVA.fasta;rm -f $DB.gz"); #unlink("$DB.tgz");
		prepareSILVA("$ddir/LSUSILVA.fasta",$DB,$DB2,"$ddir/SLVtaxLSU.csv","$ddir/SLVtaxSSU.csv");
		unlink("$ddir/LSUSILVA.fasta"); unlink("$ddir/SLVtaxLSU.csv");unlink("$ddir/SLVtaxSSU.csv");
	}
	@txt = addInfoLtS("TAX_REFDB_LSU_SLV",$DB,\@txt,1);
	@txt = addInfoLtS("TAX_RANK_LSU_SLV",$DB2,\@txt,1);

	$finalWarning .= "\nWARNING: Silva $SLVver does not have consistent taxonomy levels for LSU's, therefore the taxonomy used in LotuS will contain \"?\" after taxonomy name.\n";

	return @txt;
}

sub prepareSILVA($ $ $ $){
#taxf3 is for 18S/28S #taxf3 is for SSU/LSU
my ($path, $SeqF,$taxF,$taxGuide,$taxGuide2) = @_;
print("Rewriting SILVA DB..\n");
my %taxG;


open I,"<",$taxGuide or die "Can't find taxguide file $taxGuide\n";
while (my $line = <I>){
	chomp($line); my @splg = split("\t",$line);
	my $newN =  $splg[0]; #lc
	$taxG{$newN} =  $splg[2];
} 
close I;

if ($taxGuide2 ne ""){
open I,"<",$taxGuide2 or die "Can't find taxguide file $taxGuide2\n";
while (my $line = <I>){
	chomp($line); my @splg = split("\t",$line);
	my $newN =  $splg[0]; #lc
	$taxG{$newN} =  $splg[2];
} 
close I;
}

open I,"<",$path or die ("could not find SILVA file \n$path\n");
open OT,">",$taxF;
open OS,">",$SeqF;
#open OT2,">",$taxF2;open OS2,">",$SeqF2;
my @tdesign = (" k__"," p__"," c__"," o__"," f__"," g__"," s__");
my $skip = 0;
my $eukMode = 0;
my $replacementTax =0; my $allTax=0;
while (my $line = <I>){
	chomp($line);
	if ($line =~ m/^>/){#header
		$skip=0;$eukMode = 0;
		my @spl = split("\\.",$line);
		if (1){
			; #do nothing
		}elsif ($spl[0] =~ m/>AB201750/){
			$line = ">AB201750.1.1495 Bacteria;Firmicutes;Clostridia;Clostridiales;Clostridiaceae 2;Anaerovirgula;Anaerovirgula multivorans";
			@spl = split("\\.",$line);
		} elsif ($spl[0] =~ m/>DQ643978/){
			$line = ">DQ643978.1.1627 Bacteria;Firmicutes;Clostridia;Clostridiales;Clostridiaceae 4;Geosporobacter;Geosporobacter subterraneus";
			@spl = split("\\.",$line);
		}elsif ($spl[0] =~ m/>X99238/){
			$line = ">X99238.1.1404 Bacteria;Firmicutes;Clostridia;Clostridiales;Clostridiaceae 1;Thermobrachium;Thermobrachium celere";
			@spl = split("\\.",$line);
		} elsif ($spl[0] =~ m/>FJ481102/){
			$line = ">FJ481102.1.1423 Bacteria;Firmicutes;Clostridia;Clostridiales;Clostridiaceae 1;Fervidicella;Fervidicella metallireducens AeB";
			@spl = split("\\.",$line);
		} elsif ($spl[0] =~ m/>EU443727/){
			$line = ">EU443727.1.1627 Bacteria;Firmicutes;Clostridia;Clostridiales;Clostridiaceae 4;Thermotalea;Thermotalea metallivorans";
			@spl = split("\\.",$line);
		}elsif ($spl[0] =~ m/>FR690973/){
			$line = ">FR690973.1.2373 Bacteria;Proteobacteria;Gammaproteobacteria;Thiotrichales;Thiotrichaceae;Candidatus Thiopilula;Candidatus Thiopilula aggregata";
			@spl = split("\\.",$line);
		}elsif ($spl[0] =~ m/>CP002161/){
			$line = ">CP002161.5310.6845 Bacteria;Proteobacteria;Gammaproteobacteria;Enterobacteriales;Enterobacteriaceae;Candidatus Zinderia;Candidatus Zinderia insecticola CARI";
			@spl = split("\\.",$line);
		} elsif ($spl[0] =~ m/>FR690975/){
			$line = ">FR690975.1.2297 Bacteria;Proteobacteria;Gammaproteobacteria;Thiotrichales;Thiotrichaceae;Candidatus Thiopilula;Candidatus Thiopilula aggregata";
			@spl = split("\\.",$line);
		}elsif ($spl[0] =~ m/>FR690991/){
			$line = ">FR690991.1.2147 Bacteria;Proteobacteria;Gammaproteobacteria;Thiotrichales;Thiotrichaceae;Candidatus Thiopilula;Candidatus Marithioploca araucae";
			@spl = split("\\.",$line);
		}elsif ($spl[0] =~ m/>FR690991/){
			$line = ">AB910318.1.1553 Bacteria;Firmicutes;Clostridia;Clostridiales;Clostridiaceae 4;Thermotalea;uncultured bacterium";
			@spl = split("\\.",$line);
		}elsif ($spl[0] =~ m/>AB910318/){
			$line = ">AB910318.1.1553 Bacteria;Firmicutes;Clostridia;Clostridiales;Clostridiaceae 4;Thermotalea;uncultured bacterium";
			@spl = split("\\.",$line);
		}elsif ($spl[0] =~ m/>AY796047/){
			$line = ">AY796047.1.1592 Bacteria;Firmicutes;Clostridia;Clostridiales;Clostridiaceae 4;Thermotalea;uncultured bacterium";
			@spl = split("\\.",$line);
		}

		
		my $ID = $spl[0];
		$ID = substr($ID,1);
		$line =~ m/[^\s]+\s(.*)$/;
		my $tax = $1; chomp $tax;
		if ($tax =~ m/^\s*Eukaryota/){$eukMode = 1;}#$skip = 1; next;}
		
		print OS ">".$ID."\n";
		@spl = split(";",$tax);
		for (my $i=0;$i<@spl;$i++){
			$spl[$i] =~ s/^\s*//; $spl[$i] =~ s/\s*$//;
		}
		#die "@spl\n";
		my $tline;
		if (!$eukMode){
			if (@spl > 7 ){
				print $line."\n";
				print("too many categories\n");
			}
			for (my $i=0;$i<7; $i++){
				if ($i < scalar(@spl)){
					if ($spl[$i] =~ m/^unidentified/){$spl[$i] = "?";}
					$spl[$i] = $tdesign[$i].$spl[$i];
				} else {
					$spl[$i] = $tdesign[$i];
				}
			}
			$tline = $ID ."\t".join(";",@spl);
		} else {#parse the levels out from taxguide
			my $tmpTax = "";
			my @jnd;
			my @soughtCls = ("domain","phylum","class","order","family","genus","species");
			my $soughtLvl = 0;  my $lastUsed = 0;
			for (my $i=0;$i<@spl; $i++){
				my $scanTax = $tmpTax.$spl[$i].";";
				if (exists($taxG{$scanTax}) || $soughtLvl == 6 || $spl[$i] =~ m/^unidentified/){
					#print "$taxG{$scanTax} LL\n";
					#SILVA has no species level in tax guide file
					$lastUsed = $soughtLvl;
					if ($soughtLvl == 6){
						push(@jnd,$tdesign[$soughtLvl].$spl[$i]);
						$soughtLvl++;
						last;
					} elsif ($spl[$i] =~ m/^unidentified/ || $taxG{$scanTax} eq ""){#Euk in LSU file have no annotation..
						$spl[$i] = "";
						push(@jnd,$tdesign[$soughtLvl]."?");
						$soughtLvl++;
					} elsif ($taxG{$scanTax} eq $soughtCls[$soughtLvl]){
						push(@jnd,$tdesign[$soughtLvl].$spl[$i]);
						#print $tdesign[$soughtLvl].$spl[$i]."\n";
						$soughtLvl++;
					} elsif ($taxG{$scanTax} eq $soughtCls[$soughtLvl+1]){#fill in empty levels
						push(@jnd,$tdesign[$soughtLvl]);
						$soughtLvl++;
						push(@jnd,$tdesign[$soughtLvl].$spl[$i]);
						#print "Skipped to level ".$tdesign[$soughtLvl].$spl[$i]."\n";
						$soughtLvl++;
					}
					
				} else { #more likely to be low level species
					my $arS = @spl;
					#species signatuer & last entry
					if ($spl[$i] =~ m/\S+\s\S+/ && $arS >= ($i)){
						my $ncnt=1;
						while ($soughtLvl<6){
							my $nIdx = $lastUsed+ $ncnt;
							if ($nIdx < ($arS-1) ){
								#just impute preceding levels
								push(@jnd,$tdesign[$soughtLvl]."?".$spl[ $nIdx ]);
							} else {
								push(@jnd,$tdesign[$soughtLvl]."?");
							}
							$soughtLvl++;$ncnt++;
						}
						$soughtLvl = 6;
						#almost certainly a species
						push(@jnd,$tdesign[$soughtLvl].$spl[$i]); 
						$soughtLvl++;
						$replacementTax++;
						#print $ID."\t".join(";",@jnd)."\n$lastUsed\n";
						last;
					
					} else {
						#print $scanTax." JJ\n";
					}
				}
				 #Eukaryota;Fungi;Ascomycota;Archaeorhizomycetes;Archaeorhizomycetales;Archaeorhizomycetales_incertae_sedis
				$tmpTax .= $spl[$i].";";
				$lastUsed = $i;
			}
			$allTax++;
			for (;$soughtLvl<7;$soughtLvl++){
				push(@jnd,$tdesign[$soughtLvl]);
			}
			$tline = $ID."\t".join(";",@jnd);
			#die $tax." CC " .$tline."\n";
		}
		print OT $tline."\n";
		#die($tline);
	} elsif ($skip == 0){ #work through sequence
		$line =~ s/\s//g;
		$line =~ s/U/T/g;
		$line =~ s/u/t/g;
		#die $line;
		print OS $line."\n";
	}
}
#print "$replacementTax out of $allTax could not be defined to clear taxonomic levels and were imputed (with mostly empty tax levels or a \"?\" before tax name\n";

close I; close OT; close OS; #close OT2; close OS2;
}


sub getS2($ $){
	my ($in,$out) = @_;
	#print "getS2:$in\n$out\n";
	#print $in."\n";
	if ($WGETpres){
		print "wget\n";
		system("wget -O $out $in");
	} elsif (!$isMac && $LWPsimple){
		print "LWP\n";
		getstore($in,$out);
	} elsif ($FILEfetch){
		print "FETCH\n";
		my $ff = File::Fetch->new( uri => $in);
		my $file = $ff->fetch() or print "Can't download file $in with File::Fetch\n".$ff->error()."\n";
		move($file, $out);
	} else {
		die "no suitable library / program on you system. Please ensure that \"wget\" is installed\n";
	}
}

sub checkLtsVer($){
	my ($lver) = @_;
	my $updtmpf = get("http://psbweb05.psb.ugent.be/lotus/lotus/updates/Msg.txt");
	my $msg = ""; my $hadMsg=0;
	open( TF, '<', \$updtmpf ); while(<TF>){$msg .= $_;}  close(TF); 
	foreach my $lin (split(/\n/,$msg)){
		my @spl = split /\t/,$lin;
		next if (@spl==0);
		if ($lver<$spl[0]){print $spl[1]."\n\n"};
		$hadMsg=1;
	}
	# compare to server version
	die "LWP:simple package not installed, but required for updater!" if (!$LWPsimple);
	$updtmpf = get("http://psbweb05.psb.ugent.be/lotus/lotus/updates/curVer.txt");
	open( TF, '<', \$updtmpf ); my $lsv = <TF>; close(TF); chomp $lsv;
	my $msgEnd = "";
	$updtmpf = get("http://psbweb05.psb.ugent.be/lotus/lotus/updates/curVerMsg.txt");
	open( TF, '<', \$updtmpf ); while(<TF>){$msgEnd .= $_;} close(TF); 
	
	$updtmpf = get("http://psbweb05.psb.ugent.be/lotus/lotus/updates/UpdateHist.txt");
	my $updates = "";
	open( TF, '<', \$updtmpf );$msg = ""; while(<TF>){$msg .= $_;}  close(TF); 
	foreach my $lin (split(/\n/,$msg)){
		my @spl = split /\t/,$lin; chomp $lin;
		next if (@spl < 2 || $spl[0] eq "");
		if ($spl[1] =~ m/LotuS (\d?\.\d+)/){
			if ($lver<$1){$updates.= $spl[0]."\t".$spl[1]."\n"};
		}
	}
	if ($updates ne ""){
		print "--------------------------------\nThe following updates are available:\n--------------------------------\n";
		print $updates;
		print "\n\nCurrent Lotus version is :$lver\nLatest version is: $lsv\n";
	}
	
	if ($hadMsg || $updates ne ""){sleep(4);}

	
	#die;
	return $lsv,$msgEnd;
}

sub compile_LCA($){
	my ($ldi2) = @_;
	if (-d $ldi2 && -f "$ldi2/Makefile" ){
		print "Compiling LCA..\n";
		system("rm -f $ldi2/*.o");
		my $stat = system("make -C $ldi2");
		if ($stat == 0){
			system("rm -f $ldir/LCA $bdir/LCA; mv $ldi2/LCA $bdir/LCA; chmod +x $bdir/LCA");
		} elsif ($isMac && $stat){
			print "\n\n=================\nCompilation of LCA failed.\n It seems this is a Mac system and no native LCA compile is available, please try installing C++0x clang or gcc support for your system first, otherwise contact falk.hildebrand\@gmail.com .\n";
			print "Press any key to continue installation\n";
			$finalWarning .= "LCA was not compiled (this needs to be compiled to run lotus, rerun autoinstall, after your system has a C++0x compliant C++ compiler like clang , gcc installed).\n";
			<STDIN>;
		} else {
			print "\n\n=================\nCompilation of LCA failed (please contact falk.hildebrand\@gmail.com).\n A general prupose LCA binary is being used, but this is not recommended\n";
			print "Press any key to continue installation\n";
			$finalWarning .= "Non-native LCA compilation";
			<STDIN>;
		}
	}
	system("chmod +x $bdir/LCA");
	return "$bdir/LCA";
}
sub compile_rtk($){
	my ($ldi2) = @_;
	if (-d $ldi2 && -f "$ldi2/Makefile" ){
		print "Compiling rtk..\n";
		system("rm -f $ldi2/*.o");
		my $stat = system("make -C $ldi2");
		if ($stat == 0){
			system("rm -f $ldir/rtk $bdir/rtk; mv $ldi2/rtk $bdir/rtk; chmod +x $bdir/rtk");
		} elsif ($isMac && $stat){
			print "\n\n=================\nCompilation of trk failed.\n It seems this is a Mac system and no native rtk compile is available, please try installing C++0x clang or gcc support for your system first, otherwise contact falk.hildebrand\@gmail.com .\n";
			print "Press any key to continue installation\n";
			$finalWarning .= "rtk was not compiled (this needs to be compiled to run lotus, rerun autoinstall, after your system has a C++0x compliant C++ compiler like clang , gcc installed).\n";
			<STDIN>;
		} else {
			print "\n\n=================\nCompilation of rtk failed (please contact falk.hildebrand\@gmail.com).\n A general prupose rtk binary is being used, but this is not recommended\n";
			print "Press any key to continue installation\n";
			$finalWarning .= "Non-native rtk compilation";
			<STDIN>;
		}
	}
	system("chmod +x $bdir/rtk");
	return "$bdir/rtk";
}

sub compile_sdm($){
	my ($ldi2) = @_;
	if (-d $ldi2 && -f "$ldi2/Makefile" && -f "$ldi2/DNAconsts.cpp"){
		print "Compiling sdm..\n";
		system("rm -f $ldi2/*.o");
		my $stat = system("make -C $ldi2");
		if ($stat != 0){#repeat without gzip
			print "\n\n\n\n=================\nProblem compiling sdm with gzip support\nFallback to sdm compilation without gzip support\n";
			system("sed -i 's/#define _gzipread/#define _notgzip/g' $ldi2/DNAconsts.h");
			system("rm $ldi2/*.o");
			$stat = system("make -C $ldi2");
			$finalWarning .= "Can not read gzip file\n";
		}
		if ($stat == 0){
			system("rm -f $ldir/sdm $bdir/sdm; mv $ldi2/sdm $bdir/sdm; chmod +x $bdir/sdm");
		} elsif ($isMac && $stat){
			print "\n\n=================\nCompilation of sdm failed.\n It seems this is a Mac system and no native sdm compile is available, please try installing C++0x clang or gcc support for your system first, otherwise contact falk.hildebrand\@gmail.com .\n";
			print "Press any key to continue installation\n";
			$finalWarning .= "sdm was not compiled (this needs to be compiled to run lotus, rerun autoinstall, after your system has a C++0x compliant C++ compiler like clang , gcc installed).\n";
			<STDIN>;

		} else {
			print "\n\n=================\nCompilation of sdm failed (please contact falk.hildebrand\@gmail.com).\n A general prupose sdm binary is being used, but this is not recommended\n";
			print "Press any key to continue installation\n";
			$finalWarning .= "Non-native sdm compilation";
			<STDIN>;
		}
	}
	system("chmod +x $ldir/sdm");
	return "$bdir/sdm";
}
