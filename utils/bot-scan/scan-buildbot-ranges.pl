#!/usr/bin/env perl

# This script created JSON files from the buildbots on a specified
# build master by name and prints a list of commit ranges and the
# status of their builds.
#
# Multiple masters can be used, as well as multiple groups of bots
# and multiple bots per group, all in a json file.
#
# Module JSON needs to be installed, either from cpan or packages.

use strict;
use warnings;
use Scalar::Util qw/looks_like_number/;
use lib ".";
use helpers qw/wget read_file write_file encode decode debug/;

######################################################### Initialisation
# DEBUG
my $DEBUG = 0;

# Option checking
my $syntax = "$0 config-file.json output-file.json [NumBuilds=10]\n";
die $syntax unless (scalar @ARGV >= 2);

# Read config file
my ($config, $error) = &read_file($ARGV[0]);
die $error if ($error);
($config, $error) = &decode($config);
die $error if ($error);

# Number of builds to go back
my $number_of_builds = 10;
if (scalar @ARGV > 2 && looks_like_number($ARGV[2])) {
  $number_of_builds = $ARGV[2];
}

# Default options (json config overrides)
my $default_builder_url = "builders";
my $default_build_url = "build";

######################################################### Main Logic
# Get status for all bots
my %bot_cache;
my $fail = 0;

# Buildbots are organised by groups, so we can scan all and later choose which
# groups we want to process when finding the pass ranges.
my @groups;

# For each server declared in JSON config file, go through all of its buildbots
# and take the status of the last N builds, with commit ranges. 
foreach my $server (@$config) {
  print "Parsing server ".$server->{'name'}."...\n";

  # Ignore if asked or broken, this helps debugging and adding flaky servers
  next if (defined $server->{'ignore'} and $server->{'ignore'} eq "true");
  if (not defined $server->{'base_url'}) {
    &debug("Skipping server ".$server->{'name'}.", no base_url...\n");
    next;
  }

  # Set defaults, if unset
  $server->{'builder_url'} = $default_builder_url if (not defined $server->{'builder_url'});
  $server->{'build_url'} = $default_build_url if (not defined $server->{'build_url'});
  my ($BASE_URL, $BUILDER_URL, $BUILD_URL) =
     ($server->{'base_url'}, $server->{'builder_url'}, $server->{'build_url'});

  # For each builder group listed in the server...
  foreach my $builder (@{$server->{'builders'}}) {
    print "  Parsing builder group '".$builder->{'name'}."'...\n";
    my %group = (
      'server' => $server->{'name'},
      'base_url' => $server->{'base_url'},
      'name' => $builder->{'name'}
    );

    # For each buildbot in the group
    foreach my $bot (@{$builder->{'bots'}}) {
      print "    Parsing bot ".$bot->{'name'}."...\n";

      # If have done this before, ignore (for duplicated registrations)
      next if defined $bot_cache{$bot->{'name'}};
      next if defined $bot->{'ignore'} and $bot->{'ignore'} eq "true";

      # Get the commit range and status from the buildbot, and cache results
      my $range = &get_status($BASE_URL, $BUILDER_URL, $BUILD_URL, $bot->{'name'}, $number_of_builds);
      &debug("    ".$bot->{'name'}."processed...\n");
      $bot_cache{$bot->{'name'}} = $range;
      $group{'buildbots'}->{$bot->{'name'}} = $range;
    }
    push @groups, \%group;
  }
}

# Dump the data as a JSON file, so we can cache the data locally and run the
# set intersection algorithm many times with different parameters to find the
# best commit to pick.
my $text;
print "Converting retuls to JSON...\n";
($text, $error) = &encode(\@groups);
die $error if ($error);
print "Saving results to '$ARGV[1]'...\n";
($error) = &write_file($ARGV[1], $text);
print "Done!\n";
exit;

# GET STATUS: get the status of an individual bot
# (base url, builder url, build url, name, builds) -> (status)
sub get_status() {
  my ($BASE_URL, $BUILDER_URL, $BUILD_URL, $bot, $no_builds) = @_;
  my ($err, $contents, $json);
  my %range;

  $range{'name'} = $bot;

  # Get buildbot main JSON
  &debug("      Querying REST API...\n");
  ($contents, $err) = &wget("$BASE_URL/json/$BUILDER_URL/$bot");
  $range{'fail'} = $err;
  return \%range if $err;
  ($json, $err) = &decode($contents);
  $range{'fail'} = $err;
  return \%range if $err;
  &debug("      Main JSON parsed\n");

  # Find recent builds
  my $cached_builds = scalar @{$json->{'cachedBuilds'}};
  my $running_builds = scalar @{$json->{'currentBuilds'}};
  my $last_build = $json->{'cachedBuilds'}[$cached_builds - $running_builds - 1];
  my $first_build = $last_build - $no_builds + 1;
  return \%range if (not defined $last_build);
  &debug("      Found $last_build finished builds, taking last $no_builds\n");

  # For each finished build
  for my $build_no ($first_build..$last_build) {
    my %status;
    ($contents, $err) = &wget("$BASE_URL/json/$BUILDER_URL/$bot/$BUILD_URL/$build_no");
    $range{'fail'} = $err;
    return \%status if $err;
    ($json, $err) = &decode($contents);
    $range{'fail'} = $err;
    return \%status if $err;

    # Build number
    $status{'build'} = $json->{'number'};
    &debug("        Build number ".$status{'build'}."\n");

    # Status of the build
    # "text" : [ "build", "successful" ],
    # "text" : [ "failed", "svn-llvm" ],
    foreach (@{$json->{'text'}}) {
      s/["']+//g;
      $status{'status-msg'} .= "$_ ";
    }
    $status{'status-msg'} =~ s/ $//;
    if ($status{'status-msg'} =~ /(failed|exception)/) {
      $status{'status'} = "FAIL";
    } else {
      $status{'status'} = "PASS";
    }
    &debug("        Status ".$status{'status-msg'}." (".$status{'status'}.")\n");

    # Commit range. All LLVM repositories are in git now, so truncate the hashes
    # to 8 characters for display.
    my @commits = @{$json->{'sourceStamp'}->{'changes'}};
    for my $commit (@commits) {
      my $rev = substr($commit->{'revision'}, 0, 8);
      &debug("          Commit $rev\n");
      push @{$status{'commits'}}, $rev;
      $status{'top-commit'} = $rev;
    }
    if (defined $status{'commits'}) {
      my $num_commits = scalar @{$status{'commits'}};
      &debug("        Top commit ".$status{'top-commit'}." ($num_commits)\n");
    }

    # Elapsed time of the last build.
    $status{'time'} = $json->{'times'}[1] - $json->{'times'}[0];
    &debug("        Elapsed time ".$status{'time'}."\n");

    # Append status to range
    push @{$range{'builds'}}, \%status;
  }

  return \%range;
}
