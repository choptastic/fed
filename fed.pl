#!/usr/bin/perl

use strict;
use Cwd;

&main(@ARGV);

sub main {
	my ($file) = @_;

	if($file eq "-init") {
		&execute_init(".fed");
	}elsif($file eq "-global") {
		&execute_init($ENV{"HOME"}."/.fedconf");
	}else{
		&execute_file(@_);
	}
}

sub execute_init {
	my($file) = @_;
	my %cfg = &default_config();
	%cfg = load_config($file, %cfg);

	print("Initializing $file\n");

	my $new_config = "";
	my $ignore = join(" ",@{$cfg{"ignore"}});
	$ignore = "none" if($ignore eq "");
	$ignore = &get("Enter any file patterns you wish to ignore.\n
These are file patterns that work with 'grep'.
Separate with spaces. ",$ignore);
	$new_config .= "ignore=$ignore\n";

	my $multiple_matches = $cfg{"multiple_matches"};
	$multiple_matches = &get_until_valid("How to handle multiple matching filenames?",("ask","fail"));
	$new_config .= "multiple_matches=$multiple_matches\n";

	my $no_exist = $cfg{"no_exist"};
	$no_exist = &get_until_valid("How to handle filenames that don't exist?",("ask","create","fail"));
	$new_config .= "no_exist=$no_exist\n";

	if($file =~ /fedconf$/) {
		my $editor = $cfg{"editor"};
		$editor = &get("What would you like to use as your default editor?", $editor);
		$new_config .= "editor=$editor\n";
	
		my $alt_roots = join(" ",@{$cfg{"alt_roots"}});
		$alt_roots = &get("Enter any other filenames you'd like to use whose existence represents the
root of a project (e.g. .git or .hg).
Separate each file by spaces.",$alt_roots);
		$new_config .= "alt_roots=$alt_roots\n";
	}

	open(F, ">$file");
	print F $new_config;
	close F;
	print("New fed config written to $file\n");
}
				

sub execute_file {
	my($file) = @_;

	my %cfg = &default_config();
	%cfg = &load_config($ENV{"HOME"}."/.fedconf",%cfg);

	to_fed_root(%cfg);
	%cfg = &load_config(".fed",%cfg);

	&print_config(%cfg);

	my @files = &get_potential_files($file, %cfg);
	print("Found Files:\n\t".join("\n\t",@files)."\n\n") if($#files>-1);

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




sub extract_extension {
	my ($file) = @_;
	if($file =~ /\.([\w-]+)$/) {
		return $1;
	}else{
		return "";
	}
}

sub get {
	my($prompt, $default) = @_;
	print "$prompt [Default: $default]: ";
	my $val = <STDIN>;
	chomp($val);
	if($val eq "") {
		return $default;
	}else{
		return $val;
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
