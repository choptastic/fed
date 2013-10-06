#!/usr/bin/perl

use strict;
use Cwd;

sub main() {
	my %cfg = &default_config();
	%cfg = &load_config("~/.fedconf",%cfg);
	to_fed_root(%cfg);
	%cfg = &load_config(".fed",%cfg);

	print(%cfg);
}

sub default_config{
	my %config = (
		alt_roots,(),
		ignore,("~\$"),
		no_exist,"ask",
		multiple_matches,"ask"
	);
	return %config;
}

sub load_config{
	my($file, %config) = @_;
	if(-e $default){
		return parse_config($file, %config);
	}else{
		return %config;
	}
}

sub local_config{
	my(%config) = @_;

sub parse_config {
	my ($file, %config) = @_;

	open F, $file;
	while(<F>) {
		if(/^#/) {
			continue;
		}elsif(/editor\s*=\s*(.*)/){
			$config{editor} = $1;
		}elsif(/alt_roots\s*=\s*.+)/){
			$config{alt_roots}=split(' ',$1);
		}elsif(/editor\(([\w\s]*?)\)\s*=\s*(.*)/){
			my $exts = $1;
			my $cmd = $2;
			foreach my $ext (split(' ',$exts)) {
				$config{"editor_$ext"}=$cmd;
			}
		}elsif(/ignore\s*=\s*(.*)/){
			$config{ignore}=split(' ',$1);
		}elsif(/no_exist\s*=\s*(create|fail|ask)/){
			$config{no_exist}=$1;
		}elsif(/multiple_matches\s*=\s*(fail|ask|loadall)/){
			$config{multiple_matches}=$1;
		}
	}
	close F;
	return %config;
}

sub to_fed_root {
	my (%config)=@_;
	my $roots = $config{alt_roots};
	unshift($alt_roots, ".fed");
	
	if(getcwd()=="/"){
		die("Not in a fed project.");
	}elsif($is_root) {
		return 1;		
	}elsif{
		chdir("..");
		return find_fed(%config);
	}
}

sub is_root{
	my @roots = @_;
	foreach my $root(@roots) {
		return true if(-e $root);
	}
	return false;
}
