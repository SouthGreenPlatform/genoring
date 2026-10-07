#!/usr/bin/env perl

=pod

=head1 NAME

overrides.t - Tests GenoRing service override planning and image chaining.

=cut

use strict;
use warnings;

use File::Path qw(make_path);
use File::Spec;
use File::Temp qw(tempdir);
use FindBin;
use lib "$FindBin::Bin/../../perllib";
use Genoring;
use Test::More tests => 16;

my $modules_dir = tempdir(CLEANUP => 1);
local $Genoring::MODULES_DIR = $modules_dir;

sub write_file {
  my ($path, $content) = @_;
  my (undef, $directory) = File::Spec->splitpath($path);
  make_path($directory) if $directory && !-d $directory;
  open(my $file, '>', $path) or die "Cannot create '$path': $!";
  print {$file} $content or die "Cannot write '$path': $!";
  close($file) or die "Cannot close '$path': $!";
}

write_file(
  File::Spec->catfile($modules_dir, 'base', 'services', 'genoring-app.yml'),
  "image: app-image\n"
);
write_file(
  File::Spec->catfile($modules_dir, 'base', 'src', 'genoring-app', 'Dockerfile'),
  "FROM scratch\n"
);
foreach my $module ('override_one', 'override_two', 'inactive_override') {
  write_file(
    File::Spec->catfile(
      $modules_dir, $module, 'services', 'overrides',
      'genoring-genoring-app.dockerfile'
    ),
    "FROM app-image\n"
  );
}

my %module_info = (
  base => {'version' => '1.0'},
  override_one => {
    'version' => '1.1',
    'overrides' => {
      'genoring-genoring-app' => {'alternatives' => ['override_one']},
    },
  },
  override_two => {
    'version' => '2.0',
    'overrides' => {
      'genoring-genoring-app' => {'alternatives' => ['selected_alt']},
    },
  },
  inactive_override => {
    'version' => '1.0',
    'overrides' => {
      'genoring-genoring-app' => {'alternatives' => ['another_alt']},
    },
  },
);
my %module_config = (
  override_one => {},
  override_two => {'alternative' => 'selected_alt'},
  inactive_override => {},
);

{
  local *Genoring::GetModules = sub { return [qw(base override_one override_two inactive_override)]; };
  local *Genoring::GetModuleInfo = sub { return $module_info{$_[0]}; };
  local *Genoring::GetModuleConf = sub { return $module_config{$_[0]} || {}; };
  my $plans = Genoring::_GetServiceOverridePlans({'genoring-app' => 'base'});
  is_deeply(
    [map { $_->{'module'} } @{$plans->{'genoring-app'}->{'overrides'}}],
    [qw(override_one override_two)],
    'Only overrides for the active default/selected alternatives are included'
  );
  ok($plans->{'genoring-app'}->{'has_source'}, 'Source-based service is detected');
}

{
  write_file(
    File::Spec->catfile($modules_dir, 'base', 'services', 'genoring-dynamic.yml'),
    "image: \${DYNAMIC_IMAGE}\n"
  );
  local *Genoring::GetModules = sub { return ['base']; };
  local *Genoring::GetModuleInfo = sub { return $module_info{$_[0]}; };
  my $plans = Genoring::_GetServiceOverridePlans({'genoring-dynamic' => 'base'});
  is_deeply($plans, {}, 'Services without active override declarations are not inspected or rebuilt');
}

{
  my @builds;
  my $config = {'service_overrides' => {}};
  my $plan = {
    'owner' => 'base',
    'base_image' => 'genoring',
    'has_source' => 1,
    'signature' => 'source-signature',
    'overrides' => [
      {'module' => 'override_one', 'dockerfile' => 'one.dockerfile'},
      {'module' => 'override_two', 'dockerfile' => 'two.dockerfile'},
    ],
  };
  local *Genoring::ClearInternalCache = sub {};
  local *Genoring::GetServices = sub { return {'genoring-app' => 'base'}; };
  local *Genoring::GetConfig = sub { return $config; };
  local *Genoring::GetProjectName = sub { return 'test-project'; };
  local *Genoring::SaveConfig = sub {};
  local *Genoring::Run = sub {
    return $_[0] =~ / images -q / ? 'image-id' : '';
  };
  local *Genoring::_GetServiceOverridePlans = sub { return {'genoring-app' => $plan}; };
  local *Genoring::Build = sub { push(@builds, ['base', @_]); };
  local *Genoring::_BuildServiceOverride = sub { push(@builds, ['override', @_]); };

  Genoring::ApplyServiceOverrides();
  is(scalar(@builds), 3, 'Builds a source image and both override layers');
  is($builds[0]->[3], 'genoring-override-test-project-genoring-app-stage-0:latest', 'Builds source image to an intermediate tag');
  is($builds[1]->[5], 'genoring-override-test-project-genoring-app-stage-1:latest', 'Tags the first override as an intermediate layer');
  is($builds[2]->[5], 'genoring', 'Tags the final source-based override with the original image name');
  is_deeply(
    $config->{'service_overrides'}->{'genoring-app'}->{'modules'},
    [qw(override_one override_two)],
    'Persists the ordered override module list'
  );
  Genoring::ApplyServiceOverrides();
  is(scalar(@builds), 3, 'Does not rebuild an unchanged override chain');
}

{
  my @commands;
  my $built_dockerfile = '';
  my $dockerfile = File::Spec->catfile(
    $modules_dir, 'override_one', 'services', 'overrides',
    'genoring-genoring-app.dockerfile'
  );
  local *Genoring::_EnsureDockerBuildx = sub {};
  local *Genoring::Run = sub {
    my ($command) = @_;
    push(@commands, $command);
    if ($command =~ / -f '([^']+)' -t/) {
      open(my $file, '<', $1) or die "Cannot read generated Dockerfile '$1': $!";
      $built_dockerfile = do { local $/; <$file> };
      close($file);
    }
    return '';
  };
  Genoring::_BuildServiceOverride(
    $dockerfile, 'override_one', 'app-image',
    'genoring-intermediate:latest', 'genoring-final:latest'
  );
  like($built_dockerfile, qr/^FROM genoring-intermediate:latest$/m, 'Rewrites FROM to the preceding image');
  like($commands[1], qr/-t 'genoring-final:latest'/, 'Builds the override under its requested image name');
}

{
  my @built_overrides;
  my @base_builds;
  my $config = {'service_overrides' => {}};
  my $plan = {
    'owner' => 'mongodb',
    'base_image' => 'mongo:4.2.24',
    'has_source' => 0,
    'signature' => 'public-signature',
    'overrides' => [
      {'module' => 'override_public', 'dockerfile' => 'public.dockerfile'},
    ],
  };
  local *Genoring::ClearInternalCache = sub {};
  local *Genoring::GetServices = sub { return {'genoring-mongodb42' => 'mongodb'}; };
  local *Genoring::GetConfig = sub { return $config; };
  local *Genoring::GetProjectName = sub { return 'other_instance'; };
  local *Genoring::SaveConfig = sub {};
  local *Genoring::Run = sub {
    return $_[0] =~ / images -q / ? 'public-image-id' : '';
  };
  local *Genoring::_GetServiceOverridePlans = sub { return {'genoring-mongodb42' => $plan}; };
  local *Genoring::Build = sub { push(@base_builds, [@_]); };
  local *Genoring::_BuildServiceOverride = sub { push(@built_overrides, [@_]); };

  Genoring::ApplyServiceOverrides();
  is(scalar(@base_builds), 0, 'Does not rebuild a public base image');
  is(
    $built_overrides[0]->[4],
    'genoring-override-other_instance-genoring-mongodb42:latest',
    'Creates an instance-specific image for an override of a public image'
  );
  is(
    $config->{'service_overrides'}->{'genoring-mongodb42'}->{'image'},
    'genoring-override-other_instance-genoring-mongodb42:latest',
    'Persists the public override image for Compose generation'
  );
}

{
  my @base_builds;
  my $config = {
    'service_overrides' => {
      'genoring-app' => {
        'image' => 'genoring',
        'base_image' => 'genoring',
        'owner' => 'base',
        'source' => 1,
        'modules' => ['override_one'],
      },
    },
  };
  local *Genoring::ClearInternalCache = sub {};
  local *Genoring::GetServices = sub { return {}; };
  local *Genoring::GetConfig = sub { return $config; };
  local *Genoring::SaveConfig = sub {};
  local *Genoring::_GetServiceOverridePlans = sub { return {}; };
  local *Genoring::Build = sub { push(@base_builds, [@_]); };

  Genoring::ApplyServiceOverrides();
  is_deeply(
    $base_builds[0],
    ['base', 'genoring-app', 'genoring'],
    'Restores the original source image when its override is removed'
  );
  ok(
    !exists($config->{'service_overrides'}),
    'Removes stale override tracking from the instance config'
  );
}
