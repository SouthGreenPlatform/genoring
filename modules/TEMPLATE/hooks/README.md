# GenoRing module hooks

## Description

This directory contains hook scripts called by GenoRing when a given event
occurs. Some scripts are local, some others are for containers. The given
scripts are provided as example and can be altered. Remove all hook scripts that
are not used by your module.

All scripts should be fault-tolerant and output meaningfull messages for logs.

Local hooks are the one ending by ".pl" and run on the local server running
Genoring.

Container hooks are the one ending by "SERVICE.sh" and run inside containers.
Their file names should be adapted to the GenoRing services they are targeting.

For a detailed list of supported hooks, see genoring.pl script documentation for
functions ApplyLocalHooks and ApplyContainerHooks.

## Local hooks
Local hooks are perl scripts with the following recommandations:
- do not use non-PERL core modules (https://perldoc.perl.org/modules).
  This is required to avoid extra-requirements. Otherwise, you should document
  that your module has extra-dependencies and handle the case when those
  dependencies are not met.
- avoid the use of shell commands (ie. system(), qx(), and such) unless you are
  sure the command used are available on all OS (including Windows and Mac
  platforms).
- if using shell commands, use double quotes instead of simple quotes for
  argument quoting as single quotes are not supported by Windows system.
- when using file path, make sure function used support automatic path
  conversion, otherwise, use File::Spec->catfile() for compatibility with
  Windows.
- You can use environment variables provided by GenoRing:
  - $ENV{'GENORING_DIR'}: Path to current GenoRing installation.
  - $ENV{'GENORING_VOLUMES_DIR'}: path to current shared docker "volumes"
    directory.
  Note: both of them have no trailing slash and may contain absolute or relative
  path.
- $ENV{'PWD'} is provided by "genoring.pl" on Windows systems and is "native" on
  Linux systems.


## Container hooks

The "SERVICE" part of the name of a container hook should be replaced by the
name of a service (ie. Docker container name). The given container hook will be
executed in that container, using the container specificities (ie. if it is a
Linux image with bash, the script could start with "#!/bin/bash", but if it's an
Alpine image, using "#!/bin/ash" would be more appropriate, and in both cases,
using "#!/bin/sh" would work and ensure future compatibility in case of image
changes).

Container hook scripts are always made executable in the container to avoid
issues with local script that do not have the appropriate execution permission
on the local file system (performed using "chmod +x").

To allow the use of external materials (ie. files) in the target service, the
GenoRing "modules" directory is automatically mounted in the container as
"/genoring/modules". Therefore, the hook can call additional scripts or use
resource files for its operations.


## Some recipes

Here are some code recipes that may help in common tasks.

### Working with file path on local hooks.
```
  use File::Spec;
  use lib "$ENV{'GENORING_DIR'}/perllib";
  use Genoring;
  # To access GenoRing module sub-directory:
  my $modules_path = File::Spec->catfile($Genoring::MODULES_DIR, 'module_name', 'res');

  # To access GenoRing volumes directory:
  my $volumes_path = $Genoring::VOLUMES_DIR;
  
  # Warning:
  # Note: use ' .' instead of '.' because otherwise we would get
  # "modules\res" instead of " .\modules\res" on Windows systems. Therefore, the
  # leading space may need to be removed depending how/where the path is used.
  my $env_path = File::Spec->catfile(' .', 'env');
  # or use:
  my $env_path = File::Spec->catfile($ENV{'PWD'} || Cwd::cwd(), 'env');
```

### Running a perl script from a local hook.
```
  require $Genoring::GENORING_DIR . '/modules/somemodule/res/somescript.pl';
```

### Executing a command line from a local hook.
Remember that the script should remain cross-platform, including Windows
platform. Therefore, few applications are guaranteed to be available: docker and
perl.
```
  my $output = qx(
    docker ps
  );
  # Error management.
  if ($?) {
    my $error_message = 'ERROR';
    if ($? == -1) {
      $error_message = "ERROR $?\n$!";
    }
    elsif ($? & 127) {
      $error_message = sprintf(
        "ERROR: Child died with signal %d, %s coredump\n",
        ($? & 127), ($? & 128) ? 'with' : 'without'
      );
    }
    else {
      $error_message = sprintf("ERROR %d", $? >> 8);
    }
    warn($error_message);
  }

  print "$output\n";
```

### Processing a file to replace environment variables from a local hook.
```
  my $res_path = File::Spec->catfile(' .', 'modules', 'somemodule', 'res');
  my $volumes_path = File::Spec->catfile($ENV{'GENORING_VOLUMES_DIR'}, 'targetdir');
  # Process file to replace environment variables.
  # Note: do not forget env files in "./env" directory are prefixed by their
  # module name to avoid conflicts.
  my $output = qx(
    docker run --rm --env-file env/somemodule_envfile.env --env-file env/othermodule_other.env --env-file env/genoring_genoring.env -v $res_path:/sourcedir -v $volumes_path:/targetdir -w / alpine sh -c "apk add envsubst && envsubst < /sourcedir/somefile.conf > /target/processedfile.conf"
  );
```

### Copying files from local hooks.
```
  # For a single file:
  use File::Copy;
  # Note: copy() can translate path for Windows systems.
  my $source_file = './some/source/file.ext';
  my $target_file = './some/target/file.ext';
  if (!-e $target_file) {
    copy($source_file, $target_file);
  }

  # For a directory:
  # Recursive function to copy directories.
  sub dircopy {
    my ($source, $target) = @_;
    if (opendir(my $dh, $source)) {
      if (!-d $target) {
        if (!mkdir $target) {
          die "ERROR: Failed to create target directory '$target'!\n$!\n";
        }
      }
      foreach my $item (readdir($dh)) {
        # Skip "." and "..".
        if ($item =~ m/^\.\.?$/) {
          next;
        }
        if (-d "$source/$item") {
          # Sub-directory.
          if (!-e "$target/$item") {
            if (!mkdir "$target/$item") {
              warn "WARNING: Failed to create directory '$target/$item'!\n$!\n";
            }
          }
          dircopy("$source/$item", "$target/$item");
        }
        else {
          # File.
          if (!copy("$source/$item", "$target/$item")) {
            warn "WARNING: Failed to copy '$source/$item'.\n$!\n";
          }
        }
      }
      closedir($dh);
    }
    else {
      warn "WARNING: Failed to access '$source' directory!\n$!";
    }
  }
  # ...
  dircopy($source_path, $target_path);
```

### Create subdirectory structure.
```
  use File::Path qw(make_path);
  # ...
  my $path = $ENV{'GENORING_VOLUMES_DIR'} . '/some/path'
  if (!-d $path) {
    make_path($path);
  }
```

### Removing a subdirectory structure from a local hook.
Since files in "volumes" may be created by containers with the "root" user, they
may not be removed by current local user running the "genoring.pl" script. To
avoid permission issues, it is better to make those files and directories
removed by Docker the following way:
```
  # Ex.: remove "$GENORING_VOLUMES_DIR/some/subdirectory".
  my $volumes_path = $ENV{'GENORING_VOLUMES_DIR'};
  my $output = qx(
    docker run --rm -v $volumes_path:/genoring -w / alpine rm -rf /genoring/some/subdirectory
  );
```

### Shell script execution in container hooks.
Keep in mind that you design a script for a specific container. Depending on
that given container, you will have to choose which shell script to use (ie.
it can be "/bin/sh" or "/bin/bash" for Debian-based image and "/bin/ash" for
Alpine-based containers).
