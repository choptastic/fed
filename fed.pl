#!/usr/bin/perl

use strict;
use Cwd;

&main(@ARGV);

sub main {
	my @argv = @_;
	my ($file) = @argv;

	my %cfg = &default_config();
	%cfg = &load_config("~/.fedconf",%cfg);

	to_fed_root(%cfg);
	%cfg = &load_config(".fed",%cfg);

	&print_config(%cfg);

	my @files = &get_potential_files($file, %cfg);
	print("Found Files:\n\t".join("\n\t",@files)."\n\n");

	&execute_files(\%cfg, $file, @files);
}

sub execute_files {
	my ($cfg, $file, @files) = @_;

	if($#files == -1) {
		&execute_none($cfg, $file);
	}elsif($#files == 0) {
		&execute_single($cfg, $files[0]);
	}elsif($#files > 0) {
		&execute_multiple($cfg, @files);
	}
}

sub execute_none {
	my ($cfg, $file) = @_;
	my $ne = $cfg->{"no_exist"};
	if($ne eq "fail") {
		die("No matching file. Failing per configuration (no_exist = fail)\n");
	}elsif($ne eq "create") {
		&execute_single($cfg, $file);
	}elsif($ne eq "ask") {
		my $response = &get_until_valid("No matching file found. How would you like to proceed? (c)reate or (f)ail",("c","f"));
		if($response eq "c") {
			&execute_single($cfg, $file);
		}elsif($response eq "f") {
			die("No matching file. Failing");
		}
	}
}

sub execute_single {
	my ($cfg, $file) = @_;
	my $editor = $cfg->{"editor"};
	my $ext = &extract_extension($file);
	if(defined($cfg->{"editor_$ext"})) {
		system($cfg->{"editor_$ext"}." \"$file\"");
	}elsif(defined($cfg->{"editor"})) {
		system($cfg->{"editor"}." \"$file\"");
	}else{
		die("No editor defined for file with extension $ext. Either define a univeral editor or add extension-specific editors");
	}
}

sub execute_multiple {
	my($cfg, @files) = @_;
	my $mm = $cfg->{"multiple_matches"};
	if($mm eq "fail") {
		die("Multiple matching files. Failing per configuration (multiple_matches = fail)\n");
	}elsif($mm eq "loadall") {
		die("Load All not implemented");
	}elsif($mm eq "ask") {
		my $file = &ask_multiple(@files);
		&execute_single($cfg, $file);
	}
}

sub ask_multiple {
	my @files = @_;
	print("Multiple Matching Files:\n");
	foreach my $i (keys(@files)) {
		print("\t(".($i+1)."): $files[$i]\n");
	}
	my $filenum = &get_until_valid_range("Which file to load [1-".($#files+1)." or (f)ail]?", 1, $#files+1);
	if($filenum eq "f") {
		die("Cancelling");
	}else{
		return $files[$filenum-1];
	}
}

sub extract_extension {
	my ($file) = @_;
	if($file =~ /\.([\w-]+)$/) {
		return $1;
	}else{
		return "";
	}
}

sub get_until_valid {
	my ($prompt, @list) = @_;
	my $val;
	do {
		print "$prompt (".join("/",@list)."): ";
		$val = <STDIN>;
		chomp($val);
	} while(not($val ~~ @list));
	return $val;
}

sub get_until_valid_range {
	my ($prompt, $min, $max) = @_;
	my $val;
	do {
		print "$prompt: ";
		$val = <STDIN>;
		chomp($val);
	}until($val eq "f" or (&is_integer($val) and $val>=$min and $val<=$max));
	return $val;
}	

sub is_integer {
	my ($val) = @_;
	return !ref($val) and $val == int($val); ## tests whether is numerically equal to itself.
}

sub get_potential_files {
	my ($file, %cfg) = @_;
	my $find = "find . -name \"$file*\"";
	my $filters = "";
	foreach my $ignore (@{$cfg{"ignore"}}) {
		$filters .= " | grep -v \"$ignore\" ";
	}
	my $files = `$find $filters`;
	return split("\n", $files);
}


sub default_config{
	my %config = (
		"alt_roots",[],
		"ignore",["~\$"],
		"no_exist","ask",
		"multiple_matches","ask"
	);
	return %config;
}

sub load_config{
	my($file, %config) = @_;
	if(-e $file){
		return parse_config($file, %config);
	}else{
		return %config;
	}
}

sub parse_config {
	my ($file, %config) = @_;
	
	open F, $file;
	while(<F>) {
		if(/^#/) {
			next;
		}elsif(/editor\s*=\s*(.*)/){
			$config{"editor"} = $1;
		}elsif(/alt_roots\s*=\s*(.+)/){
			my @alt_roots=split(' ',$1);
			$config{"alt_roots"}=\@alt_roots;
		}elsif(/editor\(([\w\s]*?)\)\s*=\s*(.*)/){
			my $exts = $1;
			my $cmd = $2;
			foreach my $ext (split(' ',$exts)) {
				$config{"editor_$ext"}=$cmd;
			}
		}elsif(/ignore\s*=\s*(.*)/){
			my @ignore=split(" ",$1);
			$config{"ignore"}=\@ignore;
			print("Config: ".$config{"ignore"});
		}elsif(/no_exist\s*=\s*(create|fail|ask)/){
			$config{"no_exist"}=$1;
		}elsif(/multiple_matches\s*=\s*(fail|ask|loadall)/){
			$config{"multiple_matches"}=$1;
		}
	}
	close F;
	return %config;
}

sub print_config{
	my (%config) = @_;
	print("Loaded Config:\n");
	foreach my $k (keys(%config)) {
		my $v = &format_config_value($config{$k});
		print "\t$k => $v\n";
	}
	print("\n");
}

sub format_config_value
{
	my ($v) = @_;
	if(ref($v) eq "ARRAY") {
		if($#$v==-1){
			return "[]";
		}else{
			return "[\"".join("\", \"",@$v)."\"]"
		}
	}else{
		return $v;
	}
}

sub to_fed_root {
	my (%config)=@_;
	my @roots = $config{"alt_roots"};
	unshift(@roots, ".fed");
	my $is_root = &is_root(@roots);

	my $cwd = getcwd();
	if($cwd eq "/"){
		die("Error: Not in a fed project. No root file (".join(", ",@roots)." found in parent directories.");
	}elsif($is_root) {
		print("Project Root:\n\t$cwd\n\n");
		return 1;		
	}else{
		chdir("..");
		return &to_fed_root(%config);
	}
}

sub is_root{
	my @roots = @_;
	foreach my $root(@roots) {
		return 1 if(-e $root);
	}
	return 0;
}
