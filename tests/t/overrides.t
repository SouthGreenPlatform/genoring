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
use Test::More tests => 39;

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
make_path(File::Spec->catdir($modules_dir, 'publicbase'));
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

# Simulated local Docker image store used by override chain tests.
my (%images, %image_labels, $image_counter);
sub reset_images {
  %images = @_;
  %image_labels = ();
  $image_counter = 0;
}
sub mock_build_override {
  my ($log, $dockerfile, $module, $base, $previous, $output, $labels) = @_;
  push(@$log, ['override', $dockerfile, $module, $base, $previous, $output, $labels]);
  $images{$output} = 'built-' . ++$image_counter;
  $image_labels{$output} = {%{$labels || {}}};
}

{
  my @builds;
  my @compose_updates;
  my $config = {'service_overrides' => {}};
  my $project = 'test-project';
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
  reset_images('genoring' => 'base-id-1');
  local *Genoring::ClearInternalCache = sub {};
  local *Genoring::GetServices = sub { return {'genoring-app' => 'base'}; };
  local *Genoring::GetConfig = sub { return $config; };
  local *Genoring::GetProjectName = sub { return $project; };
  local *Genoring::SaveConfig = sub {};
  local *Genoring::GenerateDockerComposeFile = sub { push(@compose_updates, 1); };
  local *Genoring::Run = sub {
    delete($images{$1}) if $_[0] =~ / image rm -f '([^']+)'/;
    return '';
  };
  local *Genoring::_GetDockerImageId = sub { return $images{$_[0]} || ''; };
  local *Genoring::_GetDockerImageLabels = sub { return $image_labels{$_[0]} || {}; };
  local *Genoring::_GetServiceOverridePlans = sub { return {'genoring-app' => $plan}; };
  local *Genoring::Build = sub {
    push(@builds, ['base', @_]);
    $images{$_[2]} = 'base-id-rebuilt';
  };
  local *Genoring::_BuildServiceOverride = sub { mock_build_override(\@builds, @_); };

  Genoring::ApplyServiceOverrides();
  my $final_image = $builds[-1]->[5];
  is(scalar(@builds), 2, 'Builds both override layers on top of the existing source image');
  is($builds[0]->[4], 'genoring', 'Chains the first override on the original source image');
  is($builds[0]->[5], 'genoring-override-test-project-genoring-app-stage-1:latest', 'Builds the first override as an intermediate layer');
  like($final_image, qr/^genoring-override-genoring-app:[0-9a-f]{12}$/, 'Names the final image after the service and an override key');
  ok(!grep({ $_->[5] eq 'genoring' } @builds), 'Never overwrites the original source image');
  ok(!exists($images{'genoring-override-test-project-genoring-app-stage-1:latest'}), 'Removes intermediate images');
  is($image_labels{$final_image}->{'org.genoring.override.base-image-id'}, 'base-id-1', 'Labels the final image with its base image identifier');
  is($config->{'service_overrides'}->{'genoring-app'}->{'image'}, $final_image, 'Persists the effective override image');
  is_deeply(
    $config->{'service_overrides'}->{'genoring-app'}->{'modules'},
    [qw(override_one override_two)],
    'Persists the ordered override module list'
  );
  Genoring::ApplyServiceOverrides();
  is(scalar(@builds), 2, 'Does not rebuild an unchanged override chain');
  is(scalar(@compose_updates), 1, 'Regenerates Compose after changing an override image');

  # Another instance with the same override set shares the image.
  $config = {};
  $project = 'another-project';
  Genoring::ApplyServiceOverrides();
  is(scalar(@builds), 2, 'Reuses an up-to-date override image built by another instance');
  is($config->{'service_overrides'}->{'genoring-app'}->{'image'}, $final_image, 'Another instance with the same overrides uses the same image');

  # A base image change invalidates the override image.
  $images{'genoring'} = 'base-id-2';
  Genoring::ApplyServiceOverrides();
  is(scalar(@builds), 4, 'Rebuilds the override chain when the base image changed');
  is($builds[-1]->[5], $final_image, 'Rebuilds the shared override image in place');

  # A freshly compiled base image always triggers a rebuild.
  Genoring::ApplyServiceOverrides('genoring-app', 1);
  is(scalar(@builds), 6, 'Rebuilds the override chain after a base image compilation');

  # A different override set uses a different image.
  my $first_override = pop(@{$plan->{'overrides'}});
  Genoring::ApplyServiceOverrides();
  isnt($builds[-1]->[5], $final_image, 'A different override set uses a different image');
  ok(exists($images{$final_image}), 'Keeps the image of the other override set');
  push(@{$plan->{'overrides'}}, $first_override);

  # Missing base image is compiled under its original name first.
  delete($images{'genoring'});
  delete($images{$final_image});
  Genoring::ApplyServiceOverrides();
  is_deeply([@{$builds[-3]}[0 .. 3]], ['base', 'base', 'genoring-app', 'genoring'], 'Compiles a missing source image under its original name');
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
  @commands = ();
  Genoring::_BuildServiceOverride(
    $dockerfile, 'override_one', 'app-image',
    'genoring-intermediate:latest', 'genoring-final:latest',
    {'org.genoring.override.signature' => 'abc'}
  );
  like($commands[-1], qr/--label 'org.genoring.override.signature=abc'/, 'Sets requested labels on the override image');
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
  local *Genoring::GenerateDockerComposeFile = sub {};
  reset_images('mongo:4.2.24' => 'public-image-id');
  local *Genoring::Run = sub { return ''; };
  local *Genoring::_GetDockerImageId = sub { return $images{$_[0]} || ''; };
  local *Genoring::_GetDockerImageLabels = sub { return $image_labels{$_[0]} || {}; };
  local *Genoring::_GetServiceOverridePlans = sub { return {'genoring-mongodb42' => $plan}; };
  local *Genoring::Build = sub { push(@base_builds, [@_]); };
  local *Genoring::_BuildServiceOverride = sub { mock_build_override(\@built_overrides, @_); };

  Genoring::ApplyServiceOverrides();
  is(scalar(@base_builds), 0, 'Does not rebuild a public base image');
  like(
    $built_overrides[0]->[5],
    qr/^genoring-override-genoring-mongodb42:[0-9a-f]{12}$/,
    'Creates an instance-independent image for an override of a public image'
  );
  is($built_overrides[0]->[4], 'mongo:4.2.24', 'Chains the override on the public image');
  is(
    $config->{'service_overrides'}->{'genoring-mongodb42'}->{'image'},
    $built_overrides[0]->[5],
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
  local *Genoring::GenerateDockerComposeFile = sub {};
  local *Genoring::_GetServiceOverridePlans = sub { return {}; };
  local *Genoring::Build = sub { push(@base_builds, [@_]); };

  Genoring::ApplyServiceOverrides('genoring-app', 1);
  is(scalar(@base_builds), 0, 'Does not rebuild a source image during override bookkeeping');
  ok(
    !exists($config->{'service_overrides'}),
    'Removes stale override tracking after a service rebuild'
  );
}

{
  my @calls;
  local $Genoring::DOCKER_COMMAND = 'docker';
  local $Genoring::DOCKER_BUILD_COMMAND = 'docker build';
  local $Genoring::DEFAULT_ARCHITECTURE = 'linux/amd64';
  local *Genoring::_EnsureDockerBuildx = sub {};
  local *Genoring::IsContainerRunning = sub { return (); };
  local *Genoring::GetServices = sub { return {'genoring-app' => 'base'}; };
  local *Genoring::Run = sub {
    push(@calls, ['run', $_[0]]);
    return '';
  };
  local *Genoring::ApplyServiceOverrides = sub {
    push(@calls, ['overrides', @_]);
  };
  Genoring::Build('base', 'genoring-app');
  is(
    $calls[-1]->[0],
    'overrides',
    'A direct source service build applies overrides after the base build'
  );
  is_deeply(
    $calls[-1],
    ['overrides', 'genoring-app', 1],
    'The compiled base image is passed to override processing'
  );
  ok(
    (grep { $_->[0] eq 'run' && $_->[1] =~ / build / } @calls),
    'A direct build still compiles the base image'
  );
}

{
  my @override_calls;
  local $Genoring::DOCKER_COMMAND = 'docker';
  local *Genoring::GetServices = sub { return {'genoring-public' => 'publicbase'}; };
  local *Genoring::GetConfig = sub { return {}; };
  local *Genoring::_GetServiceOverridePlans = sub {
    return {
      'genoring-public' => {
        'overrides' => [{'module' => 'override_public'}],
      },
    };
  };
  local *Genoring::ApplyServiceOverrides = sub {
    push(@override_calls, [@_]);
  };
  Genoring::Build('publicbase', 'genoring-public');
  is_deeply(
    $override_calls[0],
    ['genoring-public', 0],
    'A public-image service build applies overrides without rebuilding the base'
  );
  is(scalar(@override_calls), 1, 'Public image override build exits without a source build');
}

ok(Genoring::_IsServiceImage('genoring', 'genoring'), 'Original image is a service image');
ok(Genoring::_IsServiceImage('genoring', 'genoring-override-genoring:0123456789ab'), 'Override image is a service image');
ok(!Genoring::_IsServiceImage('genoring', 'genoring-override-genoring-db:0123456789ab'), 'Other service override image is not a service image');
