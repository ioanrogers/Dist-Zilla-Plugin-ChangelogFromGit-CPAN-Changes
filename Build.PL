
use strict;
use warnings;

use Module::Build 0.3601;


my %module_build_args = (
  "build_requires" => {
    "Module::Build" => "0.3601"
  },
  "configure_requires" => {
    "Module::Build" => "0.3601"
  },
  "dist_abstract" => "Format Changelogs using CPAN::Changes",
  "dist_author" => [
    "Ioan Rogers <ioanr\@cpan.org>"
  ],
  "dist_name" => "Dist-Zilla-Plugin-ChangelogFromGit-CPAN-Changes",
  "dist_version" => "0.0.4",
  "license" => "perl",
  "module_name" => "Dist::Zilla::Plugin::ChangelogFromGit::CPAN::Changes",
  "recommends" => {},
  "recursive_test_files" => 1,
  "requires" => {
    "CPAN::Changes" => 0,
    "CPAN::Changes::Release" => 0,
    "Dist::Zilla::Plugin::ChangelogFromGit" => "0.004",
    "Moose" => 0
  },
  "script_files" => [],
  "test_requires" => {
    "IO::Handle" => 0,
    "IPC::Open3" => 0,
    "Test::More" => 0,
    "strict" => 0,
    "warnings" => 0
  }
);


unless ( eval { Module::Build->VERSION(0.4004) } ) {
  my $tr = delete $module_build_args{test_requires};
  my $br = $module_build_args{build_requires};
  for my $mod ( keys %$tr ) {
    if ( exists $br->{$mod} ) {
      $br->{$mod} = $tr->{$mod} if $tr->{$mod} > $br->{$mod};
    }
    else {
      $br->{$mod} = $tr->{$mod};
    }
  }
}

my $build = Module::Build->new(%module_build_args);

$build->create_build_script;
