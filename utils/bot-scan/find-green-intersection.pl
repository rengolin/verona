#!/usr/bin/env perl

# This script loads a JSON file with all bots and their latest build
# ranges, with commit list and build status, and finds the commits that
# form the intersection of all passing builds on all of them.
#
# If no commit found, return the commit (range) with the most number of
# passes across all buildbots.
#
# Module JSON needs to be installed, either from cpan or packages.

use strict;
use warnings;
use lib ".";
use helpers qw/wget read_file write_file encode decode debug/;

######################################################### Initialisation
# Option checking
my $syntax = "$0 bots-file.json [group1,group2,...]\n";
die $syntax unless (scalar @ARGV >= 1);

# Read config file
my ($config, $error) = &read_file($ARGV[0]);
die $error if ($error);
($config, $error) = &decode($config);
die $error if ($error);

# Select groups to look at, or add all groups if none selected
my %selected_groups;
if (scalar @ARGV > 1) {
  for my $group (split(/,/, $ARGV[1])) {
    $selected_groups{$group} = 1;
  }
} else {
  for my $group (@{$config}) {
    $selected_groups{$group->{'name'}} = 1;
  }
}

######################################################### Main Logic
# The main algorithm is linear in complexity (assuming hash complexity = O(1)).
# It scans each build of each buildbot only once, stores every bot and
# status for each commit on a hash indexed by commit. It basically inverts the
# view from bot > build(status) > commit to commit > status > bot.
my %commits;

for my $group (@{$config}) {
  next if (not $selected_groups{$group->{'name'}});
  print "Parsing buildbots in ".$group->{'name'}."...\n";
  for my $buildbot (keys %{$group->{'buildbots'}}) {
    print "  - $buildbot\n";
    for my $build (@{$group->{'buildbots'}->{$buildbot}->{'builds'}}) {
      # TODO: Differentiate test failures from instability
      my $status = $build->{'status'};
      &debug("    Build ".$build->{'build'}." status is $status\n");
      for my $commit (@{$build->{'commits'}}) {
        &debug("      Adding commit hash $commit\n");
        # Init arrays to avoid undefined issues on sort
        $commits{$commit}->{'PASS'} = [] unless $commits{$commit}->{'PASS'};
        $commits{$commit}->{'FAIL'} = [] unless $commits{$commit}->{'FAIL'};
        push @{$commits{$commit}->{$status}}, $buildbot;
      }
    }
  }
}
print "\n";

######################################################### Output Controll
# The second phase is to sort the hash by number of passing bots and print
# only the ones that pass *all* buildbots. If there are none, then print the
# one with the most number of bots and show the list of bots in which it passes
# and those in which it fails. This allows for an informed decision to be taken.
my $max_pass = 0;
for my $group (@{$config}) {
  $max_pass += scalar keys %{$group->{'buildbots'}};
}
my @sorted = sort { scalar @{$commits{$b}->{'PASS'}} cmp scalar @{$commits{$a}->{'PASS'}} } keys %commits;

# Those, if any, passed all bots
print "List of commits that passed all buildbots:\n";
my $num_passed_all = 0;
for my $commit (@sorted) {
  my $num_pass = scalar @{$commits{$commit}->{'PASS'}};
  &debug("  Processing commit hash $commit with $num_pass passes...\n");
  last if ($num_pass < $max_pass);
  $num_passed_all++;
  &print_commit($commit);
}
# If we have any commit that passes everything, no need to check the rest
exit if ($num_passed_all > 0);
print "\n";

# If not, show which ones passed the most, up to 10
print "List of commits that passed some buildbots:\n";
my $show = 10;
for my $commit (@sorted) {
  last if (not $show--);
  my $num_pass = scalar @{$commits{$commit}->{'PASS'}};
  &debug("  Processing commit hash $commit with $num_pass passes...\n");
  &print_commit($commit, $commits{$commit});
}

exit;

# PRINT COMMIT: Prints the commit and the buildbots it passed
# (commit,status) -> ()
sub print_commit() {
  my ($commit, $status) = @_;
  print "  - $commit\n";
  if (defined $status) {
    print "    Passed: ".(scalar @{$status->{'PASS'}})."\n";
    for my $buildbot (@{$status->{'PASS'}}) {
      print "      - $buildbot\n";
    }
    print "    Failed: ".(scalar @{$status->{'FAIL'}})."\n";
    for my $buildbot (@{$status->{'FAIL'}}) {
      print "      - $buildbot\n";
    }
    print "\n";
  }
}
