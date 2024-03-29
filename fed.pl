#!/usr/bin/perl

use strict;
use warnings;
use Cwd;
#use File::Basename;

&main(@ARGV);

sub version {
	return "0.4.0 (2023-02-01)";
}

sub main {
	my ($file) = @_;

	if($#_ == -1 or $#_>0) {
		&execute_usage();
	}elsif($file eq "-init" || $file eq "--init") {
		&execute_init(".fed");
	}elsif($file eq "-global" || $file eq "--global") {
		&execute_init($ENV{"HOME"}."/.fedconf");
	}elsif($file eq "-prompt" || $file eq "--prompt") {
		&prompt_and_execute_file();
	}elsif($file eq "-screen_prompt" || $file eq "--screen_prompt") {
		&screen_prompt_and_execute_file();
	}else{
		&execute_file(@_);
	}
}

sub screen_prompt_and_execute_file {
	my $STY = $ENV{"STY"};
	my $window_num = &get_window_num();
	system("screen -r $STY -x -X eval \"other\" \"split\" \"focus down\" \"resize 5\" \"select $window_num\"");

	my %seed_config = (
		"screen_prompt_mode",1
	);
	&prompt_and_execute_file(%seed_config);
}

sub screen_resize_window {
	my ($size, $cfg) = @_;
	my $STY = $cfg->{"screen_id"};
	if($cfg->{"screen_prompt_mode"}) {
		system("screen -r $STY -x -X eval \"resize $size\"");
	}
}

sub prompt_and_execute_file {
	my (%cfg) = @_;
	my ($file) = &get("Enter the file pattern to find and open: ", "");
	if($file eq "") {
		&screen_close_region(\%cfg);
		die("Blank search criteria provided");
	} else {
		&execute_file($file, %cfg);
	}
}

sub print_title {
	print "fed :: The (F)inding (ED)itor. Version ".&version()."\n";
}

sub execute_usage {
	&print_title();
	print "Usage: fed -init      # Initializes fed for the local project\n";
	print "       fed -global    # Initializes fed configuration for all your projects\n";
	print "       fed Filename   # Searches for Filename in the project and opens it in your editor\n";
	print "       fed -prompt    # Prompts the user to provide their desired filename\n";
	print "       fed -screen_prompt  # If using GNU screen, opens a small window and prompts\n";
	print "                             the user to provide their desired filename\n";

}

sub execute_init {
	my($file) = @_;
	my %cfg = &default_config();
	%cfg = &update_config_from_global(%cfg);
	%cfg = &load_config($file, %cfg);

	
	print("*********************************************************\n");
	&print_title();
	print("*********************************************************\n");
	print("   Initializing $file\n");
	print("*********************************************************\n");

	my $new_config = "";
	my $ignore = join(" ",@{$cfg{"ignore"}});
	$ignore = "none" if($ignore eq "");
	$ignore = &get("* Enter any file patterns you wish to EXCLUDE.
  That is, NEVER find files whose path matches one or more of these patterns.
  These are file patterns that work with 'grep'.
  Separate with spaces. ",$ignore);
	$new_config .= "ignore=$ignore\n";

	my $only = join(" ",@{$cfg{"only"}});
	$only = "none" if ($ignore eq "");
	$only = &get("* Enter any file patterns you wish to INCLUDE.
  That is, ONLY find files whose path matches one or more of these patterns.
  These are file patterns that work with 'grep'.
  Separate with spaces. ",$only);
	$new_config .= "only=$only\n";

	my $multiple_matches = $cfg{"multiple_matches"};
	$multiple_matches = &get_until_valid("* How to handle multiple matching filenames?",("ask","fail"));
	$new_config .= "multiple_matches=$multiple_matches\n";

	my $no_exist = $cfg{"no_exist"};
	$no_exist = &get_until_valid("* How to handle filenames that don't exist?",("ask","create","fail"));
	$new_config .= "no_exist=$no_exist\n";

	if($file =~ /fedconf$/) {
		my $editor = $cfg{"editor"};
		$editor = &get("* What would you like to use as your default editor?", $editor);
		$new_config .= "editor=$editor\n";
	
		my $alt_roots = join(" ",@{$cfg{"alt_roots"}});
		$alt_roots = &get("* Enter any other filenames you'd like to use whose existence represents the
  root of a project (e.g. .git or .hg).
  Separate each file with spaces.",$alt_roots);
		$new_config .= "alt_roots=$alt_roots\n";
	}

	open(F, ">$file");
	print F $new_config;
	close F;
	print("New fed config written to $file\n");
}
				

sub execute_file {
	my($file, %seed_cfg) = @_;

	my %cfg = &default_config(%seed_cfg);
	%cfg = &load_config($ENV{"HOME"}."/.fedconf",%cfg);

	&to_fed_root(%cfg);
	%cfg = &load_config(".fed",%cfg);

	&print_config(%cfg);

	my @files = &get_potential_files_substring($file, %cfg);
	if($#files == -1) {
		@files = &get_potential_files_fuzzy($file, %cfg);
	}
	@files = &filter_directories(@files);

	## We only want to show the file list if it's exactly 1, since the file
	#list we found will automatically be reproduced if it's more than one, and
	#if it's zero, there are no files to show
	print("Found File:\n\t".join("\n\t",@files)."\n\n") if($#files==0);

	&execute_files(\%cfg, $file, @files);
}

sub filter_directories {
	my @files = ();
	foreach(@_) {
		if(!-d $_) {
			push(@files, $_)
		}
	}
	return @files;
}
	

sub execute_files {
	my ($cfg, $file, @files) = @_;

	if($#files == -1) {
		&execute_none($cfg, $file);
	}elsif($#files == 0) {
		&maybe_execute_single($cfg, $files[0]);
	}elsif($#files > 0) {
		&execute_multiple($cfg, @files);
	}
}

sub execute_none {
	my ($cfg, $file) = @_;
	my $ne = $cfg->{"no_exist"};
	if($ne eq "fail") {
		&screen_close_region($cfg);
		die("No matching file. Failing per configuration (no_exist = fail)\n");
	}elsif($ne eq "create") {
		&maybe_execute_single($cfg, $file);
	}elsif($ne eq "ask") {
		my $response = &get_until_valid("No matching file found. How would you like to proceed? (c)reate or (q)uit",("c","q"));
		if($response eq "c") {
			&maybe_execute_single($cfg, $file);
		}elsif($response eq "f" or $response eq "q") {
			&screen_close_region($cfg);
			die("No matching file. Failing");
		}
	}
}


sub maybe_execute_single {
	my ($cfg, $file) = @_;

	if(defined($cfg->{"screen_id"})) {
		my $STY = $cfg->{"screen_id"};
		chomp($file);
		my $filename = &basename($file);

		my $window = &get_window_with_title($cfg, $filename);

		#print "Existing Windows:\n$windows\n";
		if($window > -1) {
			print("Found GNU Screen Window $window with this file open.\nSwitching to it...\n");

			#select()->flush();
			#for(my $i=3; $i>0; $i--) {
			#	print("$i...\n");
			#	select()->flush();
			#	sleep(1);
			#}
			#print("Go!\n");
			#
			#
			
			# Here, we switch back to our original main region and select the found window.
			# Then we just close the region that was created to prompt for the new file
			&screen_back_to_main($cfg);
			system("screen -r $STY -x -Q select $window");
			&screen_after_found($cfg);
		}else{

			# Here, since we actually have to open a new file, we're going to open that file in a new
			# window, then clean up the current script and exit, cleaning up afterward.
			#my $new_window_num = &get_window_num();
			&screen_back_to_main($cfg);
			&execute_single($cfg, $file);
			system("screen -r $STY -x -X title \"$filename\"");
			&screen_after_found($cfg);

		}
	}else{
		print "Not running under GNU Screen\n";
		&execute_single($cfg, $file);
	}
}

sub get_window_with_title {
	my ($cfg, $filename) = @_;
	if(defined($cfg->{"screen_id"})) {

		my $STY = $cfg->{"screen_id"};
		print "Running under GNU Screen ($STY)\n";

		print("Searching open GNU Screen windows for $filename\n");
		select()->flush();

		my @windows;
		for(my $i=0; $i<99; $i++) {
			my $switch_result = `screen -r $STY -x -Q select $i`;
			my $title = `screen -r $STY -x -Q title`;
			chomp($title);
			if($title eq $filename) {
				return $i;
			}
		}
	}
	return -1;
}

			


sub screen_close_region{
	my($cfg) = @_;
	if(defined($cfg->{"screen_prompt_mode"})) {
		my $STY = $cfg->{"screen_id"};
		print("closing region\n");
		system("screen -r $STY -x -X eval \"remove\"");
	}
}

sub screen_back_to_main {
	my($cfg) = @_;
	if(defined($cfg->{"screen_prompt_mode"})) {
		my $STY = $cfg->{"screen_id"};
		system("screen -r $STY -x -X eval \"focus up\"");
	}
}

sub screen_after_found {
	my($cfg) = @_;
	if(defined($cfg->{"screen_prompt_mode"})) {
		my $STY = $cfg->{"screen_id"};
		print("Moving focus down and trying to remove region");
		system("screen -r $STY -x -X eval \"focus down\" \"remove\"");
	}
}

sub get_window_num {
	my $STY = $ENV{"STY"};
	my $raw = `screen -r $STY -x -Q number`;
	$raw =~ /^(\d+)/;
	return $1;
}

sub basename {
	my($file) = @_;
	my @parts = split("/", $file);
	return $parts[$#parts];
}
	

sub execute_single {
	my ($cfg, $file) = @_;
	my $filename = &basename($file);
	my $editor = $cfg->{"editor"};
	my $ext = &extract_extension($file);
	my $cmd = "";
	if(defined($cfg->{"force_editor"})) {
		$cmd = $cfg->{"force_editor"}." \"$file\"";
	}elsif(defined($cfg->{"editor_$ext"})) {
		$cmd = $cfg->{"editor_$ext"}." \"$file\"";
	}elsif(defined($cfg->{"editor"})) {
		$cmd = $cfg->{"editor"}." \"$file\"";
	}else{
		die("No editor defined for file with extension $ext. Either define a univeral editor or add extension-specific editors");
	}
	
	if(defined($cfg->{"screen_prompt_mode"})) {
		my $STY = $cfg->{"screen_id"};
		system("screen -r $STY -x -X screen -t \"$filename\" $cmd");
	}else{
		system($cmd);
	}
}

sub execute_multiple {
	my($cfg, @files) = @_;
	my $mm = $cfg->{"multiple_matches"};
	if($mm eq "fail") {
		&screen_close_region($cfg);
		die("Multiple matching files. Failing per configuration (multiple_matches = fail)\n");
	}elsif($mm eq "loadall") {
		die("Load All not implemented");
	}elsif($mm eq "ask") {
		my $file = &ask_multiple($cfg, @files);
		&maybe_execute_single($cfg, $file);
	}
}

sub ask_multiple {
	my ($cfg, @files) = @_;

	my $size = $#files + 6;

	$size=40 if($size>40);
	&screen_resize_window($size, $cfg);

	print("Multiple Matching Files:\n");
	foreach my $i (keys(@files)) {
		print("\t(".($i+1)."): $files[$i]\n");
	}


	my $filenum = &get_until_valid_range("Which file to load [1-".($#files+1)." or (q)uit]?", 1, $#files+1);
	if($filenum eq "f" or $filenum eq "q") {
		&screen_close_region($cfg);
		die("Cancelling");
	}else{
		return $files[$filenum-1];
	}
}

## Currently disabled. Test for a while with just fuzzy searching, and see what happens
# sub get_potential_files {
# 	my ($file, %cfg) = @_;
# 	my $find = "find . -name \"$file*\"";
# 	my $filters = &ignore_commands(%cfg);
# 	my $files = `$find $filters`;
# 	return split("\n", $files);
# }

sub get_potential_files_substring {
	my ($file, %cfg) = @_;
	return &get_potential_files_wrapper($file, \&remap_parts_substring, "", %cfg);
}
	

sub get_potential_files_fuzzy {
	my ($file, %cfg)  = @_;
	return &get_potential_files_wrapper($file, \&remap_parts_fuzzy, "[^/]*?", %cfg);
}

sub get_potential_files_wrapper {
	my ($file, $remap_fun, $part_joiner, %cfg) = @_;
	my @parts = split(//, $file);
	@parts = &{$remap_fun}(@parts);
	my $regex = join($part_joiner,@parts);
	my $find = "find . ";
	my $filters = &ignore_and_only_commands(%cfg);
	my $cmd = "$find $filters";
	print("Running: $cmd\n");
	my $files = `$cmd`;
	my @files = split("\n",$files);

	#print "Regex: $regex\n";
	my @newfiles = ();
	foreach (@files) {
		if(m{$regex}si) {
			push(@newfiles, $_);
		}
	}
	return @newfiles;
}


sub remap_parts_fuzzy {
	return map {
		if($_ eq "."){
			"\\.";
		}elsif($_ eq '"') {
			"\\\"";
		}elsif($_ eq "/") {
			".*?/";
		}else{
			$_;
		}
	} @_;
}
		
sub remap_parts_substring {
	return map {
		if($_ eq "."){
			"[^/]*?\\.";
		}elsif($_ eq '"'){
			"\\\"";
		}elsif($_ eq "/"){
			".*?/.*?";
		}else{
			$_;
		}
	} @_;
}

sub ignore_and_only_commands {
	my (%cfg) = @_;
	my $filters;
	foreach my $ignore (@{$cfg{"ignore"}}) {
		$filters .= " | grep -v \"$ignore\" ";
	}
	
	my $only_filters = join("\\|",@{$cfg{"only"}});
	if($only_filters ne "") {
		$filters .= " | grep \"$only_filters\" ";
	}
	return $filters;
}

sub default_config{
	my (%seed_config) = @_;

	my %config = (
		"alt_roots",[],
		"ignore",["~\$"],
		"only",[],
		"no_exist","ask",
		"multiple_matches","ask"
	);
	if(defined($ENV{"FORCE_EDITOR"})) {
		$config{"force_editor"}=$ENV{"FORCE_EDITOR"};
	}
	# Are we running from within gnu screen?
	if(defined($ENV{"STY"})) {
		$config{"screen_id"}=$ENV{"STY"};
	}
	my %final_config = (%seed_config, %config);
	return %final_config;
}

sub update_config_from_global{
	my (%cfg) = @_;
	my $file = $ENV{"HOME"}."/.fedconf";
	return &load_config($file, %cfg);
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
			push(@{$config{"ignore"}}, @ignore);
		}elsif(/only\s*=\s*(.*)/){
			my @only=split(" ",$1);
			push(@{$config{"only"}}, @only);
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
	my $roots = $config{"alt_roots"};
	my @roots = @{$roots};
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
	my $default_prompt = ($default) ? " [Default: $default]: " : "";
	print "$prompt$default_prompt";
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
	} while(not(in_list($val,@list)));
	return $val;
}

sub in_list {
	my ($val, @list) = @_;
	for (@list) {
		return 1 if($val eq $_);
	}
	return 0;
}

sub get_until_valid_range {
	my ($prompt, $min, $max) = @_;
	my $val;
	do {
		print "$prompt: ";
		$val = <STDIN>;
		chomp($val);
	}until($val eq "f" or $val eq "q" or (&is_integer($val) and $val>=$min and $val<=$max));
	return $val;
}	

sub is_integer {
	my ($val) = @_;
	return (!ref($val) and $val == int($val)); ## tests whether is numerically equal to itself.
}
