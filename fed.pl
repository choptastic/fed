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
			$config{"alt_roots"}=split(' ',$1);
		}elsif(/editor\(([\w\s]*?)\)\s*=\s*(.*)/){
			my $exts = $1;
			my $cmd = $2;
			foreach my $ext (split(' ',$exts)) {
				$config{"editor_$ext"}=$cmd;
			}
		}elsif(/ignore\s*=\s*(.*)/){
			$config{"ignore"}=split(' ',$1);
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
