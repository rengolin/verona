#!/usr/bin/env perl

# This script created JSON files from the buildbots on a specified
# build master by name and prints a list of commit ranges and the
# status of their builds.
#
# Multiple masters can be used, as well as multiple groups of bots
# and multiple bots per group, all in a json file.
#
# Module JSON needs to be installed, either from cpan or packages.

package helpers;
use strict;
use warnings;

use JSON;
use LWP;
use LWP::UserAgent;

use Exporter qw/import/;

our @EXPORT_OK = qw/wget read_file write_file encode decode debug/;

# DEBUG
my $DEBUG = 0;

# WGET: uses LWP to get an URL, returns contents (or error).
# (url) -> (contents, error)
sub wget() {
  my ($url) = @_;
  my ($contents, $error) = ("", "");

  my $ua = LWP::UserAgent->new;
  $ua->agent("LLVM BotMonitor/0.1");
  my $req = HTTP::Request->new(GET => $url);
  my $res = $ua->request($req);

  if ($res->is_success) {
    $contents = $res->content;
  } else {
    $error = $res->status_line;
  }
  return ($contents, $error);
}

# READ FILE: Reads a local file, returns contents
# (filename) -> (contents, error)
sub read_file() {
  my ($file) = @_;
  my ($contents, $error) = ("", "");
  if (open FH, $file) {
    while (<FH>) { $contents .= $_; }
    close FH;
  } else {
    $error = "Can't open config file $file: $!";
  }
  return ($contents, $error);
}

# WRITE FILE: Write contents to a local file
# (filename, contents) -> (error)
sub write_file() {
  my ($file, $contents) = @_;
  my ($error) = ("");
  if (open FH, ">$file") {
    print FH $contents;
    close FH;
  } else {
    $error = "Can't open config file $file: $!";
  }
  return ($error);
}

# DECODE: Decode text into JSON
# (text) -> (JSON, error)
sub decode() {
  my ($text) = @_;
  my ($json, $error) = ("", "");
  eval { $json = decode_json($text); };
  if ($@) {
    if ($DEBUG) {
      $error = $@;
    } else {
      $error = "JSON error";
    }
  }
  return ($json, $error);
}

# ENCODE: Encodes hash as JSON
# (JSON) -> (text, error)
sub encode() {
  my ($json) = @_;
  my ($text, $error) = ("", "");
  eval { $text = encode_json($json); };
  if ($@) {
    if ($DEBUG) {
      $error = $@;
    } else {
      $error = "JSON error";
    }
  }
  return ($text, $error);
}

# DEBUG: Prints debug messages if debug enabled
# (msg) -> ()
sub debug () {
  my ($msg) = @_;
  print STDERR $msg if ($DEBUG);
}

1;
