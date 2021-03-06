#!/usr/bin/perl
# lOTUs2 - less OTU scripts
# Copyright (C) 2020 Falk Hildebrand

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

#use threads;
use 5.012;
use FindBin qw($RealBin);
my $LWPsimple = eval {
    require LWP::Simple;
    LWP::Simple->import();
    1;
};

sub usage;
sub help;
sub frame;
sub readPaths;sub readPaths_aligners;
sub announceClusterAlgo;  sub buildOTUs;
sub mergeUCs;sub delineateUCs;sub cutUCstring;sub uniq;
sub cdhitOTUs;
sub checkBlastAvaila;sub getSimBasedTax;

sub makeAbundTable2;
sub readMap;
sub assignTaxOnly;

sub writeUTAXhiera;
sub doDBblasting;
sub numberOTUs;
sub getTaxForOTUfromRefBlast;
sub get16Sstrand;
sub splitBlastTax;
sub extractTaxoForRefs;
sub calcHighTax;
sub buildTree;
sub combine;
sub contamination_rem;
sub readOTUmat;

#fasta IO
sub readFastaHd;
sub replaceFastaHd;
sub splitFastas;
sub extractFastas;
sub writeFasta;
sub readFasta;
sub revComplFasta;
sub reverse_complement_IUPAC;
sub newUCSizes;
sub readLinkRefFasta;
sub readTaxIn;
sub biomFmt;
sub printL;
sub finWarn;
sub printWarnings;    #1 to add warnings, the other to print these
sub forceMerge_fq2fna;
sub clean_otu_mat;
sub systemL;
sub swarmClust;
sub swarm4us_size;
sub dnaClust2UC;
sub chimera_rem;
sub checkLtsVer;
sub ITSxOTUs;
sub checkXtalk;
sub annotateFaProTax;
sub systemW;

#keep track of time
my $start = time;
my $duration;

#print qx/ps -o args $$/."\n";
my $cmdCall = qx/ps -o args $$/;

# --------------------
# Progams Pathways  -- get info from lotus.cfg
my $LCABin      = "";
my $sdmBin      = "./sdm";
my $usBin       = ""; #absolute path to usearch binary
my $dada2Scr    = ""; #absolute path to dada2 pipeline script
my $Rscript     = ""; #absolute path to Rscript -> also serves as check that Rscript exists on cluster..
my $swarmBin    = "";
my $VSBin       = "";
my $VSBinOri    = "";
my $VSused      = 1;
my $cdhitBin    = "";
my $dnaclustBin = "";
my $mini2Bin    = "minimap2";
my $mjar = ""; #RDP multiclassifier java archieve (e.g. /YY/MultiClassifier.jar)
my $rdpjar = ""
  ; #alternatively leave this "" and set environmental variabel to RDP_JAR_PATH, as described in RDP documentary
my $blastBin     = "";  #Blastn+ binary (e.g. /YY/ncbi-blast-2.2.XX+/bin/blastn)
my $mkBldbBin    = "";
my $lambdaBin    = "";  #lambda ref DB search
my $lambdaIdxBin = "";
my $clustaloBin  = ""; #clustalo multiple alignment binary (e.g. /YY/clustaloBin-1.2.0-OS-x86_64)
my $fasttreeBin = ""
  ; #FastTree binary - for speed improvements /YY/FastTReeMP recommended -- requires clastalo
my $flashBin   = "";    #flash for merging paired reads
my $itsxBin    = "";    #identifies ITS regions
my $hmmsrchBin = "";    #hmm required for itsx

# --------------------
#   databases
my $UCHIME_REFDB = ""; #reference database for ref chimera filtering - suggested is gold.fa or LSU93
my @TAX_REFDB = (); #greengenes or SILVA fasta ref database - requires $blastBin
my @TAX_RANKS = ();    #greengenes or SILVA taxonomic assignments for ref fasta database
my $CONT_REFDB_PHIX = "";           #ref Genome for PhiX contamination checks
my @refDBname       = ();
my $refDBwanted     = "";
my $refDBwantedTaxo = "";           #only used with custom ref DB files
my $ampliconType    = "SSU";
my $organism        = "bacteria";
my $FaProTax        = undef; #faprotax -> functional annotations from taxonomy~~

# --------------------

# --------------------
#general lOTUs parameters
my $selfID = "LotuS 2.00"; #release candidate: 2.0
my $citations = "$selfID: Hildebrand F, Tadeo RY, Voigt AY, Bork P, Raes J. 2014. LotuS: an efficient and user-friendly OTU processing pipeline. Microbiome 2: 30.\n";
my $noChimChk = 0; #deactivate all chimera checks 1=no nothing, 2=no denovo, 3=no ref; default = 0
my $mainLogFile = "";
my $osname      = $^O;

my $ClusterPipe_pre = "1";
my $ClusterPipe     = 1; #use UPARSE (1) or otupipe(0) or SWARM (2) or cd-hit(3), dnaclust (4), micca (5)
my $lotus_tempDir;
my $sdmOpt     = "";    #default sdm (simple demultiplexer) options
my $damagedFQ  = 0;
my $BlastCores = 12;    #number of cores to use for BLASTn
my $clQue      = "";    #"all.q";#"highmem";
my $OTU_prefix = "OTU_";    # Prefix for OTU label, default is OTU_ giving OTU_1, OTU_2 ...
my $chimera_prefix = "CHIMERA_"
  ;    # Prefix for chimera label, default is CHIM_ giving CHIM_1, OTU_2 ...
my $sep_smplID = "___";    #separator of smpID & ori fasta id
my $extendedLogs    = 1; #write chimeric OTUs, exact blast/RDP hits to extra dir
my $checkForUpdates = 1; #check online if a new lotus version is avaialble
my $maxReadOverlap   = 250;          #flash parameter
my $maxHitOnly       = 0;
my $greengAnno       = 0;            #if 1, annotate OTUs to best greengenes hit
my $pseudoRefOTU     = 0;            #replace OTU ids with best hit (LCA)
my $numInput         = 1;
my $saveDemulti      = 0;            #save a copy of demultiplexed reads??
my $check_map        = "";
my $lotusCfg         = "$RealBin/lOTUs.cfg";
my $curSdmV          = 1.30;
my $platform         = "miSeq";        #454, miSeq, hiSeq, PacBio
my $keepUnclassified = 1;
my $doITSx           = 1;            #run itsx in its mode?
my $ITSpartial       = 0;            #itsx --partial parameter
my $finalWarnings    = "";
my $remFromEnd       = ""; #fix for strange behavior of flash, where overlaps of too short amplicons can include rev primer / adaptor
my $doPhiX			 = 1;
my $dada2Seed        = 0; #seed for dada2 to produce reproducible results


#my $combineSamples = 0; #controls if samples are combined
my $chimCnt = "F";    #should chimeric OTU counts be split up among parents?

#flow controls
my $onlyTaxRedo = 0;    #assumes that outdir already contains finished lotus run
my $TaxOnly     = 0
  ; #will override most functionality and skip directly ahead to tax assignment part

# --------------------
#similarity taxo search options
my $RDPCONF     = 0.8;    #RDP confidence threshhold
my $utaxConf    = 0.8;    #UTAX confidence threshhold
my $LCAfraction = 0.8;    #number of matching taxa to accept taxa level
my $minBit      = 120;
my $minEval     = 1e-14;    #blast filtering; should be optimized to different platforms
my @idThr = ( 97, 93, 93, 91, 88, 78, 0 );
my $lengthTolerance =
  0.85;     #length of hits to still consider valid, compared to longest match
my $linesPerFile = 4000000;
my $otuRefDB =
  "denovo"; #OTU building strategy: "denovo" (default), "ref_closed", "ref_open"
my $doBlasting = -1;       #$doBlasting 2:lambda, 1:blast, 0:RDP, -1: ini value, 3:utax 4: vsearch 5: usearch
my $doRDPing          = -1;    #0: not, 1:do RDP
my $doBlasting_pre    = -1;
my $custContamCheckDB = "";
my $lowMemLambI       = 0;

# --------------------
#uparse / otupipe / cdhit / swarm options
my $useVsearch=0; # 1(vsearch) or 0(usearch) for chim check are being used, searching, matching tasks
#my $preferVsearch   = 0;      #0=use usearch always; 1=use vesarch always
my $chimera_absskew = 2;      # Abundance skew for de novo chimera filtering # 2
my $id_OTU          = .97;    # Id threshold for OTU clustering  #Default: .97
my $swarmClus_d     = 1;
my $id_OTU_noise =
  .99;   # Id threshold for error correction (noise removal) round #Default: .99
my $uthreads                = 1;
my $dereplicate_minsize_def = 2
  ; # Discard clusters < dereplicate_minsize in error correction round #Default: 2 for UPARSE, 4 for otupipe
my $dereplicate_minsize = -1;
my $doXtalk             = -1;    #check for cross talk in OTU tables
my $usearchVer          = 7;

#flash control
my $flashCustom = "";

#### DEPRECEATED ###
my $truncLfwd    = 130;    #250 for fwd illumina miSeq & 454; 90 for hiSeq fwd
my $truncLrev    = 200;    #200 for rev illumina miSeq; 90 for hiSeq rev
my $truncQual    = 25;     #15 for illumina miSeq, 25 for 454
my $UPARSEfilter = 0
  ; #use additional quality filter from uparse (1) or use sdm only for filtering (0) # Default: 0
#### DEPRECEATED ###

my $input;
my $outdir;
my $inq         = "";
my $barcodefile = "";
my $map;
my $exec       = 0;    #my $highmem = 0;
my $sdmDerepDo = 2;
if ( !@ARGV ) {
    usage();
    exit 1;
}
GetOptions(
    "help|?"                => \&help,
    "i=s"                   => \$input,
    "o=s"                   => \$outdir,
    "barcode=s"             => \$barcodefile,
    "m|map=s"               => \$map,
    "taxOnly|TaxOnly=i"             => \$TaxOnly,
    "check_map=s"           => \$check_map,
    "q|qual=s"              => \$inq,
    "s|sdmopt=s"            => \$sdmOpt,
    "t|tmpDir=s"            => \$lotus_tempDir,
    "c|config=s"                => \$lotusCfg,
    "exe|executionMode=i"       => \$exec,
    "CL|clustering|UP|UPARSE=s" => \$ClusterPipe_pre,
    "thr|threads=i"         => \$uthreads,
    "highmem=i"             => \$sdmDerepDo,
    "useBestBlastHitOnly=i" => \$maxHitOnly,
    "pseudoRefOTUcalling=i" => \$pseudoRefOTU,
    "greengenesSpecies=i"   => \$greengAnno,
    "id=f"                  => \$id_OTU,
    "xtalk=i"               => \$doXtalk,
    "saveDemultiplex=i"     => \$saveDemulti,        #1=yes, 0=not, 2=yes,unfiltered
    "rdp_thr=f"             => \$RDPCONF,
    "itsextraction=i"       => \$doITSx,
    "itsx_partial=i"        => \$ITSpartial,
    "utax_thr=f"            => \$utaxConf,
    "LCA_frac=f"            => \$LCAfraction,
    "chim_skew=f"           => \$chimera_absskew,		#miSeq,hiSeq,pacbio
    "p|platform=s"          => \$platform,
    "tolerateCorruptFq=i"   => \$damagedFQ,
    "keepUnclassified=i"    => \$keepUnclassified,
    "derepMin=s"            => \$dereplicate_minsize,
    "doBlast|simBasedTaxo|taxAligner=s"=> \$doBlasting_pre,
    "refDB=s"               => \$refDBwanted,
    "redoTaxOnly=i"         => \$onlyTaxRedo,
    "tax4refDB=s"           => \$refDBwantedTaxo,
    "amplicon_type=s"       => \$ampliconType,       #SSU LSU ITS ITS1 ITS2
    "tax_group=s"           => \$organism,           #fungi bacteria, euakaryote
    "readOverlap=i"         => \$maxReadOverlap,
    "endRem=s"              => \$remFromEnd,
    "keepTmpFiles=i"        => \$extendedLogs,
    "swarm_distance=i"      => \$swarmClus_d,
	"dada2seed=i"           => \$dada2Seed,
    "OTUbuild=s"            => \$otuRefDB,
    "count_chimeras=s"      => \$chimCnt,            #T or F
    "offtargetDB=s"         => \$custContamCheckDB,
    "flash_param=s"         => \$flashCustom,
    "deactivateChimeraCheck=i" => \$noChimChk,
	"VsearchChimera=i"		=> \$useVsearch,
	"removePhiX=i"			=> \$doPhiX,

    # "flashAvgLength" => \$flashLength,
    #"flashAvgLengthSD" => \$flashSD,
) or usage("Unknown options");

#still undocumented options: VsearchChimera removePhiX

#uc/lc some vars
$platform = lc($platform);
if ($greengAnno) {
    $pseudoRefOTU   = 1;
    $refDBwanted    = "GG";
    $doBlasting_pre = "4";
    print
"Greengenes ID as species ID requested (for integration with software that requires greengenes ID).\nUsing Lambda OTU similarity search and greengenes ref DB\n";
}    #
if ( -f $refDBwanted ) {
}
elsif ( $refDBwanted =~ m/^GG|SLV|UNITE|HITDB|PR2|BEETAX$/i ) {

    #$refDBwanted = uc($refDBwanted);
}
elsif ( $refDBwanted ne "" ) {
    print "$refDBwanted not recognized. Aborting..\n";
    exit(5);
}
if ( $platform eq "pacbio" ) {
    $dereplicate_minsize_def = 0;
}
if ( $dereplicate_minsize !~ m/\D/ && $dereplicate_minsize == -1 ){
	$dereplicate_minsize = $dereplicate_minsize_def ;
}

#die $refDBwanted."\n";
$ampliconType    = uc($ampliconType);
$organism        = lc($organism);
$ClusterPipe_pre = uc($ClusterPipe_pre);
$otuRefDB        = lc $otuRefDB;

if ( $check_map ne "" ) {
    $map = $check_map;
    my ( $x11, $x22, $x33 ) = readMap();
    print "\n\nmapping file seems correct\n";
    exit(0);
}

getSimBasedTax();

if ( !defined($input) && !defined($outdir) && !defined($map) ) { usage(""); }
defined($input) or usage("-i option (input dir/files) is required\n");
if ( $input =~ m/\*/ ) {
    die
"\"*\" not supported in input command. Please see documentation on how to set up the mapping file for several input files.";
}
defined($outdir) or usage("-o option (output dir) is required\n");
if ( !defined($map) && $TaxOnly == 0 ) {
    usage("-m missing option (mapping file)\n");
}
if ( !defined($sdmOpt) && $TaxOnly == 0 ) {
    finWarn("WARNING:\n sdm options not set\n WARNING\n");
}
defined($lotus_tempDir) or $lotus_tempDir = $outdir . "/tmpFiles/";
system("rm -f -r $outdir") if ( $exec == 0 && $onlyTaxRedo == 0 && $TaxOnly == 0 );
system("mkdir -p $outdir") unless ( -d $outdir );
if ( !-d $outdir ) {  die( "Failed to make outputdir or doesn't exist: " . $outdir . "\n" );}

my $existing_otus = "";

$BlastCores = $uthreads;
my $logDir       = $outdir . "/LotuSLogS/";
my $extendedLogD = $outdir . "/ExtraFiles/";
system("mkdir -p $logDir") unless ( -d $logDir );#$3

$mainLogFile = $logDir . "LotuS_run.log";
my $cmdLogFile = $logDir . "LotuS_cmds.log";

#reset logfile
open LOG, ">", $mainLogFile or die "Can't open Logfile $mainLogFile\n";
open cmdLOG , ">$cmdLogFile" or die "Can't open cmd log $cmdLogFile\n";



if ($extendedLogs) {
    systemL("mkdir -p $extendedLogD") unless ( -d $extendedLogs );
}

#die "$sdmDerepDo \n";
#-----------------
#all parameters set; pipeline starts from here
printL( frame( "\n" . $selfID . "\n" ) . $cmdCall . "\n", 0 );

if ( $platform eq "hiseq" ) {
    $linesPerFile = 8000000;
}
my $defDBset = 0;
if ( $refDBwanted eq "" ) {
    $refDBwanted = "GG";
    $defDBset    = 1;
}

readPaths_aligners($lotusCfg);
my $usvstr = `$usBin --version`;

#die $usvstr."\n";
$usvstr =~ m/usearch v(\d+\.\d+)\.(\d+)/;
$usearchVer = $1;
my $usearchsubV = $2;

#if ($usearchVer == 9){printL "Usearch ver 9 currently not supported, please install ver 8.\n",39;}
if ( $usearchVer > 11 ) {
    printL "Usearch ver $usearchVer is not supported.\n", 55;
}
elsif ( $usearchVer >= 8 && $usearchVer < 9 ) {
    printL
"Usearch ver 8 is outdated, it is recommended to install ver 9.\nDownload from http://drive5.com/ and execute \n\"./autoInstall.pl -link_usearch [path to usearch9]\"\n",
      0;
}
elsif ( $usearchVer < 8 ) {
    printL "Usearch ver 7 is outdated, it is recommended to install ver 9.\nDownload from http://drive5.com/ and execute \n\"./autoInstall.pl -link_usearch [path to usearch9]\"\n",0;
}

#die "$usearchVer $usearchsubV\n";
if ( $doXtalk == -1 ) {
    if ( $usearchVer >= 11 ) {
        $doXtalk = 0;    #deactivate since useless if not 64-bit uparse
    }
    else {
        $doXtalk = 0;
    }
}

#die "$VSBin\n";
#which default aligner?
if ( $doBlasting == -1 ) {
    if ($defDBset) {
        $doBlasting = 0;
    }   else {
        #check which aligner is installed
        my $defaultTaxAlig = 4;
        if ( !-f $VSBin ) {
            if ( -f $lambdaBin ) { $defaultTaxAlig = 2; }
            if ( -f $usBin ) { $defaultTaxAlig = 5; }
            if ( -f $blastBin ) { $defaultTaxAlig = 1; }
            elsif ( !-f $blastBin && $refDBwanted ne "" ) {
                printL "Requested similarity search ($refDBwanted), but no suitable aligner (blast, lambda) binaries found!\n",
                  50;
            }
        }
        if ( substr( $ampliconType, 0, 3 ) eq "ITS" ) {
            $doBlasting  = $defaultTaxAlig;
            $refDBwanted = "UNITE";
        }
        if ( $refDBwanted ne "" ) {
            $doBlasting = $defaultTaxAlig;    #set default to lambda
            printL "RefDB $refDBwanted requested. Setting similarity based search to default Blast option to search $refDBwanted.\n",
              0;
        }
    }
}
elsif ( $doBlasting == 0 && $refDBwanted ne "" ) {
    printL "RefDB $refDBwanted requested, but -taxAligner set to \"0\": therefore RDP classification of reads will be done\n",
      0;
}

readPaths($lotusCfg);

#die "$refDBwanted\n";
if ( $doBlasting < 1 ) {
    $doRDPing = 1;
}
else {    #LCA only
    $doRDPing = 0;
}

if ( $ClusterPipe_pre eq "CD-HIT" || $ClusterPipe_pre eq "CDHIT" || $ClusterPipe_pre eq "3" ) {
    $ClusterPipe = 3;
    if ( !-e $cdhitBin ) {
        printL "No valid CD-Hit binary found at $cdhitBin\n", 88;
    }
}elsif ( $ClusterPipe_pre eq "UPARSE" || $ClusterPipe_pre eq "1" ) {
    $ClusterPipe = 1;
}elsif ( $ClusterPipe_pre eq "UNOISE" || $ClusterPipe_pre eq "UNOISE3" || $ClusterPipe_pre eq "6" ) {
    $ClusterPipe = 6;
	$OTU_prefix = "Zotu";
}elsif ( $ClusterPipe_pre eq "DADA2" || $ClusterPipe_pre eq "7" ) {
    $ClusterPipe = 7;
	$OTU_prefix = "ASV";
}elsif ( $ClusterPipe_pre eq "SWARM" || $ClusterPipe_pre eq "2" ) {
    $ClusterPipe = 2;
    if ( !-e $swarmBin ) {
        printL "No valid swarm binary found at $swarmBin\n", 88;
    }
}elsif ( $ClusterPipe_pre eq "DNACLUST" || $ClusterPipe_pre eq "4" ) {
    $ClusterPipe = 4;
    if ( !-e $dnaclustBin ) {
        printL "No valid DNA clust binary found at $dnaclustBin\n", 88;
    }
}
if ( $platform eq "pacbio" && $ClusterPipe != 3 ) {
    printL(
"CD-HIT clustering is strongly recommended with PacBio reads (unless you know what you are doing).",
        "w"
    );
}

#reference based OTU clustering requested?
my $REFflag = $otuRefDB eq "ref_closed" || $otuRefDB eq "ref_open";

if ($REFflag) {
    if ( $ClusterPipe == 0 ) {
        printL(
"otupipe does not support ref DB out clustering\nUse dnaclust instead\n",
            12
        );
    }
    elsif ( $ClusterPipe == 1 ) {
        printL("UPARSE does not support ref DB out clustering\nUse dnaclust instead\n",12 );
    }
    elsif ( $ClusterPipe == 6 ) {
        printL("UNOISE does not support ref DB out clustering\nUse dnaclust instead\n",12 );
    }
    elsif ( $ClusterPipe == 2 ) {
        printL(
"SWARM does not support ref DB out clustering\nUse dnaclust instead\n",
            12
        );
    }
    if ( $refDBwanted eq "" ) {
        printL
"You selected ref based OTU building, please set -refDB to \"SLV\", \"GG\", \"HITdb\", \"PR2\" or a custom fasta file.\n",
          22;
    }

}

checkBlastAvaila();

#"LotuS 1.281"
$selfID =~ m/LotuS (\d\.\d+)/;
my $sdmVer = checkLtsVer($1);
if ( $sdmVer < $curSdmV ) {
    finWarn
"Installed sdm version ($sdmVer < $curSdmV) seems to be outdated, please check on \n    lotus2.earlham.ac.uk\nfor the most recent version. Make sure the sdm path in '$lotusCfg' points to the correct sdm binary\n";
}
$swarmClus_d = int($swarmClus_d);
if ( $swarmClus_d < 1 ) {
    printL "Please provide as swarm distance an int > 0\n", 29;
}

#change automatically lambdaindexer based on mem installed in machine
if ( (`cat /proc/meminfo |  grep "MemTotal" | awk '{print \$2}'`) < 16524336 ) {
    $lowMemLambI = 1;
    printL "Less than 16GB Ram detected, switching to mem-friendly workflow\n";
}

#die();
if ( $sdmOpt eq "" ) {
    $sdmOpt = "$RealBin/sdm_miSeq.txt";
    printL "No sdm Option specified, using standard 454 sequences options", 0;
}
if ( !-e $sdmOpt ) {
    printL "Could not find sdm options file (specified via \"-s\". Please make sure this is available.\n Aborting run..\n",
      33;
}

#die $LCABin."\n";
if ( substr( $ampliconType, 0, 3 ) eq "ITS" ) {
    if ( $organism ne "fungi" && $organism ne "eukaryote" ) {
        $organism = "eukaryote";
        finWarn
"Setting \"-tax_group\" to \"eukaryote\" as only eukaryote and fungi are supported options for $ampliconType.\n";
    }

    if (   $doBlasting == 0
        || ( !-f $blastBin && !-f $lambdaBin )  || @TAX_REFDB == 0 || !-f $TAX_REFDB[0] )
    {
        my $failedBlastITS = "ITS region was chosen as target; this requires a similarity based taxnomic annotation and excludes RDP tax annotation.\n";
        $failedBlastITS .= "Blast similarity based annotation is not possible due to: ";
        if ( $doBlasting == 0 ) {
            $failedBlastITS .= "Similarity search was not explicitly activated (please use option \"-taxAligner usearch\" or vsearch,lambda,blast).";
        }
        elsif ( !-f $blastBin || !-f $lambdaBin ) {
            $failedBlastITS .=
              "Neither Lambda nor Blast binary being specified correctly";
        }
        elsif ( @TAX_REFDB == 0 || !-f $TAX_REFDB[0] ) {
            $failedBlastITS .= "Reference DB does not exist ($TAX_REFDB[0]).\n";
        }
        $failedBlastITS .= "\nTherefore LotuS had to abort..\n";
        printL $failedBlastITS, 87;
    }

#$doBlasting && (-f $blastBin || -f $lambdaBin) && $TAX_REFDB ne "" && -f $TAX_REFDB)
}
if ( $noChimChk < 0 || $noChimChk > 3 ) {
    printL "option \"-deactivateChimeraCheck\" has to be between 0 and 3\n", 45;
}
if ( $saveDemulti < 0 || $saveDemulti > 3 ) {
    printL "option \"-saveDemultiplex\" has to be between 0 and 3\n", 46;
}

#if ($ClusterPipe == 1 && ($noChimChk == 2 || $noChimChk == 1) ){
#printL "Deactivation of deNovo chimera filter in conjuction with UPARSE clustering is NOT supported","w";
#}
#die $TAX_REFDB."\n";

my @inputArray = split( /,/, $input );
my @inqArray   = split( /,/, $inq );
$numInput = scalar(@inputArray);
if ( scalar(@inqArray) > 0
    && $numInput != scalar(@inqArray)
    && -f $inqArray[0] ){
    printL("Error: fasta input file number does not correspond ot quality file number.\n", 1);
}

#unless ($platform eq "miSeq" || $platform eq "hiSeq") {#only support paired reads for hi/miSeq
#	$numInput = 1;
#}

#read map, also check map file format
my ( $mapHref, $combHref, $hasCombiSmpls ) = ( {}, {}, 0 );
my %mapH;
if ( $TaxOnly == 0 ) {
    ( $mapHref, $combHref, $hasCombiSmpls ) = readMap();
    %mapH = %{$mapHref};
}

#die;

#die $exec."\n";
if ( $ClusterPipe == 0 ) {
    printL( "Warning: otupipe sequence clustering mode is depreceated.\n\n",
        0 );
}
if ( $ClusterPipe == 0 && $id_OTU_noise < $id_OTU ) {
    printL( "id_OTU must be bigger-or-equal than id_OTU_noise\n", 2 );
}
if ( $id_OTU > 1 || $id_OTU < 0 ) {
    printL( "\"-id\" set to value <0 or >1: $id_OTU\nHas to be between 0 and 1\n", 2 );
}

my $t = $lotus_tempDir;
systemL("rm -f -r $t") if ( $exec == 0 );
systemL("mkdir -p $t") unless ( -d $t );
if ( !-d $t ) {
    die( "Failed to make tmp dir or doesn't exist: " . $t . "\n" );
}

#CONSTANT file paths
my $highLvlDir   = $outdir . "/higherLvl/";
my $FunctOutDir = $outdir . "/derrivedFunctions/";
my $RDP_hierFile = "$outdir/hiera_RDP.txt";
my $SIM_hierFile = "$outdir/hiera_BLAST.txt";

#my $currdir=`pwd`;
my $clustMode = "de novo";
$clustMode = "reference closed" if ( $otuRefDB eq "ref_closed" );
$clustMode = "reference open"   if ( $otuRefDB eq "ref_open" );
if ( !$onlyTaxRedo && !$TaxOnly ) {
    if ( $ClusterPipe == 0 ) {
        printL( "Running otupipe $clustMode sequence clustering..\n", 0 );
    }
    elsif ( $ClusterPipe == 1 ) {
        printL( "Running UPARSE $clustMode sequence clustering..\n", 0 );
    }
    elsif ( $ClusterPipe == 7 ) {
        printL( "Running DADA2 $clustMode sequence clustering..\n", 0 );
		die "Incorrect dada2 script defined $dada2Scr" unless (-f $dada2Scr);
		die "Incorrect R installation (can't find Rscript)" unless (-f $Rscript);
		
    }
    elsif ( $ClusterPipe == 6 ) {
        printL( "Running UNOISE $clustMode sequence clustering..\n", 0 );
    }
    elsif ( $ClusterPipe == 2 ) {
        printL( "Running SWARM $clustMode sequence clustering..\n", 0 );
    }
    elsif ( $ClusterPipe == 3 ) {
        printL( "Running CD-HIT $clustMode sequence clustering..\n", 0 );
    }
    elsif ( $ClusterPipe == 4 ) {
        printL( "Running DNACLUST $clustMode sequence clustering..\n", 0 );
    }
    if   ($sdmDerepDo) { printL "Running fast LotuS mode..\n"; }
    else               { printL "Running low-mem LotuS mode..\n"; }
}
else {    #prep for redoing tax, save previous tax somehwere
    printL "Re-Running only tax assignments, no de novo clustering\n", 0;
    my $k       = 0;
    my $newLDir = "$outdir/prevLtsTax_$k";
    while ( -d $newLDir ) { $k++; $newLDir = "$outdir/prevLtsTax_$k"; }
    printL frame("Saving previous Tax to $newLDir"), "w";
    systemL "mkdir -p $newLDir/LotuSLogS/";
    systemL "mv $highLvlDir $FunctOutDir $RDP_hierFile $SIM_hierFile $outdir/hierachy_cnt.tax $outdir/cnadjusted_hierachy_cnt.tax $newLDir/";
    systemL "mv $outdir/LotuSLogS/* $newLDir/LotuSLogS/";
    systemL("mkdir -p $logDir") unless ( -d $logDir );

    if ($extendedLogs) {
        systemL("mkdir -p $extendedLogD") unless ( -d $extendedLogs );
    }

}
printL "------------ I/O configuration --------------\n", 0;
printL( "Input=   $input\nOutput=  $outdir\n", 0 );    #InputFileNum=$numInput\n
if ( $barcodefile ne "" ) {
    printL "Barcodes= $barcodefile\n";
}
printL "TempDir= $t\n",                                     0;
printL "------------ Configuration LotuS --------------\n", 0;
printL( "Sequencing platform=$platform\nAmpliconType=$ampliconType\n", 0 );
if ( $ClusterPipe == 2 ) {
    printL "Swarm inter-cluster distance=$swarmClus_d\n", 0;
}
else {
    printL "OTU id=$id_OTU\n", 0;
}
printL "min unique read abundance=" . ($dereplicate_minsize) . "\n", 0;
if ( $noChimChk == 1 || $noChimChk == 3 ) {
    printL "No RefDB based Chimera checking\n", 0;
}
elsif ( $noChimChk == 0 || $noChimChk == 2 ) {
    printL "UCHIME_REFDB, ABSKEW=$UCHIME_REFDB, $chimera_absskew\nOTU, Chimera prefix=$OTU_prefix, $chimera_prefix\n",
      0;
}
if ( $noChimChk == 1 || $noChimChk == 2 ) {
    printL "No deNovo Chimera checking\n", 0;
}
if ( $doBlasting == 1 ) {
    printL "Similarity search with Blast\n", 0;
    if ( !-e $blastBin ) {
        printL "Can't find blast binary at $blastBin\n", 97;
    }
} elsif ( $doBlasting == 2 ) {
    printL "Similarity search with Lambda\n", 0;
    if ( !-e $lambdaBin ) {
        printL "Can't find LAMBDA binary at $lambdaBin\n", 96;
    }
    if ( !-e $lambdaIdxBin ) {
        printL "Can't find valid labmda indexer executable at $lambdaIdxBin\n",  98;
    }
}elsif ( $doBlasting == 4 ) {
    printL "Similarity search with VSEARCH\n", 0;
    if ( !-e $VSBinOri ) {
        printL "Can't find VSEARCH binary at $VSBinOri\n", 96;
    }
}elsif ( $doBlasting == 5 ) {
    printL "Similarity search with USEARCH\n", 0;
    if ( !-e $usBin ) {
        printL "Can't find VSEARCH binary at $usBin\n", 96;
    }
}
unless ( $doBlasting < 1 ) {
    printL "ReferenceDatabase=@refDBname\nRefDB location=@TAX_REFDB\n", 0;
    if ( !-e $TAX_REFDB[0] ) {
        printL "RefDB does not exist at loction. Aborting..\n", 103;
    }
}

printL "TaxonomicGroup=$organism\n", 0;
if ( $ClusterPipe == 0 ) {
    printL "PCTID_ERR=$id_OTU_noise\n";
}
if ( $custContamCheckDB ne "" ) {
    if ( -f $custContamCheckDB ) {
        printL "Custom DB for contaminations: $custContamCheckDB\n", 0;
    }
    else {
        printL
"Can't find file at location $custContamCheckDB for custom contamination checking..\n",
          45;
    }
}
printL "--------------------------------------------\n", 0;

systemL("mkdir -p $outdir/primary") unless ( -d "$outdir/primary" );

#=========
# Pipeline



# ////////////////////////// sdm 1st time (demult,qual etc) /////////////////////////////////////////////
#  cmdArgs["-i_MID_fastq"]
my $sdmcmd       = "";
my $filterOut    = "$t/demulti.fna";
my $filterOutAdd = "$t/demulti.add.fna";
if ( $numInput > 1 ) {
    $filterOut    = "$t/demulti.1.fna,$t/demulti.2.fna";
    $filterOutAdd = "$t/demulti.1.add.fna,$t/demulti.2.add.fna";
}
my $filOutCmd = "-o_fna ";
if ($UPARSEfilter) {
    $filterOut    = "$t/demulti.fastq";
    $filOutCmd    = "-o_fastq ";
    $filterOutAdd = "$t/demulti.add.fastq";
    if ( $numInput > 1 ) {
        $filterOut    = "$t/demulti.1.fastq,$t/demulti.2.fastq";
        $filterOutAdd = "$t/demulti.1.add.fastq,$t/demulti.2.add.fastq";
    }
}
my $qualOffset = "-o_qual_offset 33";       #33 for UPARSE
my $sdmOut     = $filOutCmd . $filterOut;
my $sdmIn      = "";
my $paired     = $numInput;
if ( -d $input ) {
    $sdmIn = "-i_path $input ";
}
elsif ( -f $inputArray[0] && $inq ne "" && -f $inqArray[0] ) {
    if ( $paired == 1 ) {
        $sdmIn = "-i_fna $inputArray[0] -i_qual $inqArray[0] ";
    }
    elsif ( $paired == 2 ) {
        $sdmIn =
"-i_fna $inputArray[0],$inputArray[1] -i_qual $inqArray[0],$inqArray[1] ";
    }
}
else {
    if ( $paired == 1 ) {
        $sdmIn = "-i_fastq $inputArray[0]";
    }
    elsif ( $paired == 2 ) {
        $sdmIn = "-i_fastq $inputArray[0],$inputArray[1]";
    }
}

#for now: only use fwd pair
#if ($paired != 1){$paired.= " -onlyPair 1";}
if ( $barcodefile ne "" ) {
    $sdmIn .= " -i_MID_fastq $barcodefile";
}
my $derepCmd    = "";
my $paired_sdm  = "";
my $derepOutHQ  = "";
my $derepOutHQ2 = "";
my $derepOutMap = "";

my $sdmDemultiDir = "";
my $sdmOptStr     = "-options $sdmOpt ";
if ( $saveDemulti == 2 || $saveDemulti == 1 || $ClusterPipe == 7 ) { #dada2 also requires filtered raw reads
    $sdmDemultiDir = "$outdir/demultiplexed/";
    if ( $saveDemulti == 1 ) {
        printL "Demultiplexed input files into single samples, no quality filtering done\n";
        $sdmOptStr = "";
    }
	if ($ClusterPipe == 7){ #dada2.. no rd pair info in head!
		$sdmOptStr .= "-pairedRD_HD_out 0 ";
	}
}

if ($sdmDerepDo) {
    $derepCmd = "-o_dereplicate $t/derep.fas ";
    if ( 0 && $ClusterPipe == 2 ) {
        $derepCmd .= "-dere_size_fmt 1 ";
    }
    else { $derepCmd .= "-dere_size_fmt 0 "; }
    $derepCmd .= " -min_derep_copies $dereplicate_minsize ";
    $derepOutHQ  = "$t/derep.hq.fq";
    $derepOutMap = "$t/derep.map";
    $derepOutHQ2 = "$t/derep.2.hq.fq";
    if ( $saveDemulti == 3 ) {   #temp deactivated, since I have  $sdmDemultiDir
        $derepCmd .= " -suppressOutput 0";
    }
    else {
        $derepCmd .= " -suppressOutput 1";
    }
}
else {
    if ( $paired != 1 ) { $paired_sdm .= " -onlyPair 1"; }
}
my $demultiSaveCmd = "";
if ( $sdmDemultiDir ne "" ) {
    systemL "mkdir -p $sdmDemultiDir" unless ( -d $sdmDemultiDir );
    $demultiSaveCmd .= " -o_demultiplex $sdmDemultiDir";
}
my $dmgCmd = "";
if ($damagedFQ) { $dmgCmd = "-ignore_IO_errors 1"; }
my $mainSDMlog = "$logDir/demulti.log";
$sdmcmd =
"$sdmBin $sdmIn $sdmOut -sample_sep $sep_smplID  -log $mainSDMlog -map $map $sdmOptStr $demultiSaveCmd $derepCmd $dmgCmd $qualOffset -paired $paired $paired_sdm -maxReadsPerOutput $linesPerFile -oneLineFastaFormat 1";    #4000000
#die $sdmcmd."\n";


if ( $exec == 0 && $onlyTaxRedo == 0 && $TaxOnly == 0 ) {
    $duration = time - $start;
    printL( frame("Demultiplexing input files\n elapsed time: $duration s"),
        0 );
    systemL("cp $map $outdir/primary\n cp $sdmOpt $outdir/primary");
    if ( systemL($sdmcmd) != 0 ) {
        printL "FAILED sdm demultiplexing step: " . $sdmcmd . "\n";
        exit(4);
    }
    my $fileNum = `ls -1 $mainSDMlog* | wc -l`;
    systemL "mkdir -p $logDir/SDMperFile/; mv $mainSDMlog"
      . "0* $logDir/SDMperFile/";
    if ( $fileNum > 10 ) {
        systemL
"tar zcf $logDir/SDMperFile.tar.gz $logDir/SDMperFile/; rm -r $logDir/SDMperFile/";
    }
    if ( `cat $mainSDMlog` =~ m/binomial est\. errors/ ) {
        $citations .=
"Poisson binomial model based read filtering: Fernando Puente-Sánchez, Jacobo Aguirre, Víctor Parro (2015).A novel conceptual approach to read-filtering in high-throughput amplicon sequencing studies. Nucleic Acids Res.(2015).\n";
    }

    #postprocessing of output files
    if ( $saveDemulti == 1 || $saveDemulti == 2 ) {    #gzip stuff
        printL "Zipping demultiplex output..\n";
        systemL "gzip $sdmDemultiDir/*.fq";
    }
    if ( $saveDemulti == 1 ) {
        printL
"Demultiplexed intput files with not quality filtering to:\n$sdmDemultiDir\nFinished task, if you want to have a complete LotuS run, change option \"-saveDemultiplex\"\n";
        exit(0);
    }
    if ( $saveDemulti == 3 && $exec == 0 )
    {    #&& $onlyTaxRedo==0){#gzip demultiplexed fastas
        systemL "mkdir -p $outdir/demultiplexed; ";
        my @allOuts = split /,/, $filterOut;
        foreach (@allOuts) {
            $_ =~ m/\/([^\/]+$)/;
            my $fn  = $1;
            my $fns = $fn;
            $fns =~ s/\.(f[^\.]+)$/\.singl\.$1/;

#			systemL "gzip -c $_*.singl > $outdir/demultiplexed/$fn.singl.gz; rm -f $_*.singl";
#			systemL "gzip -c $_* > $outdir/demultiplexed/$fn.gz; rm -f $_*";
            die "DEBUG new singl filenames\n";
            systemL "gzip -c $fns > $outdir/demultiplexed/$fn.singl.gz; rm -f $_*.singl";
            systemL "gzip -c $_* > $outdir/demultiplexed/$fn.gz; rm -f $_*";
        }
        @allOuts = split /,/, $filterOutAdd;
        foreach (@allOuts) {
            $_ =~ m/\/([^\/]+$)/;
            systemL "gzip -c $_* > $outdir/demultiplexed/$1.gz; rm -f $_*";
        }
    }
}
elsif ($onlyTaxRedo) {
    printL "Skipping Quality Filtering & demultiplexing & dereplication step\n",
      0;
}
my $cmd = "";

#die();
#exit;
# ////////////////////////// OTU building ///////////////////////////////////////


my $A_UCfil;
my $tmpOTU = "$t/tmp_otu.fa";
my $OTUfa  = "$outdir/otus.fa";



my $ucFinalFile = "";
$duration = time - $start;
if ( $ClusterPipe != 0 && $onlyTaxRedo == 0 && $TaxOnly == 0 ) {
	#$ClusterPipe == 0 
	announceClusterAlgo();
	($A_UCfil) = buildOTUs($tmpOTU);
	my @tmp = @$A_UCfil;
	#die "@tmp\n";
	$ucFinalFile = $tmp[0];
}
elsif ( $onlyTaxRedo == 1 ) {
    printL "Clustering step was skipped\n", 0;
}
elsif ( $TaxOnly == 1 ) {
    printL
"No qual filter, demultiplexing or clustering required, as taxonomy only requested\n",
      0;
}
else {
    printL
"clustering method (-CL/-clustering) unknown, given argument was '$ClusterPipe'\n",
      5;
}
$duration = time - $start;

#/////////////////////////////////////////  SEED extension /////////////////////
#$derepOutMap,$derepOutHQ
my @mergeSeedsFiles; my @mergeSeedsFilesSing;
my $OTUSEED    = "$t/otu_seeds.fna";
my $OTUrefSEED = "$t/otu_seeds.fna.ref";

#uc additions have to be in matrix creation (>0.96 through sdm)
#my $UCadditions = $ucFinalFile.".ADD";
my $OTUmFile = "$outdir/OTU.txt";
my $OTUmRefFile =
  "$outdir/OTU_psRef.txt";    #diff to OTU.txt: collapse entries with same ref
$OTUmRefFile = "" unless ($pseudoRefOTU);
my $seedExtDone = 1;
my $refClusSDM  = "";
my $didMerge = 0; #were reads already merged before this step? -> so far always no


if ($REFflag)
{ #these need to be treated extra, as no new optimal ref seq needs to be identified..
    $refClusSDM .="-optimalRead2Cluster_ref $ucFinalFile.ref -OTU_fallback_refclust $tmpOTU.ref";
    $refClusSDM .=" -ucAdditionalCounts_refclust $ucFinalFile.ADDREF -ucAdditionalCounts_refclust1 $ucFinalFile.RESTREF";

    #systemL "cat $UCadditions"."REF"." >> $UCadditions"
}

my $sdmOut2 = "-o_fna $OTUSEED";
if ( $numInput == 2 ) {
    push( @mergeSeedsFiles, "$t/otu_seeds.1.fq" );
    push( @mergeSeedsFiles, "$t/otu_seeds.2.fq" );
	@mergeSeedsFilesSing = @mergeSeedsFiles; 
	$mergeSeedsFilesSing[0] =~ s/\.1\.fq/\.1\.singl\.fq/;$mergeSeedsFilesSing[1] =~ s/\.2\.fq/\.2\.singl\.fq/;

    $sdmOut2    = "-o_fastq " . $mergeSeedsFiles[0] . "," . $mergeSeedsFiles[1];
    $OTUrefSEED = "$t/otu_seeds.1.fq.ref";

    #TODO : $sdmIn
}
my $upVer = "";
$upVer = "-uparseVer $usearchVer " if ($ClusterPipe == 1);
$upVer = "-uparseVer N11 "if ($ClusterPipe == 6);
if ($sdmDerepDo) {
    $sdmIn = "-i_fastq $derepOutHQ";
    if ( $numInput == 2 ) { $sdmIn = "-i_fastq $derepOutHQ,$derepOutHQ2"; }
    $sdmcmd ="$sdmBin $sdmIn $sdmOut2 $upVer -optimalRead2Cluster $ucFinalFile -paired $numInput -sample_sep $sep_smplID -derep_map $derepOutMap -options $sdmOpt $qualOffset -log $logDir/SeedExtensionStats.txt -mergedPairs $didMerge -OTU_fallback $tmpOTU -ucAdditionalCounts $ucFinalFile.ADD -ucAdditionalCounts1 $ucFinalFile.REST -otu_matrix $OTUmFile -count_chimeras $chimCnt $refClusSDM";
} else {
    $sdmcmd = "$sdmBin $sdmIn $sdmOut2 $upVer -optimalRead2Cluster $ucFinalFile -paired $numInput -sample_sep $sep_smplID -map $map -options $sdmOpt $qualOffset -log $logDir/SeedExtensionStats.txt -mergedPairs $didMerge -OTU_fallback $tmpOTU -otu_matrix $OTUmFile -ucAdditionalCounts $ucFinalFile.ADD -ucAdditionalCounts1 $ucFinalFile.REST -count_chimeras $chimCnt $refClusSDM";
}
my $status = 0;

#die $sdmcmd."\n";
#systemL "$sdmcmd";
if ( $exec == 0 && $onlyTaxRedo == 0 && $TaxOnly == 0 ) {
    printL frame("Extending OTU Seeds\nelapsed time: $duration s"), 0;
	#die "$sdmcmd\n";
    $status = systemL($sdmcmd);

    #print "\n\n".$status."\n\n";
}
elsif ($onlyTaxRedo) { printL "Skipping Seed extension step\n", 0; }
if ($status) {
    printL "Failed $sdmcmd\n",                    0;
    printL "Fallback to OTU median sequences.\n", 0;
    $seedExtDone = 0;
	$OTUSEED = $tmpOTU;
    #exit(11);
} else {
    $seedExtDone = 1;
}
undef $tmpOTU;



#/////////////////////////////////////////  paired read merging /////////////////////

if (   $numInput == 2){
	my $key = "merged";
	$input = "$t/$key";
	my $single1  = "";my $single2  = "";
	$input   = "$t/$key.extendedFrags.fastq";
	$single1 = "$t/$key.notCombined_1.fastq";
	$single2 = "$t/$key.notCombined_2.fastq";
	if (-s $mergeSeedsFiles[0] > 0 #check that file even exists..
			&& (-f $VSBin || -f $flashBin) #as well as the alignment programs
			&& $otuRefDB ne "ref_closed" && $onlyTaxRedo == 0  && $TaxOnly == 0 ) #and otherwise also wanted step..
	{
		my $mergCmd = "";
		
		#switch to vsearch for lotus2
		if (-f $VSBin){
			$mergCmd = "$VSBin  -fastq_mergepairs $mergeSeedsFiles[0]  -reverse  $mergeSeedsFiles[1] --fastqout $input --fastqout_notmerged_fwd $single1 --fastqout_notmerged_rev $single2 --threads $BlastCores\n";
			if ($VSused == 1){
				$citations .= "VSEARCH read pair merging: Rognes T, Flouri T, Nichols B, Quince C, Mahé F. (2016) VSEARCH: a versatile open source tool for metagenomics. PeerJ 4:e2584. doi: 10.7717/peerj.2584\n";
			}else{
				$citations .= "USEARCH read pair merging: R.C. Edgar (2010), Search and clustering orders of magnitude faster than BLAST, Bioinformatics 26(19) 2460-2461\n";
			}
			#die "$mergCmd\n"; #find out what the unmerged reads are..
		} elsif ( -f $flashBin ) {
			my $flOvOption = "-m 10 -M $maxReadOverlap ";
			if ( $flashCustom ne "" ) {

				#$flOvOption = "-r $flashLength -s $flashSD";
				$flashCustom =~ s/\"//g;
				$flOvOption = " $flashCustom ";
			}
			$mergCmd = "$flashBin $flOvOption -o $key -d $t -t $BlastCores "
			  . $mergeSeedsFiles[0] . " " . $mergeSeedsFiles[1];
			$mergCmd .= "cp $t/$key.hist $logDir/FlashPairedSeedsMerges.hist";
			
			$citations .="Flash read pair merging: Magoc T, Salzberg SL. 2011. FLASH: fast length adjustment of short reads to improve genome assemblies. Bioinformatics 27: 2957-63\n";
		} 

		#print $mergCmd."\n";
		if ( $exec == 0 ) {

			#die $mergCmd."\n".$flashCustom."\n";
			printL frame("Merging OTU seed paired reads"), 0;
			if ( !systemL($mergCmd) == 0 ) {
				printL( "Merge command failed: \n$mergCmd\n", 3 );
			}
		}
		if ( $single1 ne "" ){    
			
		}
		$didMerge = 1;
	} elsif ( $onlyTaxRedo && $numInput == 2 ) {
		printL "Skipping paired end merging step\n", 0;
	}
	
	#needs to be run in any case for paired input, just to make sure all reads are correctly listed in $OTUSEED
	forceMerge_fq2fna( $single1, $single2, $input,$mergeSeedsFilesSing[0], $OTUSEED );
}
#
#merge not combined reads & check for reverse adaptors/primers
#do this also in case no pairs were found at all.. Singletons need to be fq->fna translated into $OTUSEED

#at this point $tmpOTU (== $OTUSEED) contains the OTU ref seqs

#add additional sequences to unfinal file
#my $lnkHref = numberOTUs($tmpOTU,$OTUfa,$OTU_prefix);
#new algo 0.97: don't need to rename reads any longer (and keep track of this), done by sdm - but no backlinging to uparse any longer
#/////////////////////////////////////////  check for contaminants /////////////////////
my $OTUrefDBlnk;
if ( $exec == 0 && $onlyTaxRedo == 0 && $TaxOnly == 0 ) {

    #ITSx
    ITSxOTUs($OTUSEED);

    #phiX
    my $phiXcnt = 0;
	if ($doPhiX){
		$phiXcnt = contamination_rem( $OTUSEED, $CONT_REFDB_PHIX, "PhiX" );
	}

    #custom DB for contamination
    my $xtraContCnt = contamination_rem( $OTUSEED, $custContamCheckDB, "custom_DB" );

    #remove chimeras on longer merged reads
    my $refChims = chimera_rem( $OTUSEED, $OTUfa );

    #die $OTUrefSEED."\n";
    #link between OTU and refDB seq - replace with each other
    $OTUrefDBlnk = readLinkRefFasta( $OTUrefSEED . ".lnks" );

    #but OTU matrix already written, need to remove these
    $OTUrefDBlnk = clean_otu_mat($OTUfa,$OTUrefSEED, $OTUmFile,
        $OTUrefDBlnk, $phiXcnt,$xtraContCnt) if ($seedExtDone);    #&& $otuRefDB ne "ref_closed" );
        # $OTUfa.ref contains reference Seqs only, needs to be merged later..
        #and last check for cross talk in remaining OTU match
    checkXtalk( $OTUfa, $OTUmFile );
} elsif ($onlyTaxRedo) {
    printL "Skipping removal of contaminated OTUs step\n", 0;
}

# ////////////////////////// TAXONOMY ////////////////////////////////////////////
my $RDPTAX = 0;
my $REFTAX = 0;

my $msg = "";
$duration = time - $start;


my $rdpGene = "16srrna";
$rdpGene = "fungallsu" if ( $organism eq "fungi" || $organism eq "eukaryote" );
if ( $doRDPing > 0 && $mjar ne "" && -f $mjar ) {
    $msg = "Assigning taxonomy with multiRDP";

    #ampliconType
    $cmd = "java -Xmx1g -jar $mjar --gene=$rdpGene --format=fixrank --hier_outfile=$outdir/hierachy_cnt.tax --conf=0.1 --assign_outfile=$t/RDPotus.tax $OTUfa";
    $RDPTAX = 2;
} elsif ( $doRDPing > 0 && ( $rdpjar ne "" || exists( $ENV{'RDP_JAR_PATH'} ) ) ) {
    $msg = "Assigning taxonomy with RDP";
    my $toRDP = $ENV{'RDP_JAR_PATH'};
    if ( $rdpjar ne "" ) { $toRDP = $rdpjar; }
    my $subcmd = "classify";
    $cmd =
        "java -Xmx1g -jar " . $toRDP  . " $subcmd -f fixrank -g $rdpGene -h $outdir/hierachy_cnt.tax -q $OTUfa -o $t/RDPotus.tax -c 0.1";
    $RDPTAX = 1;
}    
$msg .= "\nelapsed time: $duration s";
if ( $doRDPing > 0 && $exec == 0 ) {    #ITS can't be classified by RDP
    printL frame($msg), 0;

    #die "XXX  $cmd\n";
    if ( systemL($cmd) ) {
        printL "FAILED RDP classifier execution:\n$cmd\n", 2;
    }
    $citations .= "RDP OTU taxonomy: Wang Q, Garrity GM, Tiedje JM, Cole JR. 2007. Naive Bayesian classifier for rapid assignment of rRNA sequences into the new bacterial taxonomy. Appl Env Microbiol 73: 5261–5267.\n";
} elsif ( $rdpjar ne "" || exists( $ENV{'RDP_JAR_PATH'} ) ) {
    if ($extendedLogs) { systemL "cp $t/RDPotus.tax $extendedLogD/"; }
    if ( $RDPTAX > 0 ) {                #move confusing files
        if ($extendedLogs) {
            systemL "mv $outdir/hierachy_cnt.tax $outdir/cnadjusted_hierachy_cnt.tax $extendedLogD/";
        } else {
            unlink "$outdir/hierachy_cnt.tax";
            unlink "$outdir/cnadjusted_hierachy_cnt.tax"
              if ( -e "$outdir/cnadjusted_hierachy_cnt.tax" );
        }
    }
}
#RDP finished 

#some warnings to throw
if ( !$doBlasting && substr( $ampliconType, 0, 3 ) eq "ITS" ) {
    my $failedBlastITS = "ITS region was chosen as target; this requires a similarity based taxonomic annotation and excludes RDP tax annotation.\n";
    $failedBlastITS .=       "Blast similarity based annotation is not possible due to: ";
    if ( !$doBlasting ) {
        $failedBlastITS .= "Similarity search being deactivated.";
    }
    elsif ( !-f $blastBin || !-f $lambdaBin ) {
        $failedBlastITS .= "Neither Lambda nor Blast binary being specified correctly";
    }
    elsif ( @TAX_REFDB == 0 || !-f $TAX_REFDB[0] ) {
        $failedBlastITS .= "Reference DB does not exist (@TAX_REFDB).\n";
    }
    $failedBlastITS .= "\nTherefore LotuS had to abort..\n";
    printL $failedBlastITS, 87;
}
if ($TaxOnly) {
    assignTaxOnly( $input, $outdir );
    printL "Taxonomy has been assigned to $input, output in $outdir\n", 0;
    exit(0);
}

#pre 0.97
#my $lnkHref="";
#my ($OTUmatref,$failsR) = makeAbundTable($taxblastf,"$t/RDPotus.tax",$A_UCfil,$OTUmFile,$lnkHref,\@avSmps);
my ( $OTUmatref, $avOTUsR ) = readOTUmat($OTUmFile);

#debug
#my %retMat = %{$OTUmatref};my @hdss = keys %retMat;my @fdfd = keys %{$retMat{bl21}};die "@hdss\n@fdfd\n$retMat{bl14}{OTU_1} $retMat{bl14}{OTU_2} $retMat{bl14}{OTU_3}\n";

#this subroutine also has blast/LCA algo inside
my ($failsR) = makeAbundTable2( "$t/RDPotus.tax", $OTUmatref );    #,\@avSmps);

if ( !-d $highLvlDir ) {
    if ( systemL("mkdir -p $highLvlDir") ) {
        printL("Could not create Higher level abundance matrix directory $highLvlDir.", 23);
    }
}
if ( !-d $FunctOutDir ) {
    if ( systemL("mkdir -p $FunctOutDir") ) {
        printL("Could not create Higher level abundance matrix directory $FunctOutDir.", 29);
    }
}
systemL("cp $OTUmFile $highLvlDir");
$duration = time - $start;
if ( $REFTAX || $RDPTAX ) {
	my $taxRefHR;
    my $table_dir = "$outdir/Tables";
    if ($REFTAX) {
        printL frame("Calculating Taxonomic Abundance Tables from @refDBname assignments\nelapsed time: $duration s"), 0;
        $taxRefHR = calcHighTax( $OTUmatref, $SIM_hierFile, $failsR, 1, $OTUmRefFile );
        biomFmt( $OTUmatref, $SIM_hierFile, "$outdir/OTU.biom", 1, {} );
        if ($pseudoRefOTU) {
            my ( $OTUmatref2, $avOTUsR2 ) = readOTUmat($OTUmRefFile);
            biomFmt( $OTUmatref2, $SIM_hierFile, "$outdir/OTU_psRef.biom", 1,
                $taxRefHR );
        }

    } elsif ($RDPTAX) {
        printL(frame("Calculating Taxonomic Abundance Tables from RDP \nclassifier assignments, Confidence $RDPCONF \nelapsed time: $duration s"),0);
        $taxRefHR = calcHighTax( $OTUmatref, $RDP_hierFile, $failsR, 0, "" );
        biomFmt( $OTUmatref, $RDP_hierFile, "$outdir/OTU.biom", 0, {} );
    }
	
	
	#   TODO 
	#annotate OTU's with functions
	#my $OTU2Funct = annotateFaProTax($taxRefHR,$FaProTax); #TODO
	#calcHighFunc($OTU2Funct,$FunctOutDir); #TODO
	

}

#merge in ref seq fastas
if ($REFflag) {
    systemL("cat $OTUfa.ref >> $OTUfa");
    unlink "$OTUfa.ref";
}

#building tree & MSA
$duration = time - $start;
if ( -f $clustaloBin && -f $fasttreeBin ) {
    printL( frame("Building tree and aligning OTUs\nelapsed time: $duration s"),
        0 );
    buildTree( $OTUfa, $outdir );
}
else {
    printL(
        frame(
"Skipping tree building and multiple alignment: \nclustaloBin or fasttreeBin are not defined\nelapsed time: $duration s"
        ),
        0
    );
}

#citations file
open O, ">$logDir/citations.txt";
print O $citations;
close O;

#print"\n".$repStr;
$duration = time - $start;
if ( $exec == 0 ) { printL "Delete temp dir $t\n", 0; systemL("rm -rf $t"); }
printL(
    frame(
"Finished after $duration s \nOutput files are in \n$outdir\nThe files in LotuSLogS/ have statistics about this run\nSee LotuSLogS/citations.txt for programs used in this run\nNext steps: you can use the rtk program in this pipeline, to generate rarefaction curves and diversity estimates of your samples.\n"
    ),
    0
);

printWarnings();

close LOG; close cmdLOG;











































#--------------------------############################----------------------------------###########################

sub printWarnings() {
    if ( $finalWarnings eq "" ) { return; }
    printL "The following WARNINGS occured:\n", 0;
    printL $finalWarnings. "\n", 0;
}

sub readLinkRefFasta() {
    my ($inF) = @_;
    my %ret;
    if ( !-e $inF ) { return \%ret; }
    open I, "<$inF";
    while ( my $line = <I> ) {
        chomp $line;
        my @spl = split( /\t/, $line );
        $ret{ $spl[0] } = $spl[1];
    }
    close I;

    #unlink $inF;
    return \%ret;
}

sub hexFasta($ $) {
    my ( $in, $out ) = @_;
}

sub loadFaProTax($){
	my $opt_db = $_[0];
	#my $DB = retrieve($opt_db);
	#return $DB;
}

sub ITSxOTUs {
    my ($otusFA) = @_;
    return unless ( substr( $ampliconType, 0, 3 ) eq "ITS" );
    return if ( !$doITSx );
    if ( !-e $itsxBin ) {
        printL "Did not find ITSx binary at $itsxBin\nNo ITS extraction used\n";
        return;
    }
    if ( !-e $hmmsrchBin ) {
        printL "Did not find hmmscan binary at $hmmsrchBin\nNo ITS extraction used\n";
        return;
    }

    my $outBFile = $otusFA . ".itsX";
    my $ITSxReg  = "ITS1,ITS2";
    if ( $ampliconType eq "ITS2" ) {
        $ITSxReg = "ITS2";
        printL "Setting to ITS2 region\n";
    }
    if ( $ampliconType eq "ITS1" ) {
        $ITSxReg = "ITS1";
        printL "Setting to ITS1 region\n";
    }
    my $itsxOrg = "all";
    $itsxOrg = "F" if ( lc($organism) eq "fungi" );

    #die "$itsxOrg\n";
    my $cmd = "$itsxBin -i $otusFA -o $outBFile -cpu $uthreads -t $itsxOrg --silent T --fasta T --save_regions $ITSxReg --partial $ITSpartial --hmmBin $hmmsrchBin\n";
    $cmd .= "cp $outBFile.summary.txt $logDir/ITSx.summary.txt\n";
    if ( systemL($cmd) != 0 ) { printL( "Failed command:\n$cmd\n", 1 ); }

#die $cmd;
#if (-z "$outBFile.full.fasta"){printL "Could not find any valid ITS OTU's. Aborting run.\n Remaining OTUs can be found in $outBFile*\n",923;}
    my $hr;
    my %ITSo;
	
	if ($ampliconType eq "ITS"){
        $hr   = readFasta("$outBFile.full.fasta");
        %ITSo = %{$hr};
    } else{
		if ( $ampliconType eq "ITS1" || $ampliconType eq "ITS" ) {
			$hr   = readFasta("$outBFile.ITS1.fasta");
			%ITSo = %{$hr};
		} 
		if ( $ampliconType eq "ITS2" || $ampliconType eq "ITS" ) {
			$hr   = readFasta("$outBFile.ITS2.fasta");
			%ITSo = ( %ITSo, %{$hr} );
		}
	}

    #my $ITSfa = `grep -c '^>' $outBFile.full.fasta`;
    my $orifa = `grep -c '^>' $otusFA`;
    chomp $orifa;    #chomp $ITSfa;
    if ( scalar( keys(%ITSo) ) == 0 ) {
        printL "Could not find any valid ITS OTU's. Aborting run.\n Remaining OTUs can be found in $outBFile*\n", 923;
    }

    printL "ITSx analysis: Kept " . scalar( keys(%ITSo) ) . " OTU's identified as $ITSxReg (of $orifa OTU's).\n";

    #systemL "cat $outBFile.full.fasta > $otusFA";
    open O, ">$otusFA" or die "Can't open output $otusFA\n";
    foreach my $k ( keys %ITSo ) {
        my $hdde = "OUTx_1";
		if ($k =~ m/^([z]?OTU_\d+)\|/){
			$hdde = $1;
		}

        #my @tspl = split/\|/,$k;
        #my $hdde = $tspl[0];
        #print "$hdde $k\n";
        print O ">$hdde\n$ITSo{$k}\n";
    }
    close O;
    systemL "rm -f $outBFile*";
    $citations .=
"ITSx removal of non ITS OTUs: ITSx: Johan Bengtsson-Palm et al. (2013) Improved software detection and extraction of ITS1 and ITS2 from ribosomal ITS sequences of fungi and other eukaryotes for use in environmental sequencing. Methods in Ecology and Evolution, 4: 914-919, 2013\n";

    #die $cmd."\n";
}

sub contamination_rem($ $ $ ) {
    my ( $otusFA, $refDB, $nameRDB ) = @_;
    my $outContaminated = "$otusFA.$nameRDB.fna";
    my $required        = 1;
    if ( $refDB eq "" ) { $required = 0; }
    systemL "rm -f $outContaminated" if ( -e $outContaminated );
    my $contRem = 0;

    #printL frame "Searching for contaminant OTUs with $nameRDB ref DB";
    if ( $refDB ne "" && -f $refDB && -s $otusFA ) {
        #die "hex seq to 50kb pieces\n";
        my $hexDB = $refDB;
        $hexDB .= ".lts.fna";
        if ( 0 && -s $refDB > 100000 ) {    #hex
            hexFasta( $refDB, $hexDB );
            $refDB = $hexDB;
        }
        my $hitsFile = $otusFA . ".cont_hit.uc";
        my @hits;
		if ($nameRDB ne "PhiX"){ #minimap2
			$hitsFile= "$otusFA.cont.paf";
			$cmd = "$mini2Bin -t $uthreads $otusFA $refDB > $hitsFile";
        } elsif ( $VSused == 0 ) { #deprecated
            $cmd = "$usBin -usearch_local $otusFA -db $refDB -uc $hitsFile -query_cov .8 -log $logDir/$nameRDB"
              . "_contami_align.log ";
            $cmd .= "-id .9 -threads $uthreads -strand both ";
        }
        else {
            $cmd = "$VSBin -usearch_local $otusFA -db $refDB --maxseqlength 99999999999 -uc $hitsFile --query_cov .8 -log $logDir/$nameRDB" . "_contami_align.log ";
            $cmd .= "-maxhits 1 -top_hits_only -strand both -id .9 -threads $uthreads --dbmask none --qmask none";    #.95
        }

        #die $cmd."\n";

        if ( systemL($cmd) != 0 ) { printL( "Failed command:\n$cmd\n", 1 ); }

        #create tmp
		if ($hitsFile =~ m/\.paf/){
			open I, "<", $hitsFile or die "Can't open search result file $hitsFile";
			while (<I>) {my @spl = split(/\t/);
				if ( $spl[9] > $spl[6] * 0.6 ) { push( @hits, $spl[5] ); $contRem++; }
			}
			close I;
		} else {
			open I, "<", $hitsFile or die "Can't open search result file $hitsFile";
			while (<I>) {my @spl = split(/\t/);
				if ( $spl[0] eq "H" ) { push( @hits, $spl[8] ); $contRem++; }
			}
			close I;
		}

        if ($contRem) {
            printL frame
              "Removed $contRem contaminated OTUs ($nameRDB ref DB).\n", 0;
        } else {return(0);}
        #die ("@hits\n");
        #report
        my $hr   = readFasta($otusFA);
        my %OTUs = %{$hr};

        #(add - deleted before) contaminated Fastas to file
        open O, ">>$outContaminated"
          or printL "Can't open contaminated OTUs file $outContaminated\n", 39;
        foreach my $hi (@hits) {
            print O ">" . $hi . "\n" . $OTUs{$hi} . "\n";
            delete $OTUs{$hi};
        }
        close O;

        #print remaining OTUs
        open O, ">$otusFA" or printL "Can't open OTUs file $otusFA\n", 39;
        foreach my $hi ( keys %OTUs ) {
            print O ">" . $hi . "\n" . $OTUs{$hi} . "\n";
        }
        close O;


        #if (($nonChimRm-$emptyOTUcnt)==0){
        #	printL "Empty OTU matrix.. aborting LotuS run!\n",87;
        #}
        #print "\n\n\n\n\n\nWARN DEBUG TODO .95 .45 $outContaminated\n";
    } elsif ($required) {
        my $warnStr = "Could not check for contaminated OTUs, because ";
        unless ( $refDB ne "" && -f $refDB ) {
            $warnStr .= "$nameRDB reference database \n\"$refDB\"\ndid not exist.\n";
        } else {  $warnStr .= "OTU fasta file was empty\n";
        }
        finWarn($warnStr);

        #systemL("cp $otusFA $outfile");
        #$outfile = "$t/uparse.fa";
    }
    return $contRem;
}

sub chimera_rem($ $) {
    my ( $otusFA, $outfile ) = @_;
    my $chimOut = "$t/chimeras_ref.fa";
    if ($extendedLogs) {
        $chimOut = "$extendedLogD/chimeras_ref.fa";
    }
    if (   $UCHIME_REFDB ne ""  && -f $UCHIME_REFDB && ( $noChimChk == 2 || $noChimChk == 0 ) )
    {
        printL "Could not find fasta otu file $otusFA. Aborting..\n", 33 unless ( -s $otusFA );
        $cmd = "$VSBin -uchime_ref  $otusFA -db $UCHIME_REFDB -strand plus -chimeras $chimOut -nonchimeras $outfile -threads $uthreads -log $logDir/uchime_refdb.log";
        if (!$useVsearch && $usearchVer >= 9 && !$VSused ) {
            $cmd = "$usBin -uchime2_ref  $otusFA -db $UCHIME_REFDB -mode balanced -strand plus -chimeras $chimOut -notmatched $outfile -threads $uthreads -log $logDir/uchime_refdb.log";
        }
        #die $cmd."\n";
        if ( systemL($cmd) != 0 ) { printL( "Failed command:\n$cmd\n", 1 ); }
        if ( $usearchVer >= 9 ) {
            $citations .= "uchime2 chimera detection deNovo: Edgar, R.C. (2016), UCHIME2: Improved chimera detection for amplicon sequences, http://dx.doi.org/10.1101/074252..\n";
        }
        elsif ( $VSused == 0 ) {
            $citations .= "uchime reference based chimera detection: Edgar RC, Haas BJ, Clemente JC, Quince C, Knight R. 2011. UCHIME improves sensitivity and speed of chimera detection. Bioinformatics 27: 2194–200.\n";
        }
        else {
            $citations .= "Vsearch reference based chimera detection: \n";
        }

        #print $outfile."\n";
        return $chimOut;
    }
    else {
		printL "No ref based chimera detection\n";
        systemL("cp $otusFA $outfile");
        #$outfile = "$t/uparse.fa";
    }
    return "";
}

sub checkXtalk($ $) {
    my ( $otuFA, $otuM ) = @_;
    if ( !$doXtalk ) { return; }
    if ( $usearchVer < 11 ) {
        printL
"cannot check for cross-talk, as only implemented in usearch version > 11\n",
          83;
    }
    my $otuM1 = $otuM . ".noXref";
    systemW "cp $otuM $otuM1";
    my $cmd =
"$usBin -otutab_xtalk $otuM1 -otutabout $otuM -report $logDir/crossTalk_analysis.txt\n";

    #get the OTUs that are not in both tables
    systemL $cmd;
    if ( -z "$logDir/crossTalk_analysis.txt" ) {
        printL "Cross talk unsuccessful\n";
        systemL "rm $otuM; mv $otuM1 $otuM;";
    }
    else {
        $citations .=
"CrossTalk OTU removal: UNCROSS2: identification of cross-talk in 16S rRNA OTU tables. Robert C. Edgar . Bioarxiv (https://www.biorxiv.org/content/biorxiv/early/2018/08/27/400762.full.pdf)\n";
    }
}

#remove entries from OTU matrix
sub clean_otu_mat($ $ $ $ $) {
    my ( $OTUfa, $OTUrefFa, $OTUmFile, $OTUrefDBlnk, $phiXCnt, $xtraContCnt ) = @_;

    #search for local matchs of chimeras in clean reads
    #TODO
    #get headers of OTUs
    my $hr  = readFasta($OTUfa);
    my %hds = %{$hr};
    my $cnt = -1;

    #my @kkk =  keys %hds; die scalar @kkk ."\n";
    $hr = readFasta($OTUrefFa);
    my %refHds = %{$hr};
    my %ORDL   = %{$OTUrefDBlnk};
    my %ORDL2;
    my $chimRm      = 0;
    my $nonChimRm   = 0;
    my $chimRdCnt   = 0;
    my $emptyOTUcnt = 0;
    my %OTUcnt;
    my %OTUmat;

    #die "$OTUmFile\n$OTUfa\n";
    open I, "<$OTUmFile";
    if ($extendedLogs) {
        open O2x, ">$extendedLogD/otu_mat.chim.txt"
          or printL "Failed to open $extendedLogD/otu_mat.chim.txt", 33;
    }
    while ( my $line = <I> ) {
        $cnt++;
        chomp $line;
        if ( $cnt == 0 ) {
            $OTUmat{head} = $line;
            if ($extendedLogs) { print O2x $line . "\n"; }
            next;
        }
        my @spl = split( /\t/, $line );
        my $ot  = shift @spl;

        #my $position = index($line, "\t");
        #my $ot = substr $line,0,$position;
        #die $ot."\n";
        my $rdCnt = 0;

        #specific OTU read count
        if ( exists( $hds{$ot} ) || exists( $refHds{$ot} ) )
        {    #exists in non-chimeric set or ref DB set
            $rdCnt += $_ for @spl;
            if ( $rdCnt == 0 ) {

                #print "$ot";
                delete $hds{$ot};
                $emptyOTUcnt++;
            }
            else {
                $OTUcnt{$ot} = $rdCnt;
                $OTUmat{$ot} = join( "\t", @spl );

                #print O $line;
            }
            $nonChimRm++;
        }
        else {
            print $ot."\n";
            #die $line."\n";
            $chimRm++;    #don't include
            if ($extendedLogs) { print O2x $line . "\n"; }
            $chimRdCnt += $_ for @spl;
        }
    }
    close I;

    if ($extendedLogs) { close O2x; }

    #print resorted OTU matrix
    open OF,  ">$OTUfa";
    open OFR, ">$OTUfa.ref";
    open O,   ">$OTUmFile.tmp";
    print O $OTUmat{head} . "\n";
    my %newOTUs;

    #my @tmp= values %OTUcnt;
    #print "@tmp\n";
    my @sorted_otus = ( sort { $OTUcnt{$b} <=> $OTUcnt{$a} } keys %OTUcnt )
      ;    #sort(keys(%OTUcnt));
    my $OTUcntd = 1;    # my $maxOTUdig = length (keys %OTUcnt)
    foreach my $ot (@sorted_otus) {

        #$newOname = sprintf("%08d", $OTUcnt);
        my $newOname = $OTU_prefix . $OTUcntd;
        $OTUcntd++;
        print O $newOname . "\t" . $OTUmat{$ot} . "\n";
        if ( exists( $hds{$ot} ) ) {
            print OF ">" . $newOname . "\n" . $hds{$ot};

            #$newOTUs{$newOname} = $hds{$ot}
        }
        elsif ( exists( $refHds{$ot} ) ) {
            print OFR ">" . $newOname . "\n" . $refHds{$ot};
            $ORDL2{$newOname} = $ORDL{$ot};

            #die ("new:".$ORDL2{$newOname}."  old: ".$ORDL{$ot}."\n");
        }
        else {
            printL "Fatal error, cannot find OTU $ot\n", 87;
        }
    }
    close O;
    close OF;
    close OFR;
    if ( !$REFflag ) { unlink "$OTUfa.ref"; }

    #die $OTUmFile."\n";
    unlink $OTUmFile;
    rename "$OTUmFile.tmp", $OTUmFile;

    #writeFasta(\%newOTUs,$OTUfa);
	my $chimTag = "chimeric";
	$chimTag .= "/ITSx" if ($doITSx);
    if ($chimRm) {
        my $strTmp =
          "Removed " . ( $chimRm - $phiXCnt - $xtraContCnt ) . " $chimTag\n";
        $strTmp .= "and " . $phiXCnt . " phiX contaminant\n"
          if ( 1 || $phiXCnt > 0 );
        $strTmp .= "and " . $xtraContCnt . " contaminants from custom DB\n"
          if ( $xtraContCnt > 0 );
        $strTmp .=
            "OTUs ($chimRdCnt read counts) from abundance matrix, \n"
          . $nonChimRm
          . " OTUs remaining.\n", 0;
        printL frame($strTmp), 0;
    }
    if ( ( $nonChimRm - $emptyOTUcnt ) == 0 ) {

        #print "$nonChimRm - $emptyOTUcnt\n";
        printL "Empty OTU matrix.. aborting LotuS run!\n", 87;
    }
    if ( $emptyOTUcnt > 0 ) {
        printL "Removed mismapped OTUs ($emptyOTUcnt)..\n", 0;
    }
    return \%ORDL2;
}

sub forceMerge_fq2fna($ $ $ $ $) {
    my ( $ifq1, $ifq2, $mfq, $sdms, $out ) = @_; #not merged1, 2, merged, sdm sing, SEEDFNA
	my $seedCnt = 0;
    #print $mfq."\n";
    open O, ">", $out or die "Can't open seedFNA $out\n";
    my $hd    = "";
    my $lnCnt = 0;

    #check for rev adaptors
    my $check4endStr = 0;
    my $endRmvs      = "";
    if ( $remFromEnd ne "" ) {
        $check4endStr = 1;
        my @spl = split( /,/, $remFromEnd );
        $endRmvs .= $spl[0] . '.*$';
        for ( my $i = 1 ; $i < @spl ; $i++ ) {
            $endRmvs .= "|" . $spl[$i] . '.*$';
        }

        #print $remFromEnd."  C ".$endRmvs."\n";
        #$rawFileSrchStr1 = '.*1\.f[^\.]*q\.gz$';
    }
#main file with merged reads
	if (-s $mfq){
		open I, "<", $mfq;
		while ( my $line = <I> ) {
			chomp $line;
			if ( $line =~ m/^@/ && $lnCnt == 0 ) {
				$line =~ s/^@/>/;
				$line =~ s/.\d$//;
				print O $line . "\n"; $seedCnt++;
			}
			if ( $lnCnt == 1 ) {
				$line =~ s/$endRmvs// if ($check4endStr);
				print O $line . "\n";
			}
			$lnCnt++;
			$lnCnt = 0 if ( $lnCnt == 4 );
		}
		close I;
	}

    #merge two unmerged reads
    $lnCnt = 0;

    #print $ifq1."\n";
	if (-s $ifq1){
		open I,  "<", $ifq1;
		open I2, "<", $ifq2;
		while ( my $line = <I> ) {
			my $line2 = <I2>;
			chomp $line;
			chomp $line2;
			if ( $line =~ m/^@/ && $lnCnt == 0 ) {
				$line =~ s/^@/>/;
				$line =~ s/.\d$//;

				#print $line."\n";
				print O $line . "\n"; $seedCnt++;
			}
			if ( $lnCnt == 1 ) {
				$line =~ s/$endRmvs// if ($check4endStr);
				print O $line . "\n";    #."NNNN".$line2."\n";
			}
			$lnCnt++;
			$lnCnt = 0 if ( $lnCnt == 4 );
		}
		close I;
		close I2;
	}
    if ( !-f $sdms ) { close O; return; }
    open I, "<", $sdms;
    $lnCnt = 0;
    while ( my $line = <I> ) {
        chomp $line;
        if ( $line =~ m/^@/ && $lnCnt == 0 ) {
            $line =~ s/$endRmvs// if ($check4endStr);
            $line =~ s/^@/>/;
            $line =~ s/.\d$//;
            print O $line . "\n";$seedCnt++;
        }
        if ( $lnCnt == 1 ) {
            print O $line . "\n";
        }
        $lnCnt++;
        $lnCnt = 0 if ( $lnCnt == 4 );
    }

    close I;
    close O;
	printL "Found $seedCnt fasta seed sequences based on seed extension and read merging\n";
}

sub readTaxIn($ $ $ $ ) {
    my ( $inT, $LCAtax, $biomFmt, $calcHit2DB ) = @_;
    my %Taxo;    #
    my @lvls =
      ( "Domain", "Phylum", "Class", "Order", "Family", "Genus", "Species" );
    my @lvls2 = ( "k__", "p__", "c__", "o__", "f__", "g__", "s__" );
    my %hit2DB;
    my %hit2DBtax;
    my $taxStart   = 0;    #RDP case
    my $taxEnd     = 7;
    my $tarEntr    = 7;
    my $hit2DBEntr = 8;

    if ( $LCAtax == 1 ) {    #LCA case
        $taxStart = 1;
        $taxEnd   = 8;
        $tarEntr  = 0;
        unshift @lvls,  "OTU";
        unshift @lvls2, "";
    }
    open I, "<", $inT or die("$inT not found: $!\n");
    my $markLvl = -1;
    my $cnt     = -1;
    while ( my $line = <I> ) {
        chomp($line);
        $cnt++;
        my @spl = split( /\t/, $line );
        if ( $cnt == 1 && $markLvl == -1 ) {
            $markLvl = 0;
            $markLvl = 1 unless ( $spl[0] =~ m/[kpc]__/ );
        }
        for ( my $i = 0 ; $i < @spl ; $i++ ) {
            $spl[$i] = "?" if ( $spl[$i] eq "" );
        }
        next
          if ( $cnt == 0 )
          ; #|| $spl[0] eq "domain" || $spl[0] eq "Domain" || $spl[0] eq "OTU");
            #phylum unknown: ignore entry
            #if ($spl[1] eq "?" && $spl[2] eq "?"){next;}
        if ( @spl < 6 ) { die $line; }
        if ( $markLvl == 1 && $biomFmt == 1 ) {    #add k__ etc tags
            for ( my $i = 0 ; $i < @lvls2 ; $i++ ) {
                chomp $spl[$i];
                $spl[$i] = $lvls2[$i] . $spl[$i];
            }
        }
        if ( $biomFmt == 1 ) {                     #simple joining of levels
                #print ("@spl $taxStart .. $taxEnd\n");
            $Taxo{ $spl[$tarEntr] } =
              join( "\", \"", @spl[ $taxStart .. ( $taxEnd - 1 ) ] );
        }
        else {    #complex add up of levels
            my $foreRun = $spl[$taxStart];
            for ( my $i = $taxStart + 1 ; $i < $taxEnd ; $i++ ) {
                my $tartax = $foreRun . ";" . $spl[$i];
                if ( exists( $Taxo{ $lvls[$i] }{$tartax} ) ) {
                    push( @{ $Taxo{ $lvls[$i] }{$tartax} }, $spl[$tarEntr] );
                }
                else {
                    my @tmp = ( $spl[$tarEntr] );
                    $Taxo{ $lvls[$i] }{$tartax} = \@tmp;
                }
                $foreRun = $tartax;
            }
        }

        #prepare tag for greengenes hit
        if ($calcHit2DB) {
            if ( $spl[$hit2DBEntr] ne "?" ) {

                #previous one link.. no longer needed
                #$hit2DB{$spl[$tarEntr]} = $spl[$hit2DBEntr];}
                if ( exists( $hit2DB{ $spl[$hit2DBEntr] } ) ) {
                    push( @{ $hit2DB{ $spl[$hit2DBEntr] } }, $spl[$tarEntr] );
                }
                else {
                    my @tmp = ( $spl[$tarEntr] );
                    $hit2DB{ $spl[$hit2DBEntr] } = \@tmp;
                }

                #for bioim format, need to change the lvls
                if ( $markLvl == 1 ) {
                    for ( my $i = 0 ; $i < @lvls2 ; $i++ ) {
                        chomp $spl[$i];
                        $spl[$i] = $lvls2[$i] . $spl[$i];
                    }
                }
                $hit2DBtax{ $spl[$hit2DBEntr] } =
                  join( "\", \"", @spl[ $taxStart .. ( $taxEnd - 1 ) ] )
                  ;    #in biom format

            }
            else { $hit2DB{ $spl[$tarEntr] } = [ $spl[$tarEntr] ]; }
        }
    }
    close I;

    #create high  lvl matrix
    if ( $LCAtax == 1 ) {    #LCA case
        shift @lvls;
        shift @lvls2;
    }
    return ( \%Taxo, \@lvls, \%hit2DB, \%hit2DBtax );
}

sub biomFmt($ $ $ $ $) {
    my ( $otutab, $inT, $bioOut, $LCAtax, $bioTaxXHR ) = @_;

    if (0) {                 #$combineSamples==1){
        open O, ">$bioOut.not";
        print O
"Samples are being combined; biom format is not supported by LotuS in this case\n";
        close O;
        printL
"Samples are being combined; biom format is not supported by LotuS in this case\n";
        return;
    }
    my %bioTaxX = %{$bioTaxXHR};
    my %mapH    = %{$mapHref};
    my %combH   = %{$combHref};
    if ($hasCombiSmpls) {
        printL
"Combined samples in lotus run.. attempting merge of metadata in .biom file\n",
          "w";
    }
    my $otutab2 = $t . "/OTUpTax_tmp.txt";
    my %OTUmat  = %{$otutab};
    my @avSmps  = sort( keys %OTUmat );
    my @avOTUs  = sort( keys %{ $OTUmat{ $avSmps[0] } } );

    #die "@avSmps\n";
    my @colNms = @{ $mapH{'#SampleID'} };

    #my @lvls = ("Domain","Phylum","Class","Order","Family","Genus","Species");

   # read tax normal in every case, hit2DB would be the new OTU IDs, if required
    my ( $hr1, $ar1, $hr2, $hr3 ) =
      readTaxIn( $inT, $LCAtax, 1, 0 );    #hr3 not used here
    my %Tax    = %{$hr1};
    my %hit2db = %{$hr2};                  #my @lvls = @{$ar1};

    my ( $sec, $min, $hour, $mday, $mon, $year, $wday, $yday, $isdst ) =
      gmtime();
    my $biomo =
"{\n \"id\":null,\n \"format\": \"Biological Observation Matrix 0.9.1-dev\",
	 \"format_url\": \"http://biom-format.org/documentation/format_versions/biom-1.0.html\",
	 \"type\": \"OTU table\",
	 \"generated_by\": \"$selfID\",
	 \"date\": \"" . sprintf( "%04d-%02d-%02d", $year + 1900, $mon, $mday ) . "T";

    #$biomo .= sprintf("%04d-%02d-%02d", $year,$mon,$mday);
    $biomo .= sprintf( "%02d:%02d:%02d", $hour, $min, $sec );
    $biomo .= "\",\n \"rows\":[\n";

#    {"id":"GG_OTU_1", "metadata":{"taxonomy":["k__Bacteria", "p__Proteobacteria", "c__Gammaproteobacteria", "o__Enterobacteriales", "f__Enterobacteriaceae", "g__Escherichia", "s__"]}},

    my $cnt = 0;
    foreach my $id (@avOTUs) {
        $cnt++;

        #print $id."\n";
        my $taxstr;
        my $id2 = $id;

        if ( exists( $Tax{$id} ) ) {
            $taxstr = $Tax{$id};
        }
        elsif ( exists( $bioTaxX{$id} ) ) {

            #print "Heureka! $bioTaxX{$id}\n $id\n";
            $taxstr = $bioTaxX{$id};

            #if ($replOTUids4Hit){$id2 = $hit2db{$id};}
        }
        else {
            $taxstr =
"k__?\", \"p__?\", \"c__?\", \"o__?\", \"f__?\", \"g__?\", \"s__?";
        }
        if ( $cnt > 1 ) {
            $biomo .=
                ",\n            {\"id\":\""
              . $id2
              . "\", \"metadata\":{\"taxonomy\":[\""
              . $taxstr . "\"]}}";
        }
        else {
            $biomo .=
                "            {\"id\":\""
              . $id2
              . "\", \"metadata\":{\"taxonomy\":[\""
              . $taxstr . "\"]}}";
        }
    }
    $biomo .= "\n],\n \"columns\":[\n";

   #             {"id":"Sample1", "metadata":null},
   #   {"id":"Sample1", "metadata":{
   #                             "BarcodeSequence":"CGCTTATCGAGA",
   #                             "LinkerPrimerSequence":"CATGCTGCCTCCCGTAGGAGT",
   #                             "BODY_SITE":"gut",
   #                             "Description":"human gut"}},
   #    {"id":"Sample2", "metadata":{

    $cnt = 0;

    #print $avSmps[0]."\n";
    foreach my $smpl (@avSmps) {
        my $prepMeta = "{\n                             ";    #"null";
                                                              #print $smpl."\n";
        my @curMeta  = @{ $mapH{ $combH{$smpl} } };

        my $cnt2 = -1;
        foreach my $cn (@colNms) {
            $cnt2++;
            $prepMeta .= ",\n                             " if ( $cnt2 > 0 );
            $prepMeta .= "\"" . $cn . "\":\"" . $curMeta[$cnt2] . "\"";
        }
        $prepMeta .= "}";
        $cnt++;
        if ( $cnt > 1 ) {
            $biomo .=
                ",\n            {\"id\":\""
              . $smpl
              . "\", \"metadata\":$prepMeta}";
        }
        else {    #cnt==1
            $biomo .=
              "            {\"id\":\"" . $smpl . "\", \"metadata\":$prepMeta}";
        }
    }
    my $rnum = scalar(@avOTUs);
    my $cnum = scalar(@avSmps);

    $biomo .=
"],\n\"matrix_type\": \"dense\",\n    \"matrix_element_type\": \"int\",\n    \"shape\": ["
      . $rnum . ","
      . $cnum . "],
		\"data\":  [";
    $cnt = 0;
    foreach my $otu (@avOTUs) {
        $cnt++;
        if ( $cnt == 1 ) {
            $biomo .= "[";
        }
        else {
            $biomo .= ",\n[";
        }
        my $cnt2 = 0;
        foreach my $smpl (@avSmps) {
            $cnt2++;
            if ( exists( $OTUmat{$smpl}{$otu} ) ) {
                if ( $cnt2 == 1 ) {
                    $biomo .= $OTUmat{$smpl}{$otu};
                }
                else {
                    $biomo .= "," . $OTUmat{$smpl}{$otu};
                }
            }
            else {
                #print "$smpl  $otu\n";
                if   ( $cnt2 == 1 ) { $biomo .= "0"; }
                else                { $biomo .= ",0"; }
            }
        }
        $biomo .= "]";
    }

    $biomo .= "]\n}";
    open O, ">", $bioOut;
    print O $biomo;
    close O;
    printL frame("biom file created: $bioOut"), 0;

#die;
#my $cmd = "biom convert -i $otutab2 -o $bioOut --table-type \"otu table\" --process-obs-metadata taxonomy";
}

sub truePath($){
	my ($tmp) = @_;
	$tmp = `which $tmp 2>/dev/null`;chomp($tmp);
	$tmp="" if ($tmp =~ /^which: no/);
	return $tmp;
}

sub readPaths_aligners() {
    my ($inF) = @_;
    die("$inF does not point to a valid lotus configuration\n")
      unless ( -f $inF );
	  #die "$inF\n";
	$Rscript = truePath("Rscript");
    open I, "<", $inF;
    while ( my $line = <I> ) {
        chomp $line;
        next if ( $line =~ m/^#/ );
        next if ( length($line) < 5 );    #skip empty lines
        $line =~ s/\"//g;
        if ( $line =~ m/^usearch\s(\S+)/ ) {
            $usBin = truePath($1);
        }
		elsif ( $line =~ m/^dada2R\s+(\S+)/ ) {
            $dada2Scr = $1;
			#die $dada2Scr;
        }
        elsif ( $line =~ m/^vsearch\s+(\S+)/ ) {
            $VSBin = truePath($1);
            $VSBinOri = truePath($1);  #deactivate default vsearch again.. prob with chimera finder.
        }
        elsif ( $line =~ m/^LCA\s+(\S+)/ ) {
            $LCABin = truePath($1);
        }
        elsif ( $line =~ m/^multiRDPjar\s+(\S+)/ ) {
            $mjar = truePath($1);
        }
        elsif ( $line =~ m/^RDPjar\s+(\S+)/ ) {
            $rdpjar = truePath($1);
        }
        elsif ( $line =~ m/^blastn\s+(\S+)/ ) {
            $blastBin = truePath($1);
        }
        elsif ( $line =~ m/^makeBlastDB\s+(\S+)/ ) {
            $mkBldbBin = truePath($1);
        }
        elsif ( $line =~ m/^clustalo\s+(\S+)/ ) {
            $clustaloBin = truePath($1);
        }
        elsif ( $line =~ m/^fasttree\s+(\S+)/ ) {
            $fasttreeBin = truePath($1);
        }
        elsif ( $line =~ m/^sdm\s+(\S+)/ ) {
            $sdmBin = truePath($1);
        }
        elsif ( $line =~ m/^flashBin\s+(\S+)/ ) {
            $flashBin = truePath($1);
        }
        elsif ( $line =~ m/^swarm\s+(\S+)/ ) {
            $swarmBin = truePath($1);
        }
        elsif ( $line =~ m/^cd-hit\s+(\S+)/ ) {
            $cdhitBin = truePath($1);
        }
        elsif ( $line =~ m/^dnaclust\s+(\S+)/ ) {
            $dnaclustBin = truePath($1);
        }
        elsif ( $line =~ m/^minimap2\s+(\S+)/ ) {
            $mini2Bin = truePath($1);
        }
        elsif ( $line =~ m/^lambda\s+(\S+)/ ) {
            $lambdaBin = truePath($1);
        }
        elsif ( $line =~ m/^lambda_index\s+(\S+)/ ) {
            $lambdaIdxBin = truePath($1);
        }
        elsif ( $line =~ m/^itsx\s+(\S+)/ ) {
            $itsxBin = truePath($1);
        }
        elsif ( $line =~ m/^hmmsearch\s+(\S+)/ ) {
            $hmmsrchBin = truePath($1);
        }
        elsif ( $line =~ m/^CheckForUpdates\s+(\S+)/ ) {
            $checkForUpdates = $1;
        }
    }

    #check that usearch is execuatble
    if ( $doBlasting == 3 && !-f $usBin ) {
        printL "UTAX tax classification requested, but no usearch binary found at $usBin\nAborting..\n", 93;
    }
    if ( -f $usBin && !-X $usBin ) {
        printL "It seems like your usearch binary is not executable, attempting to change this (needs sufficient user rights)\n",0;
        printL "Failed \"chmod +x $usBin\"\n"  if ( systemL "chmod +x $usBin" ), 33;
    }
	if ($LCABin eq "" || $sdmBin eq ""){
		printL "Essential sdm/LCA programs are not found, please check that these are in the locations given in lOTUs.cfg\n",28;
	}
	#die;
}

#read database paths on hdd
sub readPaths() {    #read tax databases and setup correct usage
    my ($inF) = @_;
    die("$inF does not point to a valid lotus configuration\n")
      unless ( -f $inF );
    open I, "<", $inF;
    my $TAX_REFDB_GG        = "";
    my $GGinfile            = "";
    my $TAX_REFDB_SLV       = "";
    my $SLVinfile           = "";
    my $TAX_REFDB_SLV_LSU   = "";
    my $SLVinfile_LSU       = "";
    my $UCHIME_REFssu       = "";
    my $UCHIME_REFlsu       = "";
    my $UCHIME_REFits       = "";
    my $UCHIME_REFits2      = "";
    my $UCHIME_REFits1      = "";
    my $TAX_RANK_ITS_UNITE  = "";
    my $TAX_REFDB_ITS_UNITE = "";
    my $TAX_UTAX_ITS        = "";
    my $TAX_UTAX_16S        = "";
    my $TAX_REFDB_16S_HITdb = "";
    my $TAX_RANK_16S_HITdb  = "";
    my $TAX_REFDB_16S_PR2   = "";
    my $TAX_RANK_16S_PR2    = "";
    my $TAX_REFDB_BT        = "";
    my $TAX_RANK_16S_BT     = "";

    while ( my $line = <I> ) {
        chomp $line;
        next if ( $line =~ m/^#/ );
        next if ( length($line) < 5 );    #skip empty lines
        $line =~ s/\"//g;

        #databases
        #$UCHIME_REFits $TAX_RANK_ITS_UNITE $TAX_REFDB_ITS_UNITE
        if ( $line =~ m/^UCHIME_REFDB\s+(\S+)/ ) {
            $UCHIME_REFssu = $1;
        }
        elsif ( $line =~ m/^UCHIME_REFDB_LSU\s+(\S+)/ ) {
            $UCHIME_REFlsu = $1;
        }
        elsif ( $line =~ m/^FAPROTAXDB\s+(\S+)/ ) {
            my $FaProTaxDBfile = $1;
			$FaProTax = loadFaProTax($FaProTaxDBfile);
        }
        elsif ( $line =~ m/^UCHIME_REFDB_ITS\s+(\S+)/ ) {
            $UCHIME_REFits = $1;
        }
        elsif ( $line =~ m/^UCHIME_REFDB_ITS1\s+(\S+)/ ) {
            $UCHIME_REFits1 = $1;
        }
        elsif ( $line =~ m/^UCHIME_REFDB_ITS2\s+(\S+)/ ) {
            $UCHIME_REFits2 = $1;
        }
        elsif ( $line =~ m/^TAX_REFDB_GG\s+(\S+)/ ) {
            $TAX_REFDB_GG = $1;
        }
        elsif ( $line =~ m/^TAX_RANK_GG\s+(\S+)/ ) {
            $GGinfile = $1;
        }
        elsif ($line =~ m/^TAX_REFDB_SSU_SLV\s+(\S+)/
            || $line =~ m/^TAX_REFDB_SLV\s+(\S+)/ )
        {
            $TAX_REFDB_SLV = $1;
        }
        elsif ($line =~ m/^TAX_RANK_SSU_SLV\s+(\S+)/
            || $line =~ m/^TAX_RANK_SLV\s+(\S+)/ )
        {
            $SLVinfile = $1;
        }
        elsif ( $line =~ m/^TAX_REFDB_LSU_SLV\s+(\S+)/ ) {
            $TAX_REFDB_SLV_LSU = $1;
        }
        elsif ( $line =~ m/^TAX_RANK_LSU_SLV\s+(\S+)/ ) {
            $SLVinfile_LSU = $1;
        }
        elsif ( $line =~ m/^TAX_REFDB_ITS_UNITE\s+(\S+)/ ) {
            $TAX_REFDB_ITS_UNITE = $1;
        }
        elsif ( $line =~ m/^TAX_RANK_ITS_UNITE\s+(\S+)/ ) {
            $TAX_RANK_ITS_UNITE = $1;

            #HITdb
        }
        elsif ( $line =~ m/^TAX_RANK_HITdb\s+(\S+)/ ) {
            $TAX_RANK_16S_HITdb = $1;
        }
        elsif ( $line =~ m/^TAX_REFDB_HITdb\s+(\S+)/ ) {
            $TAX_REFDB_16S_HITdb = $1;

            #PR2
        }
        elsif ( $line =~ m/^TAX_RANK_PR2\s+(\S+)/ ) {
            $TAX_RANK_16S_PR2 = $1;
        }
        elsif ( $line =~ m/^TAX_REFDB_PR2\s+(\S+)/ ) {
            $TAX_REFDB_16S_PR2 = $1;

            #bee tax
        }
        elsif ( $line =~ m/^TAX_RANK_BEE\s+(\S+)/ ) {
            $TAX_RANK_16S_BT = $1;
        }
        elsif ( $line =~ m/^TAX_REFDB_BEE\s+(\S+)/ ) {
            $TAX_REFDB_BT = $1;

            #UTAX
        }
        elsif ( $line =~ m/^TAX_REFDB_ITS_UTAX\s+(\S+)/ ) {
            $TAX_UTAX_ITS = $1;
        }
        elsif ( $line =~ m/^TAX_REFDB_SSU_UTAX\s+(\S+)/ ) {
            $TAX_UTAX_16S = $1;

            #ref DB for PhiX conatminations
        }
        elsif ( $line =~ m/^REFDB_PHIX\s+(\S+)/ ) {
            $CONT_REFDB_PHIX = $1;
        }
        elsif ( $line =~ m/^IdentityThresholds\s+(\S+)/ ) {
            my @spl = split( /,/, $1 );
            if ( scalar(@spl) == 6 ) {
                push( @spl, 0 );
            }
            if ( scalar(@spl) == 7 ) {
                for ( my $i = 0 ; $i < @spl ; $i++ ) {
                    if ( $spl[$i] > 100 || $spl[$i] < 0 ) {
                        print
"Error reading \"IdentityThresholds\" from configuration file: every entry has to be <100 and >0. Found "
                          . $spl[$i] . ".\n";
                        exit(22);
                    }
                    $idThr[$i] = $spl[$i];
                }
            }
            else {
                printL
"Error reading \"IdentityThresholds\" from configuration file: has to contain 6 levels seperated by \",\".\n",
                  23;
            }

            #die "@idThr\n";
        }
    }
    close I;
    if ( !-e $usBin && !-e $rdpjar && !-e $sdmBin ) {
        printL
"\nWARNING:: Several essential auxiliary programs are missing: you can always install these and configure into your lotus installation by excecuting ./autoinstall.pl\n\n",
          0;
    }

    $UCHIME_REFDB = $UCHIME_REFssu;
    if ( $ampliconType eq "LSU" ) {
        $UCHIME_REFDB = $UCHIME_REFlsu;
    }
    elsif ( $ampliconType eq "ITS" ) {
        $UCHIME_REFDB = $UCHIME_REFits;
    }
    elsif ( $ampliconType eq "ITS2" ) {
        $UCHIME_REFDB = $UCHIME_REFits2;
    }
    elsif ( $ampliconType eq "ITS1" ) {
        $UCHIME_REFDB = $UCHIME_REFits1;
    }
    if ( !-e $UCHIME_REFDB ) {
        finWarn
"Requested DB for uchime ref at\n$UCHIME_REFDB\ndoes not exist; LotuS will run without reference based OTU chimera checking.\n";
    }

    if (   ( $refDBwanted !~ m/SLV/ && $refDBwanted !~ m/PR2/ )
        && $ampliconType eq "LSU"
        && !-f $refDBwanted )
    {
        printL
"-refDB \"GG\" does not contain taxonomic infomation for amplicon type $ampliconType \n switchung to \"SLV\".\n",
          0;
        $refDBwanted = "SLV";
    }

    #die $refDBwanted."$doBlasting\n";
    #printL "XX\nXX\n",0;
    if ( $doBlasting > 0 ) {
        #set up default paths
        if ( $doBlasting == 3 ) {
            $refDBwanted = "UTAX";
            if ( $usearchVer < 8.1 ) {
                printL "Your usearch version ($usearchVer) is not compatible with utax, please upgrade: http://www.drive5.com/usearch/\n",63;
            }
            if ( $usearchVer >= 9 ) {
                printL "Please use usearch ver 8 for now, if you want to use utax\n", 22;
            }
        }
        elsif ($defDBset) {
            if ( !-f $TAX_REFDB_GG && $refDBwanted eq "GG" ) {
                $refDBwanted = "SLV";
            }
        }
        for my $subrdbw ( split /,/, $refDBwanted ) {

            #print $subrdbw."\n";
            if ( -f $subrdbw ) {    #custom DB
                push @refDBname, "custom";
                push( @TAX_REFDB, $subrdbw );
                if ( $refDBwantedTaxo eq "" ) {
                    printL
"Please provide a taxonomy file for custom ref DB @TAX_REFDB\n",
                      45;
                }
                elsif ( !-f $refDBwantedTaxo ) {
                    printL
"Taxonomy file for custom ref DB $refDBwantedTaxo does not exist\n",
                      45;
                }
                push @TAX_RANKS, $refDBwantedTaxo;
                next;
            }
            $subrdbw = uc $subrdbw;
            if ( $subrdbw =~ m/^UTAX$/ ) {    #utax algo
                push @refDBname, "UTAX";
                if ( substr( $ampliconType, 0, 3 ) eq "ITS" ) {
                    push( @TAX_REFDB, $TAX_UTAX_ITS );
                }
                else {
                    push( @TAX_REFDB, $TAX_UTAX_16S );
                }
            }
            if ( $subrdbw =~ m/^UNITE$/
                || substr( $ampliconType, 0, 3 ) eq "ITS" )
            {                                 #overrides everything else
                printL "Using UNITE ITS ref seq database.\n", 0;
                $ampliconType =
                  "ITS";    #unless (substr($ampliconType,0,3) eq "ITS");
                push @TAX_REFDB, $TAX_REFDB_ITS_UNITE;
                push @TAX_RANKS, $TAX_RANK_ITS_UNITE;
                if ( !-f $TAX_REFDB[-1] || !-f $TAX_RANKS[-1] ) {
                    printL
"Could not find UNITE ITS DB files at \n$TAX_REFDB[-1]\n$TAX_RANKS[-1]\nPlease check that these files exist.\n",
                      55;
                }
                push @refDBname, "UNITE";
                $subrdbw = "";
                $citations .=
"UNITE ITS chimera DB - Nilsson et al. 2015. A comprehensive, automatically updated fungal ITS sequence dataset for reference-based chimera control in environmental sequencing efforts. Microbes and Environments. \n";
                $citations .=
"UNITE ITS taxonomical refDB - Koljalg, Urmas, et al. Towards a unified paradigm for sequence-based identification of fungi. Molecular Ecology 22.21 (2013): 5271-5277.\n";
            }
            if ( $subrdbw =~ m/^HITDB$/ ) {
                push @TAX_REFDB, $TAX_REFDB_16S_HITdb;
                push @TAX_RANKS, $TAX_RANK_16S_HITdb;
                push @refDBname, "HITdb";
                if ( !-f $TAX_REFDB[-1] || !-f $TAX_RANKS[-1] ) {
                    printL
"Could not find HITdb files at \n$TAX_REFDB[-1]\n$TAX_RANKS[-1]\nPlease check that these files exist.\n",
                      55;
                }
                $citations .=
"HITdb gut specific tax database - J. Ritari, J. Salojärvi, L. Lahti, W. M. de Vos, Improved taxonomic assignment of human intestinal 16S rRNA sequences by a dedicated reference database. BMC Genomics. 16, 1056 (2015). \n";
            }
            if ( $subrdbw =~ m/^PR2$/ ) {
                push @TAX_REFDB, $TAX_REFDB_16S_PR2;
                push @TAX_RANKS, $TAX_RANK_16S_PR2;
                if ( !-f $TAX_REFDB[-1] || !-f $TAX_RANKS[-1] ) {
                    printL
"Could not find PR2 files at \n$TAX_REFDB[-1]\n$TAX_RANKS[-1]\nPlease check that these files exist.\n",
                      55;
                }
                $citations .=
"PR2 LSU specific tax database - Nucleic Acids Research, 2013. The Protist Ribosomal Reference database (PR2): a catalog of unicellular eukaryote Small Sub-Unit rRNA sequences with curated taxonomy. Laure Guillou, Dipankar Bachar, Stephane Audic, David Bass, Cedric Berney, Lucie Bittner, Christophe Boutte, Gaetan Burgaud, Colomban de Vargas, Johan Decelle, Javier del Campo, John R. Dolan, Micah Dunthorn, Bente Edvardsen, Maria Holzmann, H.C.F. Kooistra Wiebe, Enrique Lara, Noan Le Bescot, Ramiro Logares, Frederic Mahe, Ramon Massana, Marina Montresor, Raphael Morard, Fabrice Not, Jan Pawlowski, Ian Probert, Anne-Laure Sauvadet, Raffaele Siano, Thorsten Stoeck, Daniel Vaulot, Pascal Zimmermann and Richard Christen. Nucleic Acids Res (2013) Volume 41 Issue D1: Pp. D597-D604. \n";
                push @refDBname, "PR2";
            }
            if ( $subrdbw =~ m/^GG$/ ) {
                if ( !-f $TAX_REFDB_GG || !-f $GGinfile ) {
                    printL
"Could not find greengenes DB files at \n$TAX_REFDB_GG\n$GGinfile\nPlease check that these files exist.\n",
                      55;
                }

#if (-f $TAX_REFDB_SLV && -f $SLVinfile){				#printL "Found both SILVA and greengenes databases. Using Greengenes for this run.\n",0;			}
                push @refDBname, "greengenes";
                push @TAX_REFDB, $TAX_REFDB_GG;
                push @TAX_RANKS, $GGinfile;
                $citations .=
"greengenes 16S database - McDonald D, Price MN, Goodrich J, Nawrocki EP, DeSantis TZ, Probst A, Andersen GL, Knight R, Hugenholtz P. 2012. An improved Greengenes taxonomy with explicit ranks for ecological and evolutionary analyses of bacteria and archaea. ISME J 6: 610–8.\n";
            }

            if ( $subrdbw =~ m/^BEETAX$/ ) {
                if ( !-f $TAX_REFDB_GG || !-f $GGinfile ) {
                    printL
"Could not find greengenes DB files at \n$TAX_REFDB_GG\n$GGinfile\nPlease check that these files exist.\n",
                      55;
                }

#if (-f $TAX_REFDB_SLV && -f $SLVinfile){				#printL "Found both SILVA and greengenes databases. Using Greengenes for this run.\n",0;			}
                push @refDBname, "BeeTax";
                push @TAX_REFDB, $TAX_REFDB_BT;
                push @TAX_RANKS, $TAX_RANK_16S_BT;
                $citations .=
"Bee specific reference database: Jones, Julia C et al. 2017. “Gut Microbiota Composition Is Associated with Environmental Landscape in Honey Bees.” Ecology and Evolution (October): 1–11.\n";
            }
            if ( $subrdbw =~ m/^SLV$/ ) {
                push @refDBname, "SILVA";
                if ( $ampliconType eq "SSU" ) {
                    printL "Using Silva SSU ref seq database.\n", 0;
                    push @TAX_REFDB, $TAX_REFDB_SLV;
                    push @TAX_RANKS, $SLVinfile;
                }
                elsif ( $ampliconType eq "LSU" ) {
                    printL "Using Silva LSU ref seq database.\n", 0;
                    push @TAX_REFDB, $TAX_REFDB_SLV_LSU;
                    push @TAX_RANKS, $SLVinfile_LSU;
                }
                if ( !-f $TAX_REFDB[-1] || !-f $TAX_RANKS[-1] ) {
                    printL
"Could not find Silva DB files at \n$TAX_REFDB[-1]\n$TAX_RANKS[-1]\nPlease check that these files exist.\n",
                      55;
                }
                $citations .=
"SILVA 16S/18S database - Yilmaz P, Parfrey LW, Yarza P, Gerken J, Pruesse E, Quast C, Schweer T, Peplies J, Ludwig W, Glockner FO (2014) The SILVA and \"All-species Living Tree Project (LTP)\" taxonomic frameworks. Nucleic Acid Res. 42:D643-D648 \n";

            }
            if ( @refDBname == 0 ) {
                printL
"Found no valid path to a ref database \"$subrdbw\" or could not identify term. No reference based OTU picking.Aborting LotuS\n",
                  3;
            }

        }
    }

    #die "@TAX_REFDB\n";
    #die $ampliconType.substr($ampliconType,0,3)."\n";
    if ( substr( $ampliconType, 0, 3 ) eq "ITS" ) { $doRDPing = 0; }

    if ( !-f $sdmBin ) {
        printL "Could not find sdm binary at\n\"$sdmBin\"\n.Aborting..\n", 3;
    }
    if ( !-f $usBin ) {
        printL "Could not find usearch binary at\n\"$usBin\"\n.Aborting..\n", 3;
    }
    if ( !-f $VSBin ||  $useVsearch == 0) {
        $VSBin  = $usBin;
        $VSused = 0;
        finWarn(
"Could not find vsearch binaries at\n$VSBin\n, switching to usearch binaries instead\n"
        ) if ( !-f $VSBin );
    }
    else {
        $citations .=
"VSEARCH 1.13 (chimera de novo / ref; OTU alignments): Rognes T (2015) https://github.com/torognes/vsearch\n";
    }
    if ( !-f $mjar && !-f $rdpjar && $doRDPing > 0 ) {
        printL
"Could not find rdp jar at\n\"$mjar\"\nor\n\"$rdpjar\"\n.Aborting..\n",
          3;
    }

}


sub getSimBasedTax{
	$doBlasting_pre = lc $doBlasting_pre;
	if ( $doBlasting_pre eq "1" || $doBlasting_pre eq "blast" ) {
		$doBlasting = 1;
	} elsif ( $doBlasting_pre eq "2" || $doBlasting_pre eq "lambda" ) {
		$doBlasting = 2;
	} elsif ( $doBlasting_pre eq "3" || $doBlasting_pre eq "utax" ) {
		$doBlasting = 3;
	} elsif ( $doBlasting_pre eq "4" || $doBlasting_pre eq "vsearch" ) {
		$doBlasting = 4;
	} elsif ( $doBlasting_pre eq "5" || $doBlasting_pre eq "usearch" ) {
		$doBlasting = 5;
	} elsif ( $doBlasting_pre eq "0" ) {
		$doBlasting = 0;
	}
}

sub checkBlastAvaila() {
    if ( !-f $lambdaBin && ( $doBlasting == 2 ) ) {
        printL"Requested LAMBDA based similarity tax annotation; no LAMBDA binary found at $lambdaBin\n",55;
    } elsif ( !-f $blastBin && ( $doBlasting == 1 ) ) {
        printL "Requested blastn based similarity tax annotation; no blastn binary found at $blastBin\n",55;
    } elsif ( !-f $VSBinOri && ( $doBlasting == 4 ) ) {
        printL "Requested VSEARCH based similarity tax annotation; no vsearch binary found at $VSBinOri\n",55;
    } elsif ( !-f $usBin && ( $doBlasting == 5 ) ) {
        printL "Requested USEARCH based similarity tax annotation; no usearch binary found at $usBin\n",55;
    }
}

sub help {
    print
"\nPlease provide at least 3 arguments:\n(1) -i [input fasta / fastq / dir]\n";
    print
"(2) -o [output dir]\n(3) -m/-map [mapping file]\nOptional options are:\n";
    print "############### Basic pipeline options ###############\n";
    print "  -check_map [mapping file] only checks mapping file and exists\n";
    print "  -q [input qual file (empty in case of fastq or directory)]\n";
    print
"  -barcode [file path to fastq formated file with barcodes (this is a processed mi/hiSeq format)]\n";
    print
"  -s [sdm option file, defaults to \"sdm_options.txt\" in current dir]\n";
    print
"  -c [lOTUs.cfg config file with program paths]\n  -p [sequencing platform:454,miSeq,hiSeq,PacBio]\n";
    print "  -t [temporary directory]\n";
    print
"  -threads [number of threads to be used, default 1]\n  -UP [(1) use UPARSE, (0) use otupipe, default 1]\n";
    print
"  -tolerateCorruptFq [1: continue reading fastq files, even if single entries are incomplete (e.g. half of qual values missing). 0: Abort lotus run, if fastq file is corrupt. Default 1]\n";
    print
"  -custContamCheckDB [Default: empty. This option checks in analogy to the phiX filter step in a custom DB (e.g. mouse genome, needs to be fasta format), for contaminant OTUs that are more likely to derrive from this genome than e.g. bacteria. Example: -custContamCheckDB /YY/mouse.fna]\n";
    print
"  -amplicon_type [LSU: large subunit (23S/28S) or SSU: small subunit (16S/18S). Default SSU]\n";
    print
"  -keepTmpFiles [1: save extra tmp files like chimeric OTUs or the raw blast output in extra dir; 0: don't save these, default 0]\n";
    print
"  -saveDemultiplex [1: Saves all demultiplexed & filtered reads in gzip format in the output directory (can require quite a lot of diskspace). 2: Only saves quality filtered demultiplexed reads and continues LotuS run subsequently. 3: Saves demultiplexed file into a single fq, saving sample ID in fastq/a header. 0: No demultiplexed reads are saved. Default: 0]\n";
    print
"  -highmem [1 : highmem mode which has much faster excecution speed but can require substantial amounts of ram (e.g. hiSeq: ~40GB). 0 deactivates this, reducing memory requirements to < 4 GB, default=1]\n";

    print "\n############### Taxonmomy related options ###############\n";
    print
"  -taxOnly skip most of the lotus pipeline and only run a taxonomic classification on a fasta file (provided via \"-i\" (could be an OTU fasta).\n";
    print
"  -redoTaxOnly [1: only redo the taxonomic assignments (useful for replacing a DB used on a finished lotus run), 0: normal lotus run, default]\n";
    print
"  -rdp_thr [Confidence thresshold for RDP, default 0.8]\n  -utax_thr [Confidence thresshold for UTAX, default 0.8]\n  -LCA_frac [min fraction of reads with identical taxonomy, default 0.9]\n";
    print
"  -keepUnclassified [1: includes unclassified OTUs (i.e. no match in RDP/Blast database) in OTU and taxa abundance matrix calculations; 0 does not take these OTU's into account, default 0]\n";
    print
"  -taxAligner [(previously doBlast) 0: deavtivated (just use RDP); [1 or \"blast\"]: use Blast; [2 or \"lambda\"]: use LAMBDA to search against a 16S reference database for taxonomic profiling of OTUs; [3 or \"utax\"]: use UTAX with custom databases; [4 or \"vsearch \"]: use VSEARCH to align OTUs to custom databases; [5 or \"usearch\"]: use USEARCH to align OTUs to custom databases. Default 0]\n";
    print
"  -useBestBlastHitOnly [1: don't use LCA (last common ancestor) to determine most likely taxnomic level (not recommended), instead just use the best blast hit. 0: (default) LCA algorithm]\n";
    print
"  -refDB [\"SLV\" Silva LSU (23/28S) or SSU (16/18S), \"GG\" greengenes (only SSU available), \"HITdb\" (SSU, human gut specific), \"PR2\" (LSU spezialized on Ocean environmentas), \"UNITE\" (ITS fungi specific), \"beetax\" (bee gut specific database and tax names). Decide which reference DB will be used for a similarity based taxonomy annotation, default \"GG\"\n";
    print
"Databases can be combined, with the first having the highest prioirty. E.g. \"PR2,SLV\" would first use PR2 to assign OTUs and all unaasigned OTUs would be searched for with SILVA, given that \"-amplicon_type LSU\" was set.\n";
    print
"  -tax4refDB [in conjunction with a custom fasta file provided to argument -refDB, this file contains for each fasta entry in the reference DB a taxonomic annotation string, with the same number of taxonomic levels for each, tab separated.]";
    print
"  -greengenesSpecies [1: Create greengenes output labels instead of OTU (to be used with greengenes specific programs such as BugBase). Default: 0]\n";
    print
"  -tax_group [\"bacteria\": bacterial 16S rDNA annnotation, \"fungi\": fungal 18S/23S/ITS annotation. Default \"bacteria\"]\n";
    print
"  -itsextraction [1: use ITSx to only retain OTUs fitting to ITS1/ITS2 hmm models; 0: deactivate; Default=1]\n";
    print
"  -itsx_partial [0-100: parameters for ITSx to extract partial (%) ITS regions as well; 0: deactivate; Default=0]\n";

    print "\n############### OTU clustering options ###############\n";
    print
"  -CL/-clustering [(1) use UPARSE, (0) use otupipe (deprecated), (2) use swarm and (3) use cd-hit, default 1]\n";
    print "  -id [clustering threshold for OTU's, default 0.97]\n";
    print
"  -swarm_distance [clustering threshold for OTU's when using swarm clustering, default 1]\n";
    print
"  -chim_skew [skew in chimeric fragment abundance (uchime option), default 2]\n";
    print
"  -derepMin [minimum size of dereplicated clustered, one form of noise removal. Can be complex terms like \"10:1,3:3\" -> meaning at least 10x in 1 sample or 3x in 3 different samples. Default 1]\n";
    print
"Can also be a custom fasta formatted database: in this case provide the path to the fasta file as well as the path to the taxonomy for the sequences using -tax4refDB. See also online help on how to create a custom DB.]\n";
    print
"  -count_chimeras [T: count chimeric reads into their estimated original OTUs, F: do nothing. Default F]\n";
    print
"  -deactivateChimeraCheck [0: do OTU chimera checks. 1: no chimera Check at all. 2: Deactivate deNovo chimera check. 3: Deactivate ref based chimera check.Default = 0]\n";

#   print "  -pseudoRefOTUcalling [1: create Reference based (open) OTUs, where the chosen reference database (SLV,GG etc) is being used as cluster center. Default: 0]\n";
#print "  -OTUbuild [OTU building strategy: \"ref_closed\", \"ref_open\" or \"denovo\" (default)\n";
    print
"  -readOverlap [the maximum number of basepairs that two reads are overlapping, default 300]\n";
    print
"  -flash_param [custom flash parameters, since this contains spaces the command needs to be in parentheses: e.g. -flash_param \"-r 150 -s 20\". Note that this option completely replaces the default -m and -M flash options (i.e. need to be reinserted, if wanted)]\n";
    print
"  -endRem [DNA sequence, usually reverse primer or reverse adaptor; all sequence beyond this point will be removed from OTUs. This is redundant with the \"ReversePrimer\" option from the mapping file, but gives more control (e.g. there is a probelm with adaptors in the OTU output), default \"\"]\n";
    print
"  -xtalk [(1) check for crosstalk; note that this requires in most cases 64bit usearch, default 0]\n";
    exit(0);
}

sub usage {
    print STDERR @_ if @_;
    help();
    exit(1);
}

sub frame($) {
    my ($txt) = @_;
    my @txtarr = split( /\n/, $txt );
    my $repStr =
"=========================================================================\n";
    my $numOfChar = 10;
    my $ret       = $repStr;
    for ( my $i = 0 ; $i < scalar(@txtarr) ; $i++ ) {
        $ret .= ' ' x $numOfChar . $txtarr[$i] . "\n";
    }
    $ret .= $repStr;
}

sub firstXseqs($ $ $) {
    my ( $otus, $numS, $out ) = @_;
    open I, "<", $otus;
    open O, ">", $out;
    my $cnt = 0;
    while ( my $line = <I> ) {
        $cnt++ if $line =~ m/^>/;
        last   if $cnt == $numS;
        print O $line;
    }
    close O;
    close I;
    return ($out);
}

sub get16Sstrand($ $) {    #
    my ( $OTUfa, $refDB ) = @_;
    my $ret      = "both";
    my $OTUfa_sh = firstXseqs( $OTUfa, 6, "$t/otus4blast.tmp" );
    my $cmd =
"$blastBin -query $OTUfa_sh -db $refDB -out $t/blast4dire.blast -outfmt 6 -max_target_seqs 200 -perc_identity 75 -num_threads $BlastCores -strand both \n"
      ;                    #-strand plus both
    if ( systemL($cmd) != 0 ) {
        printL "FAILED pre-run blast command:\n$cmd\n", 5;
    }

    #die "$t\n$cmd\n";
    my $plus  = 0;
    my $minus = 0;
    open I, "<", "$t/blast4dire.blast";
    while ( my $line = <I> ) {
        my @spl = split( "\t", $line );
        if ( $spl[6] < $spl[7] ) {
            if ( $spl[8] > $spl[9] ) {
                $minus++;
            }
            else { $plus++; }
        }
        else {
            if ( $spl[8] > $spl[9] ) {
                $plus++;
            }
            else { $minus++; }
        }
    }
    close I;

    #die("P= $plus M=$minus\n");
    if ( $plus + $minus > 20 ) {
        if ( $plus / ( $plus + $minus ) > 0.9 ) { $ret = "plus"; }
        if ( $plus / ( $plus + $minus ) < 0.1 ) { $ret = "minus"; }
    }

    #die ($plus ." P $minus M \n");
    #printL "Using $ret strand for blast searches.\n",0;
    return ($ret);
}

sub calcHighTax($ $ $ $ $) {
    my ( $hr, $inT, $failsR, $LCAtax, $xtraOut ) = @_;
    printL "Calculating higher abundance levels\n", 0;
    my $getHit2DB = 0;
    $getHit2DB = 1 if ( $xtraOut ne "" );
    my ( $hr1, $ar1, $hr2, $tax4RefHR ) =
      readTaxIn( $inT, $LCAtax, 0, $getHit2DB );
    my %Taxo   = %{$hr1};
    my @lvls   = @{$ar1};
    my %hit2db = %{$hr2};
    my %fails  = %{$failsR};
    my %OTUmat = %{$hr};
    my $SEP    = "\t";
    my @avSmps = sort( keys %OTUmat );

    #my @avOTUs = keys %{$OTUmat{$avSmps[0]}};
	my %matOTUs;
	foreach my $sm (keys %OTUmat){
		foreach my $kk (keys %{$OTUmat{$sm}}){
			$matOTUs{$kk} = 0;
		}
	}
	my @matOTUs2 = keys %matOTUs;
	print "@matOTUs2   ".@matOTUs2."\n"."\n";

    #pseudo OTU ref hits
    if ( $xtraOut ne "" ) {
        open O, ">$xtraOut" or die "Can't open ref OTU file $xtraOut\n";
        print O "RefOTUs" . $SEP . join( $SEP, @avSmps );
        my @avTax = sort( keys(%hit2db) );
		my %matOTUsTT = %matOTUs; 
        foreach my $ta (@avTax) {
            print O "\n" . $ta;
            my @OTUli = @{ $hit2db{$ta} };
			#first mark which OTUs get hit at all at this level (to count unclassis)
			foreach (@OTUli) {
				$matOTUsTT{$_} = 1;
			}
            foreach my $sm (@avSmps) {
                printL("Sample $sm does not exist\n"), 0 if ( !exists( $OTUmat{$sm} ) );
                my $smplTaxCnt = 0;
                foreach (@OTUli) {
                    if ( !$keepUnclassified && exists( $fails{$_} ) ){
						next;
					}
                    if ( !exists( $OTUmat{$sm}{$_} ) ) {
                        printL( "Sample $sm id $_ does not exist. $ta.\n", 0 );
                    }
                    else {
                        $smplTaxCnt += $OTUmat{$sm}{$_};
                    }
                }
                print O $SEP . $smplTaxCnt;
            }
        }
        close O;
    }

    #standard add up taxonomy on higher levels
    my $cnt = 0;
    my %totCnt;
    my %assCnt;
    my %assTax;
    my %unassTax;
	my @addedUnclOTUs=();
    foreach my $l (@lvls) {
        $cnt++;
        next if ( $cnt == 1 );    #domain doesn't need a file..
        my $lvlSmplCnt       = 0;
        my $assignedCnt      = 0;
        my $taxAssingedCnt   = 0;
        my $taxUnAssingedCnt = 0;
        my $isUnassigned     = 0;
        my @avTax            = sort( keys( %{ $Taxo{$l} } ) );
        my $outF             = $highLvlDir . $l . ".txt";
        open O, ">", $outF;

        #header
        print O $l . $SEP . join( $SEP, @avSmps );
		my %matOTUsTT = %matOTUs; 

        #smplWise counts, summed up to tax
        foreach my $ta (@avTax) {
            print O "\n" . $ta;
            if ( $ta =~ m/\?$/ ) {
                $isUnassigned = 1;
                $taxUnAssingedCnt++;
            }
            else { $taxAssingedCnt++; }
            my @OTUli = @{ $Taxo{$l}{$ta} };
			#first mark which OTUs get hit at all at this level (to count unclassis)
			foreach (@OTUli) {
				$matOTUsTT{$_} = 1;
			}

            #die(join("-",@OTUli)." ".$ta."\n");
            foreach my $sm (@avSmps) {
                printL("Sample $sm does not exist\n"), 0  if ( !exists( $OTUmat{$sm} ) );
                my $smplTaxCnt = 0;
                foreach (@OTUli) {
                    next if ( !$keepUnclassified && exists( $fails{$_} ) );
                    if ( !exists( $OTUmat{$sm}{$_} ) ) {
                        printL( "Sample $sm id $_ does not exist. $l. $ta.\n", 0 );
                    }
                    else {
                        $smplTaxCnt += $OTUmat{$sm}{$_};
                    }
                }
                $assignedCnt += $smplTaxCnt if ( !$isUnassigned );
                $lvlSmplCnt  += $smplTaxCnt;
                print O $SEP . $smplTaxCnt;
            }
            $isUnassigned = 0;
			
						#now write out the unclassified ones

        }
		if ($keepUnclassified){
			print O "\n" . "noHit;" . $SEP;
			my @OTUli = ();
			foreach (keys %matOTUsTT){
				push @OTUli, $_ if ($matOTUsTT{$_} == 0);
			}
			push(@addedUnclOTUs , scalar(@OTUli ));
			foreach my $sm (@avSmps) {
				my $smplTaxCnt = 0;
				foreach (@OTUli) {
					if ( !exists( $OTUmat{$sm}{$_} ) ) { printL( "Sample $sm id $_ does not exist.\n", 0 ); 
					} else {$smplTaxCnt += $OTUmat{$sm}{$_};
				}
			}
			$lvlSmplCnt  += $smplTaxCnt;
			print O $SEP . $smplTaxCnt;
			}
		}
		close O;
        $totCnt{$l}   = $lvlSmplCnt;
        $assCnt{$l}   = $assignedCnt;
        $assTax{$l}   = $taxAssingedCnt;
        $unassTax{$l} = $taxUnAssingedCnt;

        #		printL $l.": ". ($lvlSmplCnt)." ",0;
    }

	if ($keepUnclassified){
		printL "Adding " .join(",",@addedUnclOTUs) . " unclassified OTUs to ".join(",",@lvls) ." levels, respectively\n";
	}

    #print some stats
    $cnt = 0;
    foreach my $l (@lvls) {
        $cnt++;
        next if ( $cnt == 1 );    #domain doesn't need a file..
        if ( $cnt == 2 ) {
            printL
"Total reads in matrix: $totCnt{$l}\nTaxLvl	%AssignedReads	%AssignedTax\n",
              0;
        }
        my $assPerc = 0;
        $assPerc = $assCnt{$l} / $totCnt{$l} if ( $totCnt{$l} > 0 );
        my $assPerc2 = 0;
        $assPerc2 = $assTax{$l} / ( $assTax{$l} + $unassTax{$l} )
          if ( ( $totCnt{$l} + $unassTax{$l} ) > 0 );
        printL "$l\t" . ( 100 * $assPerc ) . "\t" . ( 100 * $assPerc2 ) . "\n",
          0;
    }
    printL "\n", 0;
    return $tax4RefHR;
}

sub buildTree($ $) {
    my ( $OTUfa, $outdir ) = @_;
    my $multAli  = $outdir . "/otuMultAlign.fna";
    my $outTree  = $outdir . "/Tree.tre";
    my $tthreads = $uthreads;

    my $cmd = $clustaloBin . " -i $OTUfa -o $multAli --outfmt=fasta --threads=$tthreads --force\n";

    if (   ( $exec == 0 && $onlyTaxRedo == 0 && -f $clustaloBin )
        || ( $exec == 0 && $onlyTaxRedo == 0 && -f $fasttreeBin ) ) {
        $citations .= "======== Phylogenetic tree building ========\n";
    }

    if ( $exec == 0 && $onlyTaxRedo == 0 && -f $clustaloBin ) {
        if ( !-f $OTUfa ) {
            printL "Could not find OTU sequence file:\n$OTUfa\n", 5;
        }
        if ( systemL($cmd) != 0 ) {
            printL "Fallback to single core clustalomega\n", 0;
            $cmd = $clustaloBin . " -i $OTUfa -o $multAli --outfmt=fasta --threads=1 --force\n";
			if ( systemL($cmd) != 0 ) {
				printL "FAILED multiple alignment command: " . $cmd . "\n", 5;
			}
        }
        $citations .= "Clustalo multiple sequence alignments: Sievers F, Wilm A, Dineen D, Gibson TJ, Karplus K, Li W, Lopez R, McWilliam H, Remmert M, Söding J, et al. 2011. Fast, scalable generation of high-quality protein multiple sequence alignments using Clustal Omega. Mol Syst Biol 7: 539.\n";
    }
    elsif ($onlyTaxRedo) { printL "Skipping Multiple Alignment step\n", 0; }
    if ( $exec == 0 && $onlyTaxRedo == 0 && -f $fasttreeBin ) {
        if ( !-f $multAli ) {
            printL "Could not find multiple alignment file:\n$multAli\n", 5;
        }
        $cmd = $fasttreeBin . " -nt -gtr -no2nd -spr 4 -log $logDir/fasttree.log -quiet $multAli > $outTree";

        #die($cmd."\n");
        if ( $exec == 0 ) {
            printL "Building tree..\n";
            if ( systemL($cmd) != 0 ) {
                printL "FAILED tree building command: " . $cmd . "\n", 5;
            }
            $citations .=
"FastTree2 phylogenetic tree construction for OTUs: Price MN, Dehal PS, Arkin AP. 2010. FastTree 2--approximately maximum-likelihood trees for large alignments. ed. A.F.Y. Poon. PLoS One 5: e9490.\n";
        }
    }
    elsif ($onlyTaxRedo) { printL "Skipping Tree building step\n", 0; }
}

sub getGGtaxo($ $) {
    my ( $ggTax, $rDBname ) = @_;
    open TT, "<", $ggTax or printL "Can't open taxonomy file $ggTax\n", 87;

    #my @taxLvls = ("domain","phylum","class","order","family","genus");
    my %ret;
    while ( my $line = <TT> ) {
        chomp $line;
        my @spl = split( "\t", $line );
        my $tmp = $spl[1];
        if ( @spl < 2 ) {
            die( "Taxfile line missing tab separation:\n" . $line . "\n" );
        }
        $tmp =~ s/__;/__\?;/g;
        $tmp =~ s/__unidentified;/__\?;/g;
        $tmp =~ s/s__$/s__\?/g;
        $tmp =~ s/\s*[kpcofgs]__//g;
        $tmp =~ s/\"//g;
        my @sp2 = split( ";", $tmp );
        foreach (@sp2) { s/\]\s*$//; s/^\s*\[//; chomp; }
        my $taxv = join( "\t", @sp2 );

        #die($taxv."\n");
        $ret{ $spl[0] } = \@sp2;
    }
    close TT;
    printL "Read $rDBname taxonomy\n", 0;
    return %ret;
}

sub maxTax($) {
    my ($in)  = @_;
    my @spl22 = @{$in};
    my $cnt   = 0;
    foreach (@spl22) {
        last if ( $_ eq "?" );
        $cnt++;
    }
    return $cnt;
}

sub correctTaxString($ $) {
    my ( $sTax2, $sMaxTaxX ) = @_;
    my @ta  = @{$sTax2};
    my @ta2 = @ta;

    #die "@ta\n".$ta[$sMaxTaxX]." ".$sMaxTaxX."\n";
    for ( my $i = 0 ; $i < $sMaxTaxX ; $i++ ) {
        $ta2[$i] =~ s/^\s+//;
    }
    for ( my $i = $sMaxTaxX ; $i < @ta2 ; $i++ ) {
        $ta2[$i] = "?";
    }
    return \@ta2;
}

sub add2Tree($ $ $) {
    my ( $r1, $r2, $mNum ) = @_;
    my %refT = %{$r1};
    my @cT   = @{$r2};
    my $k    = "";

    #print $cT[3]."\n";
    #my $tmp = join("-",@cT); print $tmp." ".$mNum."\n";
    for ( my $i = 0 ; $i < $mNum ; $i++ ) {
        last if $cT[0] eq "?";
        if ( $i == 0 ) {
            $k = $cT[0];
        }
        else { $k .= ";" . $cT[$i]; }
        if ( exists( $refT{$i}{$k} ) ) {
            $refT{$i}{$k}++;
        }
        else { $refT{$i}{$k} = 1; }
    }
    return \%refT;
}

sub LCA($ $ $) {
    my ( $ar1, $ar2, $maxGGdep ) = @_;
    my @sTax       = @{$ar1};
    my @sMaxTaxNum = @{$ar2};
    if ( scalar(@sTax) == 1 ) {

        #print"early";
        my @tmpX = @{ $sTax[0] };
        my @tmp  = ();
        for ( my $i = 0 ; $i < $sMaxTaxNum[0] ; $i++ ) {
            push( @tmp, $tmpX[$i] );
        }
        for ( my $re = scalar(@tmp) ; $re < $maxGGdep ; $re++ ) {
            push( @tmp, "?" );
        }
        return ( \@tmp );
    }
    my $r1 = {};
    for ( my $i = 0 ; $i < scalar(@sMaxTaxNum) ; $i++ ) {

        #my @temp = split($sTax[$i]);
        #print @{$sTax[$i]}[0]."  $sMaxTaxNum[$i] \n";
        #next if ($sTax[$i] =~ m/uncultured /);
        $r1 = add2Tree( $r1, $sTax[$i], $sMaxTaxNum[$i] );
    }
    my %refT      = %{$r1};
    my $fini      = 0;
    my $latestHit = "";

    #determine which taxa has the highest number of hits
    my $dk;

    #print $sMaxTaxNum[0]."\n";
    my $numHits = int(@sTax) + 1;
    foreach $dk ( sort { $a <=> $b } ( keys %refT ) ) {

        #print $dk." ";
        my @curTaxs = keys %{ $refT{$dk} };
        foreach my $tk (@curTaxs) {

     #if ($dk == 2){print int($LCAfraction*$numHits). " ". $refT{$dk}{$tk}.":";}
     #if ($refT{$dk}{$tk} < $numHits){#need to get active
            if ( $refT{$dk}{$tk} >= int( $LCAfraction * $numHits ) ) {
                $latestHit = $tk;
                $fini      = 0;
                $numHits   = $refT{$dk}{$latestHit};
                last;

                #} #else {#$fini = 1;#last;}
            }
            else {
                $fini = 1;

                #$latestHit = $tk;
            }
        }

        if ($fini) { last; }
    }

    #my $winT = join("\t",@refT);
    #print "LAT ".$latestHit."\n";
    my @ret = split( ";", $latestHit );
    for ( my $re = scalar(@ret) ; $re < $maxGGdep ; $re++ ) {
        push( @ret, "?" );
    }

    #my $maxN = maxTax(\@ret);
    return ( \@ret );    #,$maxN);
}

sub extractTaxoForRefs($ $ $) {
    my ( $OTUrefDBlnk, $BlastTaxR, $GGref ) = @_;
    my %ORDL  = %{$OTUrefDBlnk};
    my %BTaxR = %{$BlastTaxR};     #my %BTaxDepR = %{$BlastTaxDepR};
    my @work  = keys %ORDL;
    if ( !@work ) { return; }

    #open O,">>$taxblastf" or die "Can't open taxOut file $taxblastf\n";
    #TODO: load this only once
    my %GG = %{$GGref};
    foreach my $w (@work) {

        #die $ORDL{$w}." XX ".$GG{$ORDL{$w}}."\n";
        #my @cur = @{$GG{$ORDL{$w}}};
        #$BTaxDepR{$w} = 7;
        $BTaxR{$w} = $GG{ $ORDL{$w} };
    }

    #close O;
    return ( \%BTaxR );    #,\%BTaxDepR);
}

sub rework_tmpLines($ $ $ $ $ $ $ $) {
    my ( $tmpLinesAR, $hr1, $sotu, $splAR, $sID, $sLength, $GGhr, $maxGGdep ) =
      @_;
    my @tmpLines   = @{$tmpLinesAR};
    my $debug_flag = 0;

    #if ($sotu eq "S1__ITS_26"){print "\nYAAYYA\n\n\n"; $debug_flag = 1;}
    #my (%ret,%retD) = (%{$hr1},%{$hr2});

    if ( @tmpLines == 0 || $sID == 0 )
    {    #prob no entry passed inclusion criteria
            #${$hr1}{$sotu} = [];${$hr2}{$sotu} = 0;
            #print $sotu."\n";
        ${$hr1}{$sotu} = [];    #$retD{$sotu} = 0;
        return ($hr1);
    }
    my %ret = %{$hr1};

    #if ($sotu eq "S1__ITS_26"){print "\nYAAYYA\n\n\n";}
    my %GG = %{$GGhr};

    #my @ggk = keys %GG; print @ggk."NN\n";
    my @spl        = @{$splAR};
    my @sTax       = ();
    my @sMaxTaxNum = ();
    my $tolerance  = 1.5;

  #extend tolerance upon lesser hits (to include more spurious, off-target hits)
    if    ( $maxHitOnly == 1 ) { $tolerance = 0; }
    elsif ( $sID == 100 )      { $tolerance = 0.1; }
    elsif ( $sID >= 99.5 )     { $tolerance = 0.25; }
    elsif ( $sID >= 99 )       { $tolerance = 0.5; }
    elsif ( $sID >= 98 )       { $tolerance = 1; }
    elsif ( $sID >= 97 )       { $tolerance = 1.25; }

    #print "XX $sID $tolerance $sLength\n";
    foreach my $lin2 (@tmpLines) {    #just compare if the tax gets any better
            #only hits within 1.5% range of best (first) hit considered
        my @spl2 = @{$lin2};    #split("\t",$lin2);
                                #print "$spl2[2] < ($sID - $tolerance\n";
        if ( $spl2[2] < ( $sID - $tolerance ) )           { next; }
        if ( $spl2[3] < ( $sLength * $lengthTolerance ) ) { next; }
        my $sMax2 = 0;
        foreach (@idThr) {
            if ( $spl2[2] < $_ ) { $sMax2++ }
        }
        $sMax2 = 7 - $sMax2;
        unless ( exists $GG{ $spl2[1] } ) {
            die "Can't find GG entry for $spl2[1]\n";
        }
        my $tTax = $GG{ $spl2[1] };

        #print $tTax." JJ\n";
        my $sMax3 = maxTax($tTax);

        #die "$tTax  $sMax3\n";
        if ( $sMax3 <= $sMax2 ) { $sMax2 = $sMax3; }
        push( @sTax,       $tTax );
        push( @sMaxTaxNum, $sMax2 );
    }

    #print "@sTax\n";
    #print $sID."\n";
    #entry for last OTU with best results etc..
    if ( $sotu ne "" ) {
        die "sTax not defined: LC="
          . @tmpLines
          . "\n@{$tmpLines[0]}\n@{$tmpLines[1]}\n@{$tmpLines[2]}\n@{$tmpLines[3]}\n"
          unless ( @sTax > 0 );
        my ($sTaxX) = LCA( \@sTax, \@sMaxTaxNum, $maxGGdep );

        #print $sotu." ".@{$sTaxX}[0]."\n";
        $ret{$sotu} = $sTaxX;

        #$retD{$sotu} = $sMaxTaxX;
        #if ($debug_flag){print "$sTaxX  $sMaxTaxX $retD{$sotu} $sotu\n";}
    }
    return ( \%ret );    #,\%retD);

}

sub splitBlastTax($ $) {
    my ( $blf, $num ) = @_;
    my $blLines = `wc -l $blf | cut -f1 -d ' ' `;
    my $endL    = int( $blLines / $num );
    if ( $endL < 3000 ) { $endL = 3000; }
    my $subLcnt = $endL;
    my @subf;
    my $fcnt   = 0;
    my $totCnt = 0;
    open I, "<$blf" or die "Can't open to split $blf\n";
    my $lstHit = "";
    my $OO;

    while ( my $l = <I> ) {
        $l =~ m/^(\S+)\s/;

        #my $hit = $1;
        if ( $1 ne $lstHit && $subLcnt >= $endL ) {

            #open new file
            #print "$lstHit  $1 $subLcnt\n";
            $subLcnt = 0;
            $lstHit  = $1;
            close $OO if ( defined $OO );
            open $OO, ">$blf.$fcnt";
            push( @subf, "$blf.$fcnt" );
            $fcnt++;
        }
        else {
            $lstHit = $1;    #has to continue until next time a change occurs..
        }
        print $OO $l;
        $subLcnt++;
        $totCnt++;

    }
    close $OO;
    close I;

    #die $blLines." $blf\n";
    #die "@subf\n$totCnt\n";
    return @subf;
}

sub getTaxForOTUfromRefBlast($ $ $) {
    my ( $blastout, $GGref, $interLMode ) = @_;

    #sp,ge,fa,or,cl,ph
    my %GG       = %{$GGref};
    my @ggk      = keys(%GG);
    my $maxGGdep = scalar( @{ $GG{ $ggk[0] } } );
    @ggk = ();
    open B, "<", $blastout or die "Could not read $blastout\n";
    my $sotu    = "";
    my $sID     = 0;
    my $sLength = 0;

    #my @sTax=(); my @sMaxTaxNum = ();
    my $retRef   = {};    # my $retDRef ={};
    my $cnt      = 0;
    my @tmpLines = ();    #stores Blast lines
    my @spl;              #temp line delim
    my %prevQueries = ();
    my $line2       = "";
    while ( my $line = <B> ) {
        $cnt++;
        chomp $line;
        $line2 = $line;
        my @spl  = split( "\t", $line );
        my $totu = $spl[0];                #line otu
        $totu =~ s/^>//;
        if ( $cnt == 1 ) { $sotu = $totu; }

        #print $line." XX $spl[11] $spl[10]\n"; die () if ($cnt > 50);

#check if this is a 2 read-hit type of match (interleaved mode) & merge subsequently
        if ($interLMode) {
            if ( @tmpLines > 0 && exists( $prevQueries{ $spl[1] } ) ) {
                my @prevHit = @{ $prevQueries{ $spl[1] } };
                die
"something went wrong with the inter matching: $prevHit[1] - $spl[1]\n"
                  unless ( $prevHit[1] eq $spl[1] );
                $prevHit[11] += $spl[11];    #bit score
                $prevHit[3]  += $spl[3];
                $prevHit[5]  += $spl[5];
                $prevHit[4] +=
                  $spl[4];    #alignment length,mistmatches,gap openings
                $prevHit[2] = ( $prevHit[2] + $spl[2] ) / 2;

                #$tmpLines[-1] = \@prevHit;
                @spl = @prevHit;

                #next;
            }
            else { $prevQueries{ $spl[1] } = \@spl; }
        }
        if ( ( $spl[11] < $minBit ) || ( $spl[10] > $minEval ) )
        {                     #just filter out..
            $spl[2] = 0;      #simply deactivate this way...
        }

        if ( $sotu eq $totu ) {
            push( @tmpLines, \@spl );
            if ( $spl[2] > $sID && $spl[3] > $sLength ) {
                $sID     = $spl[2];
                $sLength = $spl[3];
            }
            if ( $spl[3] > ( $sLength * 1.4 ) && $spl[2] > ( $sID * 0.9 ) ) {
                $sID     = $spl[2];
                $sLength = $spl[3];
            }                 #longer alignment is worth it..
                              #print $sID."\n";
        }
        else {
            #print "Maybe\n";
            ($retRef) =
              rework_tmpLines( \@tmpLines, $retRef, $sotu, \@spl, $sID,
                $sLength, \%GG, $maxGGdep )
              if ( $sotu ne "" );
            $sotu = $totu;
            undef @tmpLines;
            undef %prevQueries;
            push( @tmpLines, \@spl );
            $prevQueries{ $spl[1] } = \@spl;
            $sID                    = $spl[2];
            $sLength                = $spl[3];
        }
    }

    #last OTU in extra request
    if ( $sotu ne "" ) {
        my @spl = split( "\t", $line2 );
        ($retRef) =
          rework_tmpLines( \@tmpLines, $retRef, $sotu, \@spl, $sID, $sLength,
            \%GG, $maxGGdep );
    }
    close B;

    #debug
    #my %ret = %{$retRef};	my @tmp = @{$ret{$sotu}};print "\n@tmp  $sotu\n";

    return ($retRef);
}

sub numberOTUs($ $ $) {    #rewrites OTUs with new header (numbered header)
    my ( $inf, $outf, $pref ) = @_;
    open X,  "<", $inf;
    open XX, ">", $outf;
    open L,  ">", $inf . "_convertNames";
    my $wrLine = "";
    my $cnt    = 0;
    my %lnk;
    while ( my $line = <X> ) {
        if ( $line =~ m/^>/ ) {
            print XX ">" . $pref . $cnt . "\n";
            $line =~ m/>(\S+).*/;
            my $tmp = $1;
            $tmp =~ m/(.*);size.*/;
            $lnk{$1} = $pref . $cnt;

            #print $1." CC ".$pref.$cnt."\n";
            print L $1 . "\t" . $pref . $cnt . "\n";
            $cnt++;
        }
        else {
            print XX $line;
        }
    }
    close X;
    close XX;
    close L;

    return \%lnk;
}

sub newUCSizes($ $) {
    my ( $fafil, $ucfil ) = @_;
    my $hr = readFastaHd($fafil);
    my %fa = %{$hr};

    #read UC file
    open UC, "<", $ucfil;
    my $tok;
    my @splu;
    while ( my $line = <UC> ) {
        chomp($line);
        my $cnt = 0;
        if ( $line =~ m/^S/ ) {
            @splu = split( /\t/, $line );
            $tok  = $splu[8];
            $tok =~ s/;size=(\d+);//;

            #die ($line."\n".$1."\n");
            $cnt = $1;
        }
        elsif ( $line =~ m/^H/ ) {
            @splu = split( /\t/, $line );
            $tok  = $splu[9];
            $tok =~ s/;size=\d+;//;
            my $tik = $splu[8];
            $tik =~ m/;size=(\d+);/;
            $cnt = $1;
        }
        if ( !exists( $fa{$tok} ) ) {
            die("Expected fasta seq with head $tok\n");
        }
        $fa{$tok} += $cnt;
    }
    close UC;

    replaceFastaHd( \%fa, $fafil );
}

sub readFastaHd($) {
    my ($fil) = @_;
    open( FAS, "<", "$fil" ) || die("Couldn't open FASTA file $fil.");
    my %Hseq;
    my $line;
    while ( $line = <FAS> ) {
        if ( $line =~ m/^>/ ) {
            chomp($line);
            $line =~ s/;size=\d+;.*//;
            $line = substr( $line, 1 );

            #die $line."\n";
            $Hseq{$line} = 0;
        }
    }
    close FAS;
    return \%Hseq;
}

sub revComplFasta {
    my ($inF) = @_;
    open I, "<$inF";
    open O, ">$inF.tmp";
    while ( my $l = <I> ) {
        chomp $l;
        if ( $l !~ m/^>/ ) { $l = reverse_complement_IUPAC($l); }
        print O $l . "\n";
    }
    close I;
    close O;
    systemL "rm $inF; mv $inF.tmp $inF";
}

sub reverse_complement_IUPAC {
    my $dna = shift;

    # reverse the DNA sequence
    my $revcomp = reverse($dna);

    # complement the reversed DNA sequence
    $revcomp =~
      tr/ABCDGHMNRSTUVWXYabcdghmnrstuvwxy/TVGHCDKNYSAABWXRtvghcdknysaabwxr/;
    return $revcomp;
}

sub readFasta($) {
    my ($fil) = @_;
    my %Hseq;
    if ( -z $fil ) { return \%Hseq; }
    open( FAS, "<", "$fil" ) || printL( "Couldn't open FASTA file $fil\n", 88 );
    my $temp;
    my $line;
    my $trHe = <FAS>;
    chomp($trHe);
    $trHe = substr( $trHe, 1 );
    $trHe =~ s/;size=\d+;.*//;
    $trHe =~ s/\s.*//;

    while ( $line = <FAS> ) {
        if ( $line =~ m/^>/ ) {

            #finish old fas`
            $Hseq{$trHe} = $temp;

            #prep new entry
            chomp($line);
            $trHe = substr( $line, 1 );
            $trHe =~ s/;size=\d+;.*//;
            $trHe =~ s/\s.*//;
            $temp = "";
            next;
        }
        $temp .= ($line);
    }
    $Hseq{$trHe} = $temp;
    close(FAS);
    return \%Hseq;
}

sub writeFasta($ $) {
    my ( $hr, $outFile ) = @_;
    my %fas = %{$hr};
    open O, ">$outFile" or printL "Can't open outfasta $outFile", 99;
    foreach my $k ( keys %fas ) {
        print O ">" . $k . "\n" . $fas{$k} . "\n";
    }
    close O;
}

sub swarm4us_size($) {
    my ($otuf) = @_;
    open I, "<$otuf"      or die "Can't open $otuf\n";
    open O, ">$otuf.ttmp" or die "Can't open $otuf.tmp\n";
    while ( my $line = <I> ) {
        chomp $line;
        if ( $line =~ m/^>/ ) {
            $line =~ s/_(\d+)$/;size=$1;/;
        }
        print O $line . "\n";
    }
    close I;
    close O;

    #	die $otuf."\n";
    systemL "rm $otuf;mv $otuf.ttmp $otuf";
}

sub replaceFastaHd($ $) {
    my ( $href, $ifil ) = @_;
    my $ofil = $ifil . ".tmp";
    my %fa   = %{$href};
    open O, ">", $ofil;
    open( FAS, "<", "$ifil" ) || die("Couldn't open FASTA file.");
    my %Hseq;
    my $line;
    while ( $line = <FAS> ) {
        if ( $line =~ m/^>/ ) {
            chomp($line);
            $line =~ s/;size=\d+;//;
            $line = substr( $line, 1 );
            if ( !exists( $fa{$line} ) ) { die("can't find key $line\n"); }
            $line = ">" . $line . ";size=" . $fa{$line} . ";\n";
        }
        print O $line;
    }
    close FAS;
    close O;
    rename( $ofil, $ifil ) or die "Unable to overwrite file $ifil\n";
}

sub onelinerSWM($) {
    my ($ifil) = @_;
    my $ofil = $ifil . ".tmp";
    open O, ">", $ofil;
    open( FAS, "<", "$ifil" ) || die("Couldn't open FASTA file.");
    my $seq = "";
    while ( my $line = <FAS> ) {
        chomp($line);
        if ( $line =~ m/^>/ ) {
            $line =~ s/;size=(\d+);.*/_$1/;
            if ( $seq ne "" ) {
                print O $seq . "\n" . $line . "\n";
                $seq = "";
            }
            else {
                print O $line . "\n";
            }
        }
        else {
            $seq .= $line;
        }
    }
    print O $seq;
    close FAS;
    close O;
    rename( $ofil, $ifil ) or die "Unable to overwrite file $ifil\n";
}

sub readRDPtax($) {
    my ($taxf) = @_;    #$avOTUR
    open T, "<", $taxf or die "Can't open $taxf : \n" . $!;
    my @taxLvls = ( "domain", "phylum", "class", "order", "family", "genus" );
    my @Hiera   = ();
    my %Fail;

    #my %AvOTUs = %{$avOTUR};
    my $rankN = -1;
    while ( my $line = <T> ) {
        chomp($line);

        #print $line."\n";
        $line =~ s/"//g;
        my @spl = split( "\t", $line );
        next unless ( $spl[0] =~ m/^$OTU_prefix/ && @spl > 3 );

        #print $spl[0]."\n";
        if ( $rankN == -1 ) {
            for ( my $i = 3 ; $i < 10 ; $i += 3 ) {
                if ( $spl[$i] =~ m/domain/ ) {
                    $rankN = $i - 1;
                    last;
                }
            }
        }
        next if ( $rankN == -1 );

        #phylum level class
        if ( $spl[ $rankN + 5 ] < $RDPCONF ) {
            $Fail{ $spl[0] } = 1;

            #next;
        }

        #$AvOTUs{$spl[0]} = 1;
        #push(@AvOTUs,$spl[0]);
        my $nhier = "";    #$spl[$rankN]."\t";
        my $tcnt  = 0;     #1,+3
        for ( my $i = $rankN + 0 ; $i <= $rankN + 16 ; $i += 3 ) {
            if ( $taxLvls[$tcnt] eq $spl[ $i + 1 ] ) {
                $tcnt++;
            }
            else { die( "expected " . $taxLvls[$tcnt] . " " . $line . "\n" ); }
            if ( $spl[ $i + 2 ] < $RDPCONF ) {
                $nhier .= "?\t";
            }
            else             { $nhier .= $spl[$i] . "\t"; }
            if ( $i > @spl ) { last; }
        }
        $nhier .= "?\t" . $spl[0];
        push( @Hiera, $nhier );
    }
    close T;

    #write hier
    open H, ">", $RDP_hierFile;
    print H join( "\t", @taxLvls ) . "\tspecies\tOTU\n";
    foreach (@Hiera) { print H $_ . "\n"; }
    close H;

    #print(keys(%Fail)."\n");
    return ( \@Hiera, \%Fail );    #\%AvOTUs,
}

sub blastFmt($ $) {
    my ( $aref, $tD ) = @_;
    $aref = correctTaxString( $aref, $tD );
    my @in = @{$aref};
    return join( "\t", @{$aref} );
}

sub writeUTAXhiera($ $ $) {
    my ( $utout, $avOTUsR, $failsR ) = @_;
    my %fails  = %{$failsR};
    my @avOTUs = @{$avOTUsR};

    #parse utax output
    my %utStr;
    open I, "<$utout" or die "Can;t open $utout\n";
    while (<I>) {
        my @spl   = split /\t/;
        my $k     = $spl[0];
        my @spl2  = split( /,/, $spl[1] );
        my $nline = "";
        my $cnt   = 0;
        foreach my $sus (@spl2) {
            $sus =~ s/^\S://;
            $sus =~ s/\"//g;
            $sus =~ m/(^.*)\(([0-9\.]*)\)/;
            my $sus2 = $1;
            if ( $2 < $utaxConf ) {
                $sus2 = "?";
                if ( $cnt == 0 ) { $fails{$k} = 1; last; }
            }
            $nline .= $sus2 . "\t";
            $cnt++;
        }
        while ( $cnt < 7 ) { $nline .= "?\t"; $cnt++; }

        #die $nline."\n$_";
        $utStr{$k} = $nline;
    }
    close I;

    open H, ">", $SIM_hierFile or die "Can't open $SIM_hierFile\n";
    print H "Domain\tPhylum\tClass\tOrder\tFamily\tGenus\tSpecies\tOTU\n";

    #print all failed OTUs
    my @faKeys = keys(%fails);
    foreach (@faKeys) {
        if ( exists( $utStr{$_} ) ) {
            delete $fails{$_};
        }
        else {
            print H "?\t?\t?\t?\t?\t?\t?\t" . $_ . "\n";
        }
    }

    #print newly derrived tax
    foreach (@avOTUs) {    #(sort(keys(%{$taxr}))){
        my $failed1 = exists( $fails{$_} );
        if ( !$failed1 ) {    #actually print OTU taxonomy
            die "Can;t find $_ key in utax\n" unless ( exists( $utStr{$_} ) );
            print H $utStr{$_} . "$_\n";
        }
    }

    #die "UTAX: ".@faKeys." unassigned OTUs\n";
    close H;
    return ( \%fails );
}

sub writeBlastHiera($ $ $) {
    my ( $taxr, $avOTUsR, $failsR ) = @_;

    #my %fails = %{$failsR};
    my %fails  = %{$failsR};
    my @avOTUs = @{$avOTUsR};
    my $cnt    = 0;
    open H, ">", $SIM_hierFile or die "Can't open $SIM_hierFile\n";
    print H "OTU\tDomain\tPhylum\tClass\tOrder\tFamily\tGenus\tSpecies\n";
    #
    foreach ( keys(%fails) ) {
        if (   exists( ${$taxr}{$_} )
            && ${$taxr}{$_}
            && maxTax( ${$taxr}{$_} ) > 0 )
        {
            delete $fails{$_};
        }
        else {
            print H $_ . "\t?\t?\t?\t?\t?\t?\t?" . "\n";
        }
    }
    foreach (@avOTUs) {    #(sort(keys(%{$taxr}))){
         #if ( exists( ${$taxr}{$_}) && !exists( ${$taxDepr}{$_}) ) {print "entry missing: $_\n";}
         #print maxTax(${$taxr}{$_}). "HH\n";
        my $tdep = 0;
        next if ( exists( $fails{$_} ) );
        $tdep = maxTax( ${$taxr}{$_} )
          if ( exists( ${$taxr}{$_} ) && ${$taxr}{$_} );
        if ( $tdep > 0 ) {
            print H $_ . "\t" . blastFmt( ${$taxr}{$_}, $tdep ) . "\n";
        }
        else {
            print H $_ . "\t?\t?\t?\t?\t?\t?\t?\t" . "\n";
            $fails{$_} = 1;
        }
        $cnt++;
    }
    close H;
    return ( \%fails );
}

sub checkLtsVer($) {
    my ($lver)  = @_;
    my $sdmVstr = `$sdmBin -v`;
    my $sdmVer  = 1;
    if ( $sdmVstr =~ m/sdm (\d\.\d+) \D+/ ) {
        $sdmVer = $1;
    }
    else {
        $sdmVstr = `$sdmBin`;

        #die $sdmVstr;
        if ( $sdmVstr =~ m/This is sdm version (\d\.\d+) \D+/ ) {
            $sdmVer = $1;
        }
    }

    # compare to server version
    unless ( $checkForUpdates == 1 ) { return $sdmVer; }
    die
"LWP:simple package not installed, but required for automatic update checker!\n deactivate \"CheckForUpdates 0\" in $lotusCfg to circumvent the update checks.\n"
      if ( !$LWPsimple );

    printL "Checking for updates..  ";
    my $url = "http://psbweb05.psb.ugent.be/lotus/lotus/updates/Msg.txt";
    if ( !head($url) ) {
        printL "LotuS server seems to be down!\n";
        return $sdmVer;
    }
    my $updtmpf = get($url);

    my $msg     = "";
    my $hadMsg  = 0;
    my $msgCont = "";
    open( TF, '<', \$updtmpf );
    while (<TF>) { $msg .= $_; }
    close(TF);
    foreach my $lin ( split( /\n/, $msg ) ) {
        my @spl = split /\t/, $lin;
        next if ( @spl == 0 );
        if ( $lver < $spl[0] ) { $msgCont .= $spl[1] . "\n\n" }
        $hadMsg = 1;
    }
    $updtmpf =
      get("http://psbweb05.psb.ugent.be/lotus/lotus/updates/curVer.txt");
    open( TF, '<', \$updtmpf );
    my $lsv = <TF>;
    close(TF);
    chomp $lsv;
    my $msgEnd = "";
    $updtmpf =
      get("http://psbweb05.psb.ugent.be/lotus/lotus/updates/curVerMsg.txt");
    open( TF, '<', \$updtmpf );
    while (<TF>) { $msgEnd .= $_; }
    close(TF);

    $updtmpf =
      get("http://psbweb05.psb.ugent.be/lotus/lotus/updates/UpdateHist.txt");
    my $updates = "";
    open( TF, '<', \$updtmpf );
    $msg = "";
    while (<TF>) { $msg .= $_; }
    close(TF);
    foreach my $lin ( split( /\n/, $msg ) ) {
        my @spl = split /\t/, $lin;
        chomp $lin;
        next if ( @spl < 2 || $spl[0] eq "" );
        $spl[1] =~ m/LotuS (\d?\.\d+)/;
        if ( $lver < $1 ) { $updates .= $spl[0] . "\t" . $spl[1] . "\n" }
    }
    if ( $updates ne "" || $msgCont ne "" ) {
        printL "\n";
        if ( $updates ne "" ) {
            printL
"--------------------------------\nThe following updates are available:\n--------------------------------\n";
            printL $updates;
            printL
              "\n\nCurrent Lotus version is :$lver\nLatest version is: $lsv\n";
        }
        if ( $msgCont ne "" ) {
            printL
"--------------------------------\nThe following messages were on LotuS server:\n--------------------------------\n";
            printL $msgCont;
        }
    }
    else {
        printL "Your LotuS version is up-to-date!\n";
        return $sdmVer;
    }

    if ( $hadMsg || $updates ne "" ) {
        printL
"New LotuS updates discovered (10s wait).\nIf you want to install updates\n  (1) Press \"Ctrl-c\"\n  (2) perl autoInstall.pl\n\n";
        printL
"To deactivate, open $sdmOpt and change \"CheckForUpdates\" to \"0\"\n";
        sleep(10);
    }
    printL "Continuing LotuS run..\n";

    #die;
    return $sdmVer;
}

sub readMap() {

    #find number of samples
    #my @avSMPs = ();
    printL( frame("Reading mapping file"), 0 );
    my %mapH;
    my %combH;
    unless ( open M, "<", $map ) {
        printL( "Couldn't open map file $map: $!\n", 3 );
    }
    local $/ = undef;
    my $mapst = <M>;
    $mapst =~ s/\r\n|\n|\r/\n/g;
    close M;

    #$mapst=~s/\R//g;
    my @mapar = split( /\n/, $mapst );

    #try mac file conversion
    #if (scalar(@mapar) == 1){ @mapar = split(/\r\n/,$mapst);}
    #if (scalar(@mapar) == 1){ @mapar = split(/\r/,$mapst);}
    my $cnt          = 0;
    my $warnTrig     = 0;
    my $fileCol      = -1;
    my $twoFiles     = 0;
    my $CombineCol   = -1;
    my $hasCombiSmpl = 0;
    my $colCnt       = -1;

    foreach my $line (@mapar) {
        $cnt++;
        next if ( $cnt > 1 && ( $line =~ m/^#/ || length($line) < 2 ) );
        chomp($line);
        my @spl = split( "\t", $line );
        if ( @spl == 0 ) {
            $warnTrig = 1;
            finWarn(
"Mapping file contains lines that cannot be split by tab seperator (line $cnt):\"$line\"\n"
            );
            next;
        }
        if ( $colCnt != -1 && @spl != $colCnt ) {
            for ( my $i = @spl ; $i < $colCnt ; $i++ ) { $spl[$i] = ""; }
        }
        chomp( $spl[0] );
        if ( $spl[0] eq "" ) {
            $warnTrig = 1;
            finWarn("Empty SampleID in row number $cnt, skipping entry.\n");
            next;
        }
        my $smplNms = $spl[0];
        if ( $fileCol != -1 ) {
            if ( $spl[$fileCol] =~ m/,/ ) {
                printL "Switching to paired end read mode\n", 0
                  if ( $numInput != 2 );
                $numInput = 2;
            }
            elsif ( $numInput == 2 ) {
                printL
"Inconsistent file number in mapping. See row with ID $smplNms.\n",
                  55;
            }
        }
        if ( $CombineCol != -1 && $spl[$CombineCol] ne "" ) {
            $combH{ $spl[$CombineCol] } = $smplNms;
        }
        else {
            $combH{$smplNms} = $smplNms;
        }
        if ( $cnt == 1 ) {
            if ( $line !~ m/^#/ ) {
                printL
"First line does not start with \"#\". Please check mapping file for compatibility (http://psbweb05.psb.ugent.be/lotus/documentation.html#MapFile)\n",
                  0;
            }
            my $ccn = 0;
            $colCnt = @spl;
            foreach (@spl) {
                if ( $_ eq "fastqFile" || $_ eq "fnaFile" ) {
                    printL "Sequence files are indicated in mapping file.\n", 0;
                    if ( $fileCol != -1 ) {
                        printL
"both fastqFile and fnaFile are given in mapping file, is this intended?\n";
                    }
                    $fileCol = $ccn;
                }
                if ( $_ eq "CombineSamples" ) {
                    printL "Samples will be combined.\n", 0;
                    $CombineCol   = $ccn;
                    $hasCombiSmpl = 1;
                }

                $ccn++;
            }
        }
        if ( $line =~ m/\"/ ) {
            $warnTrig = 1;
            finWarn(
"Possible biom incompatibility: Mapping file contains \" for sample $smplNms. Lotus is removing this."
            );
        }
        if ( $line =~ m/ / ) {
            $warnTrig = 1;
            finWarn(
"Possible biom incompatibility: Mapping file contains spaces for sample $smplNms"
            );
        }
        if ( $line =~ m/[^\x00-\x7F]/ ) {
            $warnTrig = 1;
            finWarn(
"Possible biom incompatibility: Mapping file contains non-ASCII character for sample $smplNms"
            );
        }
        $line =~ s/\s+/\t/g;
        if ( $smplNms =~ m/^\s/ || $smplNms =~ m/\s$/ ) {
            printL
"SampleID $smplNms contains spaces. Aborting LotuS as this will lead to errors, please fix.\n",
              5;
        }
        if ( $cnt == 1 ) {    #col names
            if ( $line =~ m/\t\t/ ) {
                printL
"Empty column header in mapping file:\n check for double tab chars in line 1:\n$map\n",
                  4;
            }
            if ( $smplNms ne '#SampleID' ) {
                printL
"Missing \'#SampleID\' in first line of file $map\n Aborting..\n",
                  65;
            }

            #if ($line =~/\tCombineSamples\t/){$combineSamples=1;} #deprecated
            my $hcnt = 0;
            foreach (@spl) {
                $hcnt++;
                if (m/^\s*$/) {
                    printL
"Empty column header in mapping file (column $hcnt)\n$map\n",
                      4;
                }
            }
            if ( $line =~ m/\t\t/ ) {
                printL
"Empty header in mapping file:\n check for double tab chars in line 1:\n$map\n",
                  4;
            }
        }
        splice( @spl, 0, 1 );

        #print $smplNms." ".$spl[0]."\n";
        for ( my $i = 0 ; $i < @spl ; $i++ ) {
            $spl[$i] =~ s/\"//g;
        }

        #print $smplNms."\n";
        $mapH{$smplNms} = [@spl];

    }

    #print keys %mapH."\n";
    if ( scalar( keys %mapH ) == 0 ) {
        printL(
"Could not find sample names in mapping file (*nix/win file ending problem?\n",
            9
        );
    }

    if ( $warnTrig == 1 ) {
        print
"*********\nWarnings for mapping file \n$map \nAbort by pressing Ctrl+c (10 sec wait)\n*********\n";
        sleep(10);
    }
    return ( \%mapH, \%combH, $hasCombiSmpl );
}

sub finWarn($) {
    my ($msg) = @_;
    $finalWarnings .= $msg . "\n";
    printL "$msg \n", 0;
}

sub readOTUmat($) {
    my ($file) = @_;

    #my @avSmps = sort(keys %OTUmat);
    open I, "<", $file or die "Can't open expected OTU counts: $file\n";
    my $cnt = -1;
    my @samples;
    my @avOTUs;
    my %OTUm;
    while ( my $line = <I> ) {
        $cnt++;
        chomp($line);
        my @spl = split( "\t", $line );
        if ( $cnt == 0 ) {    #header
            @samples = @spl[ 1 .. $#spl ];

           #die($samples[0]." ".$samples[$#samples]." ".@spl." ".@samples."\n");
            next;
        }
        my $curOT = shift(@spl);
        push( @avOTUs, $curOT );
        for ( my $i = 0 ; $i < @samples ; $i++ ) {
            $OTUm{ $samples[$i] }{$curOT} = $spl[$i];
        }
    }
    close I;
    return ( \%OTUm, \@avOTUs );
}

sub utaxTaxAssign($ $) {
    my ( $query, $taxblastf ) = @_;
    if ( !-f $usBin ) { printL "uearch binary not found: $usBin\n", 81; }
    my $dbfa = $TAX_REFDB[0];
    if ( !-d $dbfa ) { printL "wrong utax input dir: $dbfa\n", 82; }

    #contains path to utax dir
    my $taxLconf = "120";    #250,500,full_length
    if ( $platform eq "454" )    { $taxLconf = 500; }    #454, miSeq, hiSeq
    if ( $platform eq "miseq" )  { $taxLconf = 250; }
    if ( $platform eq "pacbio" ) { $taxLconf = 700; }
    my $utFas  = "$dbfa/fasta/refdb.fa";
    my $utUdb  = "$dbfa/fasta/refdb.$taxLconf.udb";
    my $utConf = "$dbfa/taxconfs/$taxLconf.tc";

    $cmd = "";
    unless ( -e $utUdb ) {
        $cmd .=
          "$usBin -makeudb_utax $utFas -output $utUdb -taxconfsin $utConf\n";
    }
    $cmd .= "$usBin -utax $query -db $utUdb -utaxout $taxblastf -strand both\n";

    #die $utaCmd."\n";

    if ( $exec == 0 ) {
        printL frame(
"Assigning taxonomy against reference using UTAX with confidence $taxLconf bp\nelapsed time: $duration s"
        );

        #print $cmd."\n";
        if ( systemL($cmd) ) { printL "UTAX failed:\n$cmd\n", 3; }
    }
    return $taxblastf;
}

sub doDBblasting($ $ $) {
    my ( $query, $DB, $taxblastf ) = @_;
    my $simMethod = "";

#die "$doBlasting\n";
#if ($doBlasting != 3 && $doBlasting && (-f $blastBin || -f $lambdaBin) && $DB ne "" && -f $DB){
    $REFTAX = 1;
    if ( $doBlasting == 1 ) {
        printL "Could not find blast executable.\n$blastBin\n", 33
          unless ( -f $blastBin );
        printL "Could not find blast executable.\n$mkBldbBin\n", 33
          unless ( -f $mkBldbBin );
        $cmd = "$mkBldbBin -in $DB -dbtype 'nucl'\n";
        unless ( -f $DB . ".nhr" ) {
            if ( systemL($cmd) ) {
                printL "makeBlastDB command failed:\n$cmd\n", 3;
            }
        }
        my $strand = "both";

#if ($exec==0){$strand = get16Sstrand($query,$DB);} #deactivated as speed gain is too moderate for gain
        $cmd =
"$blastBin -query $query -db $DB -out $taxblastf -outfmt 6 -max_target_seqs 200 -perc_identity 75 -num_threads $BlastCores -strand $strand \n"
          ;    #-strand plus both minus
        if ( !-s $query ) { $cmd = "touch $taxblastf"; }
        else {
            $citations .=
"Blast taxonomic similarity search: Altschul SF, Gish W, Miller W, Myers EW, Lipman DJ. 1990. Basic local alignment search tool. J Mol Biol 215: 403–10.\n";
        }
        $simMethod = "BLAST";
    } elsif (0) {    #doesn't work with greengenes, too much mem
        my $udbDB = $DB . ".udb";
        print "\n\nDEBUG\n$udbDB\n";
        if ( !-f $udbDB ) {
            print "Building UDB database\n";
            if (systemL("$usBin -makeudb_ublast $DB -wordlength 14 -output $udbDB")!= 0)
            {
                die("make udb command failed\n");
            }
        }
        print "Starting ublast.. ";
        $cmd = "$usBin -ublast $query -db $udbDB -evalue 1e-9 -accel 0.8 -id 0.75 -query_cov 0.9 -blast6out $taxblastf -strand both -threads $BlastCores";
        print "Done.\n";
        if ( !-s $query ) { $cmd = "touch $taxblastf"; }
        $simMethod = "usearch";
	} elsif ($doBlasting == 4 || $doBlasting == 5){#new default: vsearch 
        my $udbDB = $DB . ".vudb";
        $udbDB = $DB . ".udb" if ($doBlasting == 5 );
        if ( !-f $udbDB ) { 
            print "Building UDB database\n";
			if ($doBlasting == 4 ){
				if (systemL("$VSBinOri  --makeudb_usearch $DB -output $udbDB")){printL "VSEARCH DB building failed\n";}
			} else {
				if (systemL("$usBin  --makeudb_usearch $DB -output $udbDB")){printL "USEARCH DB building failed\n";}
			}
        }
       if ($doBlasting == 4){ 
		$cmd = "$VSBinOri ";
			$citations .= "VSEARCH taxonomic database search: Rognes T, Flouri T, Nichols B, Quince C, Mahé F. (2016) VSEARCH: a versatile open source tool for metagenomics. PeerJ 4:e2584. doi: 10.7717/peerj.2584\n" unless ( $citations =~ m/VSEARCH taxonomic database search/ );
	   }
		$simMethod = "VSEARCH";
		if ($doBlasting == 5){
			$cmd = "$usBin "; 
			$simMethod = "USEARCH";
			$citations .= "USEARCH taxonomic database search: \n" unless ( $citations =~ m/USEARCH taxonomic database search/ );
		}
		$cmd .= "--usearch_global $query --db $udbDB  --id 0.75 --query_cov 0.5 --blast6out $taxblastf --maxaccepts 200 --maxrejects 100 -strand both --threads $BlastCores";
		#die "$cmd\n";
    } elsif ( $doBlasting == 2 ) {    #lambda
        printL "Could not find lambda executable.\n$lambdaBin\n", 33   unless ( -f $lambdaBin );
        my $lamVer  = 0.4;
        my $lverTxt = `$lambdaBin --version`;
        if ( $lverTxt =~ m/lambda version: (\d\.\d)[\.0-9]* \(/ ) {$lamVer = $1;}
        ( my $TAX_REFDB_wo = $DB ) =~ s/\.[^.]+$//;
        print $DB. ".fm.txt.concat\n";
        if (   $lamVer > 0.4
            && -f $DB . ".dna5.fm.sa.val"
            && !-f "$DB.dna5.fm.lf.drv.wtc.24" )
        {
            printL "Rewriting taxonomy DB to Lambda > 0.9 version\n", 0;
            systemL "rm -r $DB.*";
        }
        if ( !-f $DB . ".dna5.fm.sa.val" ) {
            print "Building LAMBDA index anew (may take up to an hour)..\n";

            #die($DB.".dna5.fm.sa.val");
            my $xtraLmbdI = "";
            $xtraLmbdI = " --algorithm skew7ext " if ($lowMemLambI);
            my $cmdIdx =  "$lambdaIdxBin -p blastn -t $BlastCores -d $DB $xtraLmbdI";
            #print $cmdIdx."\n";
            systemL "touch $DB.dna5.fm.lf.drv.wtc.24";
            if ( systemL($cmdIdx) ) {
                printL( "Lamdba ref DB build failed\n$cmdIdx\n", 3 );
            }
        }

        #OMP_NUM_THREADS = $BlastCores
        print "Starting LAMBDA similarity search..\n";

        #TMPDIR env var.. TODO
        my $tmptaxblastf = "$t/tax.m8";
        $cmd = "$lambdaBin -t $BlastCores -id 75 -nm 200 -p blastn -e 1e-8 -so 7 -sl 16 -sd 1 -b 5 -pd on -q $query -d $DB -o $tmptaxblastf\n";
        $cmd .= "\nmv $tmptaxblastf $taxblastf\n";

        #lambda is not guranteed to return sorted list <- apparently it does
        #$cmd .= "sort $tmptaxblastf > $taxblastf;rm $tmptaxblastf";

        if ( !-s $query ) { $cmd = "rm -f $taxblastf;touch $taxblastf\n"; }
        else { $citations .= "Lambda taxonomic similarity search: Hauswedell H, Singer J, Reinert K. 2014. Lambda: the local aligner for massive biological data. Bioinformatics 30: i349-i355\n" unless ( $citations =~ m/Lambda taxonomic similarity search:/ );
        }
        $simMethod = "LAMBDA";

        #die $cmd."\n";
    } else {
        printL "Unknown similarity comparison program option (-simBasedTaxo): \"$doBlasting\"\n", 98;
    }
    if ($extendedLogs) { $cmd .= "cp $taxblastf $extendedLogD/\n"; }
    #die($cmd."\n");
    $duration = time - $start;
	if ( $exec == 0 ) {
		printL frame("Assigning taxonomy against reference using $simMethod\nelapsed time: $duration s");
		#print $cmd."\n";
		if ( systemL($cmd) ) {
			printL "$simMethod against ref database failed:\n$cmd\n", 3;
		}
	}
	return $taxblastf;
}

sub findUnassigned($ $ $ ) {
    my ( $BTr, $Fr, $outF ) = @_;
    my %BT  = %{$BTr};
    my %Fas = %{$Fr};

    #my @t =keys %Fas; print "$t[0]\n";
    my $cnt    = 0;
    my $dcn    = 0;
    my @kk     = keys %Fas;
    my $totFas = @kk;

    if ( $outF eq "" ) {
        foreach my $k ( keys %BT ) {
            my @curT = @{ $BT{$k} };
            if ( @curT == 0 || $curT[0] eq "?" ) { $dcn++; } #|| $curT[1] eq "?"
            $cnt++;
        }
        if ( @kk == 0 ) {
            printL "Total of "
              . ( $cnt - $dcn )
              . " / $cnt reads have LCA assignments\n", 0;
        }
        else {
            printL "$dcn / $cnt reads failed LCA assignments, checked $totFas reads.\n",
              0;
        }
        return;
    }
    foreach my $k ( keys %BT ) {
        my @curT = @{ $BT{$k} };

        #print $k."\t${$BT{$k}}[0]   ${$BT{$k}}[2]\n"
        if ( @curT == 0 || $curT[0] eq "?" ) {    #|| $curT[1] eq "?"){
            delete $BT{$k};
            $dcn++;

            #print ">".$k."\n".$Fas{$k}."\n";
        }    #else {print $k."\t${$BT{$k}}[0]   ${$BT{$k}}[2]\n" ;}
        else {
            die "Can't find fasta entry for $k\n" unless ( exists $Fas{$k} );
            delete $Fas{$k};
        }
        $cnt++;

        #die if ($cnt ==100);
    }
    @kk = keys %Fas;
    printL "$dcn / $cnt reads failed LCA assignments\nWriting " . @kk ." of previous $totFas reads for next iteration.\n", 0;
    open O, ">$outF" or die "can;t open unassigned fasta file $outF\n";
    foreach my $k (@kk) {
        print O ">" . $k . "\n" . $Fas{$k} . "\n";
    }
    close O;
    return ( $outF, \%BT, $dcn, \%Fas );
}

sub assignTaxOnly($ $) {
    my ( $taxf, $output ) = @_;    #,$avSmpsARef
                                   #printL $outmat."\n";

    my $hieraR;
    my $failsR = {};

    #RDP taxonomy
    unless ( $doRDPing < 1 || $otuRefDB eq "ref_closed" ) {
        ( $hieraR, $failsR ) = readRDPtax($taxf); #required to rewrite RDP tax..
    }

    my $blastFlag = $doBlasting != 3 && $doBlasting;       #set that blast has to be done

    my $fullBlastTaxR = {};
    my $GGloaded      = 0;
    my %GG;
    if ( $doBlasting == 3 ) {
        my $utaxRaw = "$t/tax.blast";
        my $utout   = utaxTaxAssign( $taxf, $utaxRaw );
        $failsR = writeUTAXhiera( $utout, $avOTUsR, $failsR );
    }
    elsif ( -f $LCABin && $blastFlag && $maxHitOnly != 1 ) {
        my @blOuts = ();
        for ( my $DBi = 0 ; $DBi < @TAX_REFDB ; $DBi++ ) {
            my $taxblastf = "$t/tax.$DBi.blast";
            my $DB        = $TAX_REFDB[$DBi];
            my $DBtax     = $TAX_RANKS[$DBi];
            my $blastout  = doDBblasting( $taxf, $DB, $taxblastf );
            push( @blOuts, $blastout );
        }
        my $LCxtr = "";
        if ($pseudoRefOTU) { $LCxtr = "-showHitRead -reportBestHit"; }
        my $cmd =  "$LCABin  -i " . join( ",", @blOuts ) . " -r ". join( ",", @TAX_RANKS ) . " -o $SIM_hierFile $LCxtr -LCAfrac $LCAfraction -id ". join( ",", @idThr ) . "\n";

        #die $cmd;
        if ( systemL $cmd) { printL "LCA command $cmd failed\n", 44; }
        systemL "cp @blOuts $output\n";
    }
}

sub makeAbundTable2($ $) {
    my ( $taxf, $retMatR ) = @_;    #,$avSmpsARef
                                    #printL $outmat."\n";

    my $hieraR;
    my $failsR = {};

    #RDP taxonomy
    unless ( $doRDPing < 1 || $otuRefDB eq "ref_closed" ) {
        ( $hieraR, $failsR ) = readRDPtax($taxf); #required to rewrite RDP tax..
    }

    my $blastFlag = $doBlasting != 3 && $doBlasting ;       #set that blast has to be done
    my %fails    = %{$failsR};
    my $curQuery = $OTUfa;

    my $fullBlastTaxR = {};
    my $GGloaded      = 0;
    my %GG;
    if ($REFflag) { #no activated currently
        #$OTUrefSEED
        if ( !$GGloaded ) {
            %GG       = getGGtaxo( $TAX_RANKS[0], $refDBname[0] );
            $GGloaded = 1;
        }

#an extra otu file exists with ref sequences only.. tax needs to be created separately for these & then merged for final output..
#this overwrites all ref OTUs, but de novo OTUs still need to be assigned..
        ($fullBlastTaxR) = extractTaxoForRefs( $OTUrefDBlnk, $fullBlastTaxR, \%GG );
        die "TODO ref assign of denove OTUs\n";
    }
    if ( $doBlasting == 3 ) {
        my $utaxRaw = "$t/tax.blast";
        my $utout   = utaxTaxAssign( $OTUfa, $utaxRaw );
        $failsR = writeUTAXhiera( $utout, $avOTUsR, $failsR );
    }     elsif ( $blastFlag && $maxHitOnly != 1 ) {
		#TODO: maxHitOnly
        my @blOuts = ();
        for ( my $DBi = 0 ; $DBi < @TAX_REFDB ; $DBi++ ) {
            my $taxblastf = "$t/tax.$DBi.blast";
            my $DB        = $TAX_REFDB[$DBi];
            my $DBtax     = $TAX_RANKS[$DBi];
            my $blastout  = doDBblasting( $curQuery, $DB, $taxblastf );
            push( @blOuts, $blastout );
        }
        my $LCxtr = "";
        if ($pseudoRefOTU) { $LCxtr = "-showHitRead -reportBestHit"; }
        my $cmd = "$LCABin  -i " . join( ",", @blOuts ) . " -r " . join( ",", @TAX_RANKS ) . " -o $SIM_hierFile $LCxtr -LCAfrac $LCAfraction -id " . join( ",", @idThr ) . "\n";

        #die $cmd;
        if ( systemL $cmd) { printL "LCA command $cmd failed\n", 44; }
        unlink @blOuts;
    }
    else {    #old Perl implementation
        my $taxblastf = "$t/tax.blast";
        my $BlastTaxR = {};                  # my $BlastTaxDepR = {};
                                             #read this only once
        my $leftOver  = 111;
        my $fasrA     = readFasta($OTUfa);
        if ($blastFlag) {                    #do blast taxnomy
            my $DBi = 0;
            printL
"legacy Perl coded LCA is being used. note that for multi DB tax assignments, this version is not recommended. Please ensure that \'LCA\' program is in your lotus dir or try a clean reinstall if you use multiDB tax assignments.\n",
              "w";
            for ( my $DBi = 0 ; $DBi < @TAX_REFDB ; $DBi++ ) {
                my $DB       = $TAX_REFDB[$DBi];
                my $DBtax    = $TAX_RANKS[$DBi];
                my $blastout = doDBblasting( $curQuery, $DB, $taxblastf );

#my @subf = splitBlastTax($taxblastf,$BlastCores);#paralellize getTaxForOTUfromRefBlast#printL "Running tax assignment in ".@subf." threads..\n";	#my @thrs;
#for (my $i=0;$i<@subf;$i++){$thrs[$i] = threads->create(\&getTaxForOTUfromRefBlast,$subf[$i],\%GG,0);}
#for (my $i=0;$i<@subf;$i++){my $ret = $thrs[$i]->join();$BlastTaxR = {%$BlastTaxR,%$ret};}
#---------  single core way --------------
                %GG        = getGGtaxo( $DBtax, $refDBname[$DBi] );
                $GGloaded  = 1;
                $BlastTaxR = getTaxForOTUfromRefBlast( $blastout, \%GG, 0 );
                if ( $DBi < ( @TAX_REFDB - 1 ) ) {
                    ( $curQuery, $BlastTaxR, $leftOver, $fasrA ) =
                      findUnassigned( $BlastTaxR, $fasrA,
                        $OTUfa . "__U" . $DBi . ".fna" );
                    $taxblastf = "$t/tax.blast_rem_$DBi";
                }
                else { findUnassigned( $BlastTaxR, $fasrA, "" ); }
                $fullBlastTaxR = { %$fullBlastTaxR, %$BlastTaxR };
                last if ( $leftOver == 0 );
            }
            printL "Assigned @refDBname Taxonomy to OTU's\n", 0;
            systemL "rm $OTUfa" . "__U*" if ( $DBi > 0 );
        }

        #here do the same check on ref seqs
        if ( $REFflag || $blastFlag ) {
            findUnassigned( $fullBlastTaxR, {}, "" );
            ($failsR) = writeBlastHiera( $fullBlastTaxR, $avOTUsR, $failsR );
        }

        #	my @t = @{${$fullBlastTaxR}{"OTU_1"}}; die "@t\n";
        undef $BlastTaxR;
        undef $fullBlastTaxR;

        %fails = %{$failsR};    #my @avOTUs = @{$avOTUsR};
    }
    if ($REFflag) {
        findUnassigned( $fullBlastTaxR, {}, "" );
        ($failsR) = writeBlastHiera( $fullBlastTaxR, $avOTUsR, $failsR );
        die "TODO ref blast\n";
    }

    #get number of samples from aref
    #my @avSMPs = @{$avSmpsARef};
    #sanity check
    #foreach(@avSMPs){die("$_ key not existant") unless (exists($retMat{$_}));}

    return ( \%fails );
}

sub cutUCstring($) {
    my ($aref) = @_;
    my @in = uniq( @{$aref} );

    #my @sa = sort (@in);
    #die("@in\n");
    my @newa = ();
    foreach (@in) {
        my @spl = split($sep_smplID);
        push( @newa, $spl[0] );
    }
    return \@newa;
}

sub mergeUCs($ $) {
    my ( $cref, $dref ) = @_;
    my %cons   = %{$cref};
    my %derep  = %{$dref};
    my $cnt    = 0;
    my $totlen = keys %cons;
    foreach my $k ( keys %cons ) {

        #print $cnt." / ".$totlen."  ".@{$cons{$k}}."\n";
        #if (@{$cons{$k}} == 0){die "$k\n";}
        my @newa = @{ $derep{$k} };  #first add initial seed, should be the same
        die "$k not in derep\n" unless exists( $derep{$k} );
        foreach my $k2 ( @{ $cons{$k} } ) {
            push( @newa, @{ $derep{$k2} } );

            #print "added $k2 to $k\n";
        }
        $cons{$k} = \@newa;
        $cnt++;
    }
    printL "finished merging\n", 0;
    return %cons;
}

sub delineateUCs($ $) {
    my ( $ifi, $mode ) = @_;
    open UC, "<", $ifi;
    my %clus;
    my %expSize = ();
    while ( my $line = <UC> ) {
        chomp($line);
        my @spl     = split( "\t", $line );
        my $hit     = $spl[9];
        my $que     = $spl[8];
        my $hitsize = 1;
        my $quesize = 1;
        if ( $mode >= 1 ) {

            # if $mode==1;
            if ( $mode == 1 ) { $que =~ s/;size=(\d+).*$//; $quesize = $1; }
            $hit =~ s/;size=(\d+).*$//;
            $hitsize = $1;
        }
        if ( $mode == 3 )
        { #switch hit and que, because in UPARSE case, reads are aligned to OTUs (= not backtracing)
                #print($quesize." ".$hitsize."\n");
            my $temp = $hit;
            $hit     = $que;
            $que     = $temp;
            $temp    = $hitsize;
            $hitsize = $quesize;
            $quesize = $temp;
        }

        if ( $spl[0] eq "H" ) {    #in cluster
            if ( exists( $clus{$hit} ) ) {
                push( @{ $clus{$hit} }, $que );
                $expSize{$hit} += $quesize;
            }
            else {
                my @empty = ( $hit, $que );
                $clus{$hit}    = \@empty;
                $expSize{$hit} = $quesize + $hitsize;
            }
        }
        if ( $spl[0] eq "S" ) {    #starts new cluster

            #	print $hit." ".$que."\n"; die();
            if ( !exists( $clus{$que} ) ) {
                my @empty = ($que);
                $clus{$que}    = \@empty;
                $expSize{$que} = $quesize;
            }
        }
        if ( $mode != 2 ) {
            if ( $spl[0] eq "C" )
            { #all "H" should have appeared at this point; cross-check if cluster size is right

                if ( !exists( $clus{$que} ) ) {
                    die("Entry for $que does not exist (but should exist).\n");
                }
                else {
                    my $arraySize = scalar( @{ $clus{$que} } );
                    if ( $spl[2] != $expSize{$que} ) {
                        printL(
                            "$que :: expected "
                              . $spl[2]
                              . " cluster size. found cluster size: "
                              . $expSize{$que}
                              . " from array with S $arraySize.\n",
                            0
                        );
                        foreach ( @{ $clus{$que} } ) {
                            printL $_. "\n", 0;
                        }
                        die();
                    }
                }
            }
        }
    }
    close UC;
    return \%clus;
}

sub uniq {
    my %seen;
    return grep { !$seen{$_}++ } @_;
}

sub cdhitOTUs() {

    #my ($outfile) = @_;
    my $BlastCores  = 8;
    my $nseqs_input = `grep \">\" $input | wc -l`;
    printL $nseqs_input. " reads\n", 0;

    my $cdh454 = "/home/falhil/bin/cd-hit_v461/./cd-hit-454";
    my $cmd =
      $cdh454 . " -i $input -o $t/OTUs.fa -c .$id_OTU -M 0 -T $BlastCores";
    print $cmd. "\n";
    my $OTUfa = "$t/OTUs.fa";

    my $cdhConBin = "/home/falhil/bin/cdhit-clcon/./cdhit-cluster-consensus";
    $cmd = $cdhConBin . " $OTUfa $input $t/Consensus.fa";
    print $cmd. "\n";
    die();
    my $UCfil = "";
    return ( $UCfil, $OTUfa );
}

sub print_nseq($) {
    my ($tf) = @_;
    my $nseqs = `grep \">\" $tf | wc -l`;
    printL( $nseqs . " reads\n", 0 );
    return ($nseqs);
}

sub printL($ $) {
    my ( $msg, $stat ) = @_;
    if ( defined $stat && $stat eq "w" ) {
        finWarn($msg);
        return;
    }
    print $msg;
    if ( $mainLogFile ne "" ) {
        print LOG $msg;
    }
    if ( defined $stat && $stat ne "0" ) { exit($stat); }
}

sub systemL($) {
    my ($subcmd) = @_;

    # $subcmd.=" 2>&1 | tee -a $mainLogFile";
    # my $sysoutp = `$subcmd 2>&1`;
    # print $stdout;
    # print LOG $stdout;
    # print callLog $subcmd."\n";
    #printL("[cmd] $subcmd\n",0);
	print cmdLOG "[cmd] $subcmd\n";
    return system($subcmd);
    # return $ENV{'PIPESTATUS[0]'};
}

sub announceClusterAlgo{
	   if ( $ClusterPipe == 0 ) {
		printL "\n\n--------- OTUPIPE ----------- \nelapsed time: $duration s\n\n",0;
	} elsif ( $ClusterPipe == 1 ) {
        printL"\n\n--------- UPARSE clustering ----------- \nelapsed time: $duration s\n\n", 0;
	} elsif ( $ClusterPipe == 6 ) {
        printL"\n\n--------- UNOISE clustering ----------- \nelapsed time: $duration s\n\n", 0;
    }
    elsif ( $ClusterPipe == 2 ) {
        printL"\n\n--------- SWARM clustering ----------- \nelapsed time: $duration s\n\n",0;
    }
    elsif ( $ClusterPipe == 3 ) {printL"\n\n--------- CD-HIT clustering ----------- \nelapsed time: $duration s\n\n",0;
    }
    elsif ( $ClusterPipe == 4 ) {
        printL"\n\n--------- DNACLUST clustering ----------- \nelapsed time: $duration s\n\n",0;
    }  elsif ( $ClusterPipe == 7 ) {
        printL"\n\n--------- DADA2 OTU clustering ----------- \nelapsed time: $duration s\n\n",0;
    }

}



sub splitFastas($ $) {
    my ( $inF, $num ) = @_;
    my $protN = `grep -c '^>' $inF`;
    chomp $protN;
    my $pPerFile = int( $protN / $num ) + 1;
    my $fCnt     = 0;
    my $curCnt   = 0;
    my @nFiles   = ("$inF.$fCnt");

    open I, "<$inF" or printL "Fatal: Can't open fasta file $inF\n", 59;
    open my $out, ">$inF.$fCnt"
      or printL "Fatal: Can't open output fasta file $inF.$fCnt\n", 59;
    while ( my $l = <I> ) {
        if ( $l =~ m/^>/ ) {
            $curCnt++;
            if ( $curCnt > $pPerFile ) {
                $fCnt++;
                close $out;
                open $out, ">$inF.$fCnt";
                push( @nFiles, "$inF.$fCnt" );
                $curCnt = 0;
            }
        }
        print $out $l;
    }
    close I;
    close $out;
    return \@nFiles;
}

sub extractFastas($ $ $) {
    my ( $in, $hr, $addSize ) = @_;
    my %tars = %{$hr};
    my %fasSubs;
    my $hd = "";
    open I, "<$in" or printL "Fatal: Can't open fasta file $in\n", 59;
    my $use = 0;
    while ( my $l = <I> ) {
        chomp $l;
        if ( $l =~ m/^>/ ) {
            $use = 0;
            $l =~ m/^>(\S+)/;
            $hd = $1;
            if ( exists( $tars{$hd} ) ) {
                if ($addSize) { $hd .= ";size=" . $tars{$hd} . ";"; }
                $use = 1;
                $fasSubs{$hd} = "";
            }
            next;
        }
        $fasSubs{$hd} .= $l if ($use);
    }
    close I;
    return \%fasSubs;
}

sub combine($ $) {
    my ( $fadd, $freal ) = @_;
    if ( $osname eq 'MSWin32' ) {
        systemL("type $fadd  $freal > $freal");
    }
    else {
        systemL("cat $fadd >> $freal");
    }
    unlink("$fadd");
}

sub usearchDerepSort($ ) {
    my ($filtered) = @_;
    my $outputLab = "-output";
    if ( $usearchVer >= 8 && $VSused == 0 ) { $outputLab = "-fastaout"; }

    printL(
"\n =========================================================================\n Dereplicate exact sub-sequences & sort (usearch).\n ",
        0
    );
    $cmd = "$VSBin -derep_fulllength $filtered $outputLab $t/derep.fa -uc $t/derep.uc -log $logDir/derep.log -sizeout -threads $uthreads";

    #die($cmd);
    if ( systemL($cmd) != 0 ) { printL "Failed dereplication\n", 1; }

    my $dcnt          = 1;
    my $bigDerepCnt   = 0;
    my @lotsFiles     = ($filtered);
    my @subDerepFa    = ("$t/derep.fa");    #my @subDerepUC = ("$t/derep.uc");
    my @subDerepFaTmp = ();
    while ( -f $filtered . "." . $dcnt ) {
        if ( $dcnt == 1 ) { @subDerepFaTmp = @subDerepFa; @subDerepFa = (); }
        push( @lotsFiles,     $filtered . "." . $dcnt );
        push( @subDerepFaTmp, "$t/derep.fa.$dcnt" )
          ;    #push(@subDerepUC,"$t/derep.uc.$dcnt");
        $cmd = "$VSBin -derep_fulllength $filtered.$dcnt $outputLab $subDerepFaTmp[-1] -sizeout -threads $uthreads"
          ;    #-uc $t/derep.uc -log $logDir/derep.log
               #die $cmd;
        if ( systemL($cmd) != 0 ) { printL "Failed dereplication\n", 1; }
        if ( -f $filterOutAdd . "." . $dcnt ) {

            #Combining low qual reads..
            combine( $filterOutAdd . "." . $dcnt, $filterOutAdd );
        }
        if ( ( $dcnt + 1 ) % 10 == 0 || !-f $filtered . "." . ( $dcnt + 1 ) )
        {      #intermediary merge.. too big otherwise
            my $firstF = shift(@subDerepFaTmp);

            #print join(" ",@subDerepFaTmp)."\n";
            my $pid =
              open( CMD,
                "| cat " . join( " ", @subDerepFaTmp ) . " >> $firstF" )
              || printL "Merge of derep subfiles failed.\n", 1;
            defined($pid) || printL( "Cannot fork derep of subfiles.\n", 1 );
            close CMD;
            foreach (@subDerepFaTmp) { unlink; }
            @subDerepFaTmp = ();

            my $dereOut = "$t/derep.inter.$bigDerepCnt.temp";
            $cmd = "$VSBin -derep_fulllength $firstF $outputLab $dereOut -uc $t/derep.uc -log $logDir/derep.log -sizeout -threads $uthreads";
            if ( systemL($cmd) != 0 ) {
                printL "Failed intermediate dereplication\n", 1;
            }
            newUCSizes( $dereOut, "$t/derep.uc" );

            #delete tmp files
            unlink("$t/derep.uc");
            unlink("$firstF");
            push( @subDerepFa, $dereOut );
            $bigDerepCnt++;

            #consecutive bigger files
            if ( @subDerepFa > 1 ) {
                $firstF = shift(@subDerepFa);
                $pid    = open( CMD,
                    "| cat " . join( " ", @subDerepFa ) . " >> $firstF" );
                defined($pid)
                  || printL( "Cannot fork derep of subfiles.\n", 1 );
                close CMD || printL "Merge of derep subfiles failed.\n", 1;
                $cmd = "$VSBin -derep_fulllength $firstF $outputLab $t/derep.post.temp -uc $t/derep.uc -log $logDir/derep.log -sizeout -threads $uthreads";
                print $cmd. "\n";
                systemL $cmd || printL "Derep Command Failed: \n$cmd\n", 1;
                newUCSizes( "$t/derep.post.temp", "$t/derep.uc" );
                foreach (@subDerepFa) { print $_. "\n"; unlink; }
                systemL("mv $t/derep.post.temp $t/derep.fa");
                unlink("$t/derep.pre.temp");
                @subDerepFa = ("$t/derep.fa");
            }
            elsif ( !-f $filtered . "." . ( $dcnt + 1 ) ) {
                systemL("mv $subDerepFa[0] $t/derep.fa");
            }
        }
        $dcnt++;
    }
    my $dereplicate_minsizeX = $dereplicate_minsize;
    $dereplicate_minsizeX =~ m/^(\d+)\D?/;
    $dereplicate_minsizeX = $1;
    printL
"Reset derep min to $dereplicate_minsizeX, as u/vsearch does not support more complex options\n",
      "w";

    #dereplicate_minsize is 2 by default
    $cmd =
"$VSBin -sortbysize  $t/derep.fa $outputLab $t/derep.fas -minsize $dereplicate_minsizeX -log $logDir/sortbysize.log";
    if ( systemL($cmd) != 0 ) { exit(1); }
    unlink("$t/derep.fa");
    return ("$t/derep.fas");
}

sub parseSDMlog($) {
    my ($inF) = @_;
    open I, "<", $inF;
    my $totSeq = 0;
    my $SeqLen = 0;
    while (<I>) {
        chomp;
        if (m/^Accepted: (\d+) \(/) { $totSeq = $1; }
        if (m/^\s+\- Seq Length : \d+\/(\d+)\/\d+/) { $SeqLen = $1; }
    }
    close I;

    #die $totSeq." " .$SeqLen."\n";
    return ( $totSeq, $SeqLen );

    #"Accepted: 349515 (0 end-trimmed)","    - Seq Length : 250/250/250"

}

sub removeNonValidCDhits($ $ $) {
    my ( $refDB4otus, $addon, $denNN ) = @_
      ; #idea is to use the addon.clstr to find refSeqs that were used the denNN file (are not in there)

}

sub dnaClust2UC($ $) {
    my ( $in, $out ) = @_;
    print "DNAclust1";
    my %cluster;
    my %clSize;
    my %clus_denovo;
    my %clDNSize;
    open I, "<$in" or printL "Fatal: Can't open dnaclust output $in\n", 38;
    while ( my $line = <I> ) {
        my @spl = split( /\s/, $line );
        next unless ( @spl > 1 );    #/data/falhil/otutmpAN1//clusters.uc
        my $curCl = shift(@spl);

        #print $curCl."\n";
        my $siz = 0;
        foreach (@spl) { m/;size=(\d+);/; $siz += $1; }
        die "DNAclust:: double Cluster detected: $curCl\n"
          if ( exists( $clus_denovo{$curCl} )
            || exists( $clus_denovo{$curCl} ) );
        if ( $curCl =~ m/;size=\d+;/ ) {    #denovo cluster
            $clus_denovo{$curCl} = \@spl;
            $clDNSize{$curCl}    = $siz;
        }
        else {                              #ref cluster
            $cluster{$curCl} = \@spl;
            $clSize{$curCl}  = $siz;
        }
    }
    close I;
    my @refs  = keys %cluster;
    my $CLnUM = 0;

    #print ref clusters in UC format
    #print "uc\n";
    open O, ">$out.ref"
      or printL "Fatal: Can't open dnaclust uc rewrite $in\n", 37;
    foreach my $k (@refs) {
        my @mem = @{ $cluster{$k} };
        my $ref = $k;                  #.";size=".@mem.";";
            #print O "H\t$CLnUM\t170\t100.0\t+\t0\t0\t170M\t$ref\t$ref\n";
        foreach my $mm (@mem) {
            print O "H\t$CLnUM\t170\t100.0\t+\t0\t0\t170M\t$mm\t$ref\n";
        }
        $CLnUM++;
    }
    close O;

    #print denovo clusters in UC format
    open O, ">$out" or printL "Fatal: Can't open dnaclust uc rewrite $in\n", 37;
    foreach my $k ( keys %clus_denovo ) {
        my @mem = @{ $clus_denovo{$k} };
        my $ref = $k;                      #.";size=".@mem.";";
        print O "N\t$CLnUM\t170\t100.0\t+\t0\t0\t170M\t$ref\t$ref\n";
        foreach my $mm (@mem) {
            print O "H\t$CLnUM\t170\t100.0\t+\t0\t0\t170M\t$mm\t$ref\n";
        }
        $CLnUM++;
    }
    close O;

    #die " done\n$out\n";
    return ( \%cluster, \%clSize, \%clus_denovo, \%clDNSize );
}

##################################################
# Core cluster routing on quality filtered files #
##################################################
sub buildOTUs($) {

    my ($outfile) = @_;
    my @UCguide = ( "$t/finalOTU.uc", "$t/finalOTU2.uc" );    #,"$t/otus.uc",1);

    #if ($exec==1){return(\@UCguide);}
    systemL "rm -f $UCguide[0]*";

    my $refDB4otus = "$TAX_REFDB[0]" if ( @TAX_REFDB > 0 );  #reference database

    #print_nseq("$filterOut");
    my $filtered = "$t/filtered.fa";

    if ($UPARSEfilter) {
        printL("\n =========================================================================\n Secondary uparse filter\n",0  );
        my $cmd = "$usBin -fastq_filter $filterOut -fastaout $filtered -fastq_trunclen $truncLfwd -threads $uthreads";

        #-fastq_truncqual $truncQual
        #die($cmd."\n");
        if ( systemL($cmd) != 0 ) { exit(1); }
    }
    else {
        $filtered = $filterOut;
    }

    my $derepl = "$t/derep.fas";    #,$totSeqs,$arL)
    my ( $totSeqs, $SeqLength ) = parseSDMlog("$logDir/demulti.log");
    if ( !$sdmDerepDo ) {
        my ($derepl) = usearchDerepSort($filtered);
    }
    else {
        if ( !-f $derepl || -z $derepl ) {
            printL "The sdm dereplicated output file was either empty or not existing, aborting lotus.\n$derepl\n",1;
        }

#my @lotsFiles = ($filtered); my $dcnt=1; while (-f $filtered.".".$dcnt){	push(@lotsFiles,$filtered.".".$dcnt);$dcnt++}
    }
    my $OTUfastaTmp = $outfile;                 #"$t/uparse.fa";
    my $dnaclustOut = "$t/clusters_pre.dncl";

    #have to rev seq for dnaclust & cd-hit ref clustering
    if ($REFflag) {
        my $strand = get16Sstrand( $derepl, $refDB4otus );
        print $strand. " strand\n";
        if ( $strand eq "minus" ) {
            printL "reversing 16S for alignment to DB..\n", 0;
            revComplFasta($derepl);
        }
    }

    if ( $ClusterPipe == 1 ) { #UPARSE clustering
        my $maxhot  = 62;
        my $maxdrop = 12;
        #too many files need a more thorough clustering process
        if ( $totSeqs > 12000000 && $totSeqs < 24000000 ) {
            $maxhot  = 72;
            $maxdrop = 15;
        }
        elsif ( $totSeqs >= 24000000 ) {
            $maxhot  = 92;
            $maxdrop = 18;
        }
        my $id_OTUup    = $id_OTU;
        my $outputLab   = "-output";
        my $idLabel     = "-id";
        my $xtraOptions = "";
        if ( $usearchVer >= 10 ) {    #just to control id percentage
            $idLabel  = "";
            $id_OTUup = "";
            if ( $id_OTU != 0.97 ) {
                printL "UPARSE 10 does only support 97% id OTU clusters\n", "w";
            }
        }
        elsif ( $usearchVer >= 8 ) {
            $idLabel  = "-otu_radius_pct";
            $id_OTUup = 100 - ( $id_OTU * 100 );
            if ( $id_OTUup < 0 || $id_OTUup > 50 ) {
                printL
                  "UPARSE cluster radius $id_OTUup not valid, aborting..\n", 54;
            }
        }
        if ( $usearchVer >= 8 ) {
            $xtraOptions .= " -uparseout $UCguide[0] ";    #-sizeout sizein
            $outputLab = "-fastaout";
        }
        if ( $usearchVer >= 8 && $usearchVer < 9 ) {       #8 specific commands
            $xtraOptions .=" -sizeout -sizein -uparse_maxhot $maxhot -uparse_maxdrop $maxdrop ";
        }
        if ( $noChimChk == 1 || $noChimChk == 2 ) {  #deactivate chimera de novo
            $xtraOptions .= " -uparse_break -999 ";
        }
        printL("\n =========================================================================\n UPARSE core routine\n Cluster at "
              . 100 * $id_OTU
              . "%\n=========================================================================\n",0);

        $cmd = "$usBin -cluster_otus $derepl -otus $OTUfastaTmp $idLabel $id_OTUup -log $logDir/UPARSE.log $xtraOptions";    # -threads $uthreads"; # -uc ".$UCguide[2]."
        $citations .= "UPARSE OTU clustering - Edgar RC. 2013. UPARSE: highly accurate OTU sequences from microbial amplicon reads. Nat Methods.\n";
		#die $cmd."\n";
    }
    elsif ( $ClusterPipe == 7 ) { #dada2
        printL("\n =========================================================================\n DADA2 ASV clustering\n Dereplication of reads\n=========================================================================\n",0);
		die "incorrect dada2 script defined" unless (-f $dada2Scr);
		$cmd = "$Rscript $dada2Scr $sdmDemultiDir $sdmDemultiDir $dada2Seed $uthreads\n";
		$cmd .= "mv -f $sdmDemultiDir/*.pdf $logDir\n";
		$cmd .= "cp $sdmDemultiDir/uniqueSeqs.fna $OTUfastaTmp\n";
		$citations .= "DADA2 ASV clustering - Callahan BJ, McMurdie PJ, Rosen MJ, et al. DADA2: High-resolution sample inference from Illumina amplicon data. Nat Methods 2016;13:581–3. doi:10.1038/nmeth.3869\n";
	}
    elsif ( $ClusterPipe == 6 ) { #unoise3
        printL("\n =========================================================================\n UNOISE core routine\n Cluster at ". 100 * $id_OTU . "%\n=========================================================================\n",0);
	
        $cmd = "$usBin -unoise3 $derepl -zotus $OTUfastaTmp -tabbedout $logDir/unoise3_longreport.txt -log $logDir/unoise3.log ";    # -threads $uthreads"; # -uc ".$UCguide[2]."
        $citations .= "UNOISE ASV (zOTU) clustering - R.C. Edgar (2016), UNOISE2: improved error-correction for Illumina 16S and ITS amplicon sequencing, https://doi.org/10.1101/081257 \n";
		#die $cmd."\n";
    } elsif ( $ClusterPipe == 2 ) {

#prelim de novo OTU filter
#$cmd="$usBin -uchime_denovo  $derepl -chimeras $t/chimeras_denovo.fa -nonchimeras $t/tmp1.fa -abskew $chimera_absskew -log $logDir/uchime_dn.log";
#if (systemL($cmd) != 0){exit(1);}	systemL("ls -lh $t/tmp1.fa");
        if ( !-e $swarmBin ) {
            printL "No valid swarm binary found at $swarmBin\n", 88;
        }
        printL("\n =========================================================================\n SWARM OTU clustering\n Cluster with d = ". $swarmClus_d. "\n=========================================================================\n",0);

        #-z: unsearch size output. -u uclust result file
        my $uclustFile = "$t/clusters.uc";
        my $dofasti    = "-f ";
        if ( $swarmClus_d > 1 ) { $dofasti = ""; }
        $cmd = "$swarmBin -z $dofasti -u $uclustFile -t $uthreads -w $OTUfastaTmp --ceiling 4024 -s $logDir/SWARMstats.log -l $logDir/SWARM.log -o $t/otus.swarm -d $swarmClus_d < $derepl";
        $citations .= "swarm v2 OTU clustering - Mahé F, Rognes T, Quince C, de Vargas C, Dunthorn M. 2015. Swarm v2: highly-scalable and high-resolution amplicon clustering. PeerJ. DOI: 10.7717/peerj.1420\n";

#perl script to replace swarm size with usearch size
#print $cmd."\n";
#create OTU fasta ($OTUfastaTmp)
#$cmd .= "\ncut -d \" \" -f 1 $t/otus.swarm | sed -e 's/^/>/' > $t/tmp_seeds.txt";
#$cmd.= "\ngrep -A 1 -F -f $t/tmp_seeds.txt $derepl | sed -e '/^--\$/d' > $OTUfastaTmp";
    }
    elsif ( $ClusterPipe == 3 ) {
        if ( !-e $cdhitBin ) {
            printL "No valid CD-Hit binary found at $cdhitBin\n", 88;
        }
        printL("\n =========================================================================\n CD-HIT OTU clustering\n Cluster at ". 100 * $id_OTU . "%\n=========================================================================\n", 0 );
        if ($REFflag) {  #$otuRefDB eq "ref_closed" || $otuRefDB eq "ref_open"){
            printL "CD-HIT ref DB clustering not supported!\n", 55;
            die();
            $cmd = "$cdhitBin-2d -T $uthreads -o $OTUfastaTmp.2 -c $id_OTU -M 0 -i2 $derepl -i $refDB4otus -n 9 -g 1\n";#-aL 0.77 -aS 0.98
            if ( $otuRefDB eq "ref_open" ) {
                $cmd .= "$cdhitBin -T $uthreads -i $OTUfastaTmp.2 -c $id_OTU -M 0 -o $OTUfastaTmp.3 -n 9 -g 1 -aS 0.98";#.3 are the denovo clusters
                die $cmd . "\n";
                $OTUfastaTmp = removeNonValidCDhits( $refDB4otus, "$OTUfastaTmp.2", "$OTUfastaTmp.3" );
            }
        }
        else {           #de novo
            $cmd = "$cdhitBin -T $uthreads -o $OTUfastaTmp -c $id_OTU -G 0 -M 0 -i $derepl -n 9 -g 0 -r 0 -aL 0.0 -aS 0.9 ";          #-aL 0.77 -aS 0.98
        }
		$citations .= "CD-HIT OTU clustering - Fu L, Niu B, Zhu Z, Wu S, Li W. 2012. CD-HIT: Accelerated for clustering the next-generation sequencing data. Bioinformatics 28: 3150–3152.\n";
    }
    elsif ( $ClusterPipe == 4 ) {    #dnaclust-ref
        my $dnaClOpt = "";
        if ($REFflag) {
            $dnaClOpt .="-l --approximate-filter --predetermined-cluster-centers $refDB4otus ";
            $dnaClOpt .= "--recruit-only " if ( $otuRefDB eq "ref_closed" );
        }
        else {
            printL "DNACLUST de novo clustering not supported in LotuS.\n", 34;
        }

        #ref_closed
        $cmd ="$dnaclustBin -i $derepl -s $id_OTU -t $uthreads --assign-ambiguous $dnaClOpt > $dnaclustOut \n";

        #die $cmd."\n";
        $citations .="DNACLUST - Ghodsi, M., Liu, B., & Pop, M. (2011). DNACLUST: accurate and efficient clustering of phylogenetic marker genes. BMC Bioinformatics, 12, 271. \n";
    }
    elsif ( $ClusterPipe == 5 ) {    #micca
         #"$otuclustBin $derepl -s $id_OTU  --out-clust $otuclust_clust --out-rep $OTUfastaTmp -f fasta -c"; #-d: fast
         #$citations.= "MICCA";
    }
    else {
        printL "Unkown \$ClusterPipe $ClusterPipe\n", 7;
    }
	#actual excecution
    if ( $exec == 0 ) {
        if ( systemL($cmd) != 0 ) {
            printL( "Failed core OTU clustering command:\n$cmd\n", 1 );
        }
    }
	
	#die $cmd;

    if ( $ClusterPipe == 2 ) {
        swarm4us_size($OTUfastaTmp);
    }

    #--------- ref based clustering ------------
    my ( $refsCL, $refCLSiz, $denovos, $denoSize );
    if ( $ClusterPipe == 4 ) {    #transcribe dnaclust out to .uc
        ( $refsCL, $refCLSiz, $denovos, $denoSize ) =
          dnaClust2UC( $dnaclustOut, $UCguide[0] );
    }
    if ($REFflag) {
        #1=add correct size tag to each (denovo uchime)
        my $fasRef = extractFastas( $refDB4otus, $refCLSiz, 1 );
        #and get denovo cluster centers separate
        my $fasRefDeno = extractFastas( $refDB4otus, $denoSize, 1 );
        #print "fast wr";
        #write fastas out
        writeFasta( $fasRef,     $OTUfastaTmp . ".ref" );
        writeFasta( $fasRefDeno, $OTUfastaTmp );

        #die($OTUfastaTmp."\n");
    }

    #do in later loop
    #print "ASD\n$noChimChk\n$OTUfastaTmp\n$ClusterPipe\n";
	#uparse, unoise, dada2 have their own chimera checks
    if (   $ClusterPipe != 1 && $ClusterPipe != 6 && $ClusterPipe != 7  && -e $OTUfastaTmp && ( $noChimChk == 0 || $noChimChk == 3 ) ){    #not uparse && actual reads in fasta
            #post OTU-pick de novo OTU filter
            #print "GF";

        printL( frame("de novo chimera filter\n"), 0 );
        my $chimOut = "$t/chimeras_denovo.fa";
        if ($extendedLogs) {
            $chimOut = "$extendedLogD/chimeras_denovo.fa";
        }

        $cmd = "$VSBin -uchime_denovo $OTUfastaTmp -chimeras $chimOut -nonchimeras $t/tmp1.fa -abskew $chimera_absskew -log $logDir/chimera_dn.log";

        #die "\n\n$usearchVer\n";
        if (!$useVsearch && $usearchVer >= 10 && !$VSused ) {
            if ( $usearchVer == 10.0 && $usearchsubV <= 240 ) {
                #really dirty hack..
                $cmd ="$VSBinOri -uchime_denovo $OTUfastaTmp -chimeras $chimOut -nonchimeras $t/tmp1.fa -abskew $chimera_absskew -log $logDir/chimera_dn.log";
                printL "Can't do de novo chimer filter, since usearch 10.0.240 currently has a bug with this\nUsing vsearch chimera detection instead\n","w";
            }
            else {
                $cmd = "$usBin -uchime3_denovo $OTUfastaTmp -chimeras $chimOut -nonchimeras $t/tmp1.fa -log $logDir/chimera_dn.log";
            }

            #replace until bug is fixed
        }
        elsif ( $usearchVer >= 9 && !$VSused ) {
            $cmd = "$usBin -uchime2_denovo $OTUfastaTmp -abskew 16 -chimeras $chimOut -nonchimeras $t/tmp1.fa -log $logDir/chimera_dn.log";
        }

        #die $cmd."\n";
        $cmd .= "\nrm $OTUfastaTmp\nmv -f $t/tmp1.fa $OTUfastaTmp";
        if ( systemL($cmd) != 0 ) {
            printL( "uchime de novo failed// aborting\n", 1 );
        }
        if ( $usearchVer >= 9 ) {
            $citations .= "uchime2 chimera detection deNovo: Edgar, R.C. (2016), UCHIME2: Improved chimera detection for amplicon sequences, http://dx.doi.org/10.1101/074252..\n";
        }
        elsif ($VSused) {
            $citations .= "Vsearch chimera detection deNovo: \n";
        }
        else {
            $citations .=
"uchime chimera detection deNovo: Edgar RC, Haas BJ, Clemente JC, Quince C, Knight R. 2011. UCHIME improves sensitivity and speed of chimera detection. Bioinformatics 27: 2194–200.\n";
        }
        systemL("ls -lh $t/tmp1.fa");
    }

    #die "NN\n";


#------------------ 2nd part: --------------------
    #backmap reads to OTUs/ASVs/zOTUs
    my $cnt = 0;
    my @allUCs;
    my $userachDffOpt = "-maxhits 1 --maxrejects 200 -top_hits_only -strand both -id $id_OTU -threads $uthreads";
    my $vsearchSpcfcOpt = " --minqt 0.8 ";
    $vsearchSpcfcOpt = " --minqt 0.3 " if ( $platform eq "454" );
    $vsearchSpcfcOpt = "" if ( !$VSused );
    $vsearchSpcfcOpt .= " --dbmask none --qmask none";

    if ($sdmDerepDo) {
        #only HQ derep need to be mapped, and uparse v8 has this already done
        #my @lotsFiles = ($derepl); #these are dereplicated files
        if (   ( $usearchVer < 8 && $ClusterPipe == 1 )
            || $ClusterPipe == 2 || $ClusterPipe == 6  || $ClusterPipe == 3 || $ClusterPipe == 7 )
        {    #usearch8 has .up output instead
            $cmd =
                "$VSBin -usearch_global ". $derepl. " -db $outfile -uc $UCguide[0] $userachDffOpt $vsearchSpcfcOpt";    #-threads  $BlastCores";
                   #die $cmd."\n";
            if ( systemL($cmd) != 0 ) {
                printL( "vsearch backmapping command aborted:\n$cmd\n", 1 );
            }
        }
    } else {         #map all qual filtered files to OTUs
        if ( $usearchVer >= 8 ) {
            printL "\n\nWarning:: usearch v8 can potentially cause decreased lotus performance in seed extension step, when used with option -highMem 0\n\n",
              0;
            sleep(10);
        }
        my @lotsFiles = ($filtered);
        my $dcnt      = 1;
        while ( -f $filtered . "." . $dcnt ) {
            push( @lotsFiles, $filtered . "." . $dcnt );
            $dcnt++;
        }
        foreach my $fil (@lotsFiles) {
            my $tmpUC = "$t/tmpUCs.$cnt.uct";
            push( @allUCs, $tmpUC );
            $cmd =
                "$VSBin -usearch_global $fil -db $outfile -uc "
              . $tmpUC
              . " -strand both -id $id_OTU -threads $uthreads $vsearchSpcfcOpt"
              ;    #-threads  $BlastCores";
            if ( systemL($cmd) != 0 ) { exit(1); }
            if ( $cnt > 0 ) {
                combine( $fil, $filtered );
                unlink($fil);
            }
            $cnt++;
        }
        if (
            systemL( "cat " . join( " ", @allUCs ) . " > " . $UCguide[0] ) != 0 )
        {
            printL "Merge of UC subfiles failed.\n", 1;
            exit(1);
        }
        foreach (@allUCs) { unlink; }
    }
    my @lotsFiles = ($filterOutAdd);
    my $dcnt      = 1;
    while ( -f $filterOutAdd . "." . $dcnt && $dcnt < 100000 ) {
        push( @lotsFiles, $filterOutAdd . "." . $dcnt );
        $dcnt++;
    }

 #if (@lotsFiles > 0){	systemL ("cat ".join(" ",@lotsFiles)." >>$filterOutAdd");}

    #add in mid qual reads
    foreach my $subF (@lotsFiles) {
        if ( -f $subF && !-z $subF ) {
            #make sure there's at least 2 lines
            open T, "<", $subF;
            my $lcnt = 0;
            while (<T>) { $lcnt++; last if ( $lcnt > 5 ); }
            close T;
            if ( $lcnt > 2 ) {    #file contains reads, so map
                printL frame("Searching with mid qual reads..\n"), 0;
                my $tmpUC = "$t/add.uc";
                $cmd =
                    "$VSBin -usearch_global $subF -db $OTUfastaTmp -uc "
                  . $tmpUC
                  . " $userachDffOpt $vsearchSpcfcOpt"; #-threads  $BlastCores";
                if ( -s $OTUfastaTmp ) {
                    if ( systemL($cmd) != 0 ) { printL( "Failed: $cmd\n", 1 ); }
                }
                else { systemL("touch $tmpUC"); }
                systemL( "cat $tmpUC >> " . $UCguide[0] . ".ADD" );
                unlink $tmpUC;

                #any ref DB to map onto??
                if ( ($REFflag) && -s "$OTUfastaTmp.ref" ) {
                    $cmd = "$VSBin -usearch_global $subF -db $OTUfastaTmp.ref -uc "
                      . $tmpUC . " $userachDffOpt $vsearchSpcfcOpt"
                      ;    #-threads  $BlastCores";
                    if ( systemL($cmd) != 0 ) { printL( "Failed: $cmd\n", 1 ); }
                    systemL( "cat $tmpUC >> " . $UCguide[0] . ".ADDREF" );
                    unlink $tmpUC;
                }
            }
        }
    }

    #add in unique abundant reads
    if ( -s $derepl . ".rest" ) {
#push(@lotsFiles,$derepl.".rest"); #these are sdm "uniques" that were too small to map
#my @lotsFiles2 = ($derepl,$derepl.".rest");
        my $restUC = "$t/rests.uc";
        $cmd =  "$VSBin -usearch_global "
          . $derepl . ".rest" . " -db $OTUfastaTmp -uc $restUC $userachDffOpt $vsearchSpcfcOpt";#-threads  $BlastCores";
        if ( -s $OTUfastaTmp ) {
            if ( systemL($cmd) != 0 ) { exit(1); }
        }
        else { systemL("touch $restUC"); }
        systemL( "cat $restUC >> " . $UCguide[0] . ".REST" );
        unlink $restUC;
        if ( ($REFflag) && -s "$OTUfastaTmp.ref" ) {
            $cmd =
                "$VSBin -usearch_global " . $derepl . ".rest" . " -db $OTUfastaTmp.ref -uc " . $restUC
              . " $userachDffOpt $vsearchSpcfcOpt";    #-threads  $BlastCores";
            if ( systemL($cmd) != 0 ) { printL( "Failed: $cmd\n", 1 ); }
            systemL( "cat $restUC >> " . $UCguide[0] . ".RESTREF" );
            unlink $restUC;
        }
    }

#if (systemL("cat ".join(" ",@allUCs)." >> ".$UCguide[0]) != 0){printL "Merge of UC subfiles failed.\n",1;};
#foreach (@allUCs){unlink;}
    return ( \@UCguide );
}

#eg. $CONT_REFDB_PHIX
#removes all seqs from otusFA, that match at 95% to refDB
sub derepBash($) {

    #SWARM derep way
    my ($filtered) = @_;
    die("DERPRECATED bash derep\n");
    my $derepCmd = 'grep -v "^>" ' . $filtered . ' | \
	grep -v [^ACGTacgt] | sort -d | uniq -c | \
	while read abundance sequence ; do
		hash=$(printf "${sequence}" | sha1sum)
		hash=${hash:0:40}
		printf ">%s_%d_%s\n" "${hash}" "${abundance}" "${sequence}"
	done | sort -t "_" -k2,2nr -k1.2,1d | \
	sed -e \'s/\_/\n/2\' > '
      . "$t/derep.fa";    #amplicons_linearized_dereplicated.fasta
    die $derepCmd . "\n";
    open( CMD, $derepCmd ) || printL( "Can't derep in swarm:\n$derepCmd\n", 1 );
    close CMD;
    return ("$t/derep.fa");
}

sub swarmClust($) {
    my ($outfile) = @_;
    die("DEPRECATED swarm function\n");

    my $swarmThreads = $uthreads;
    my $swPath       = "/home/falhil/bin/swarm-dev/";
    my $swarmBin     = "$swPath/swarm";

    #my $swarmBreakBin = "python $swPath/scripts/swarm_breaker.py";
    my @UCguide = ( "$t/finalOTU.uc", 2 );    #,"$t/otus.uc",1);
    if ( $exec == 1 ) { return ( \@UCguide ); }

    my $filtered = $filterOut;
    my $derepl   = "$t/derep.fas";            #,$totSeqs,$arL)
    if ( !-f $derepl || -z $derepl ) {
        printL
"The sdm dereplicated output file was either empty or not existant, aborting lotus.\n$derepl\n",
          1;
    }

    my ( $totSeqs, $SeqLength ) = parseSDMlog("$logDir/demulti.log");
    my @lotsFiles = ($filtered);
    my $dcnt      = 1;
    while ( -f $filtered . "." . $dcnt ) {
        push( @lotsFiles, $filtered . "." . $dcnt );
        $dcnt++;
    }
    if ( !$sdmDerepDo ) {
        my ($dereplFi) = usearchDerepSort($filtered);
        onelinerSWM($derepl);
        $derepl = $dereplFi;
    }

    return ( \@UCguide );
}

sub annotateFaProTax{
	my ($hir,$FaPr) = @_;
	return unless (defined($FaPr));
	
	 $citations .=
	"FaProTax (functional abundances based on OTUs) - Louca, S., Parfrey, L.W., Doebeli, M. (2016) - Decoupling function and taxonomy in the global ocean microbiome. Science 353:1272-1277\n";
	
}


sub systemW {
    my ($cc) = @_;
    my $ret = systemL $cc;
    if ($ret) { printL "Failed command $cc\n", 99; }
    printL("[sys]: $cc",0);
    return $ret;
}

