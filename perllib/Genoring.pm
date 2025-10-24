=pod

=head1 NAME

GenoRing - Contains GenoRing Perl library.

=head1 SYNOPSIS

use Genoring;

=head1 REQUIRES

Perl5

=head1 EXPORTS

$g_debug $g_exec_prefix $g_flags $g_project
ApplyContainerHooks ApplyLocalHooks Backup CanUseExposedVolumes
CheckFreeSpace CheckGenoringUser CleanupOperations ClearCache
CompareVersions Compile CompileMissingContainers Confirm
CopyDirectory CopyFiles CopyModuleFiles CopyVolumeFiles
CreateVolumeDirectory DeleteAllContainers DirCopy DisableAlternative
DisableModule EnableAlternative EnableModule EndOperations ExportVolume
GenerateDockerComposeFile GetConfig GetContainerName GetDiagosticLogs
GetEnvironmentFiles GetEnvVariable GetLogs GetModuleAlternatives
GetModuleConf GetModuleInfo GetModuleRealState GetModules GetModulesConfig
GetModuleServices GetModuleVolumes GetOs GetProfile GetProjectName
GetServices GetState GetStatus GetVolumeName GetVolumes ImportIntoVolume
HandleShellExecutionError InitGenoringUser InstallModule IsContainerRunning
ListAlternatives ParseDependencies ParseVersion PerformContainerOperations
PerformLocalOperations PrepareOperations Reinitialize RemoveDependencyFiles
RemoveEnvFiles RemoveModuleConf RemoveVolumeDirectories RemoveVolumeFiles
Restore Run RunShell SaveConfig SetEnvVariable SetModuleConf SetupGenoring
SetupGenoringEnvironment StartGenoring StopGenoring ToDockerService
ToLocalService UninstallModule Update Upgrade WaitModulesReady

=head1 DESCRIPTION

This module contains GenoRing library.

=cut

package Genoring;

require 5.8.0;
use strict;
use warnings;
use utf8;
use Genoring::GenoringConst;
use Genoring::GenoringEnv;
use Genoring::GenoringFunc;

use base qw(Exporter);
our @EXPORT = qw(
  $g_debug $g_exec_prefix $g_flags $g_project
  ApplyContainerHooks ApplyLocalHooks Backup CanUseExposedVolumes
  CheckFreeSpace CheckGenoringUser CleanupOperations ClearCache
  CompareVersions Compile CompileMissingContainers Confirm
  CopyDirectory CopyFiles CopyModuleFiles CopyVolumeFiles
  CreateVolumeDirectory DeleteAllContainers DirCopy DisableAlternative
  DisableModule EnableAlternative EnableModule EndOperations ExportVolume
  GenerateDockerComposeFile GetConfig GetContainerName GetDiagosticLogs
  GetEnvironmentFiles GetEnvVariable GetLogs GetModuleAlternatives
  GetModuleConf GetModuleInfo GetModuleRealState GetModules GetModulesConfig
  GetModuleServices GetModuleVolumes GetOs GetProfile GetProjectName
  GetServices GetState GetStatus GetVolumeName GetVolumes ImportIntoVolume
  HandleShellExecutionError InitGenoringUser InstallModule IsContainerRunning
  ListAlternatives ParseDependencies ParseVersion PerformContainerOperations
  PerformLocalOperations PrepareOperations Reinitialize RemoveDependencyFiles
  RemoveEnvFiles RemoveModuleConf RemoveVolumeDirectories RemoveVolumeFiles
  Restore Run RunShell SaveConfig SetEnvVariable SetModuleConf SetupGenoring
  SetupGenoringEnvironment StartGenoring StopGenoring ToDockerService
  ToLocalService UninstallModule Update Upgrade WaitModulesReady
  IsGitAvailable GetAvailableVersions
);
# Init $NULL.
$Genoring::NULL = ('Win32' eq GetOs()) ? 'nul' : '/dev/null';



# CODE END
###########


=pod

=head1 AUTHORS

Valentin GUIGNON (The Alliance Bioversity - CIAT), v.guignon@cgiar.org

=head1 VERSION

Version 1.0

Date 13/10/2025

=head1 SEE ALSO

GenoRing documentation.

=cut

return 1; # package return
