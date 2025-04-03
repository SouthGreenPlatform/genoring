=pod

=head1 NAME

GenoRing - Contains GenoRing Perl library.

=head1 SYNOPSIS

use Genoring;

=head1 REQUIRES

Perl5

=head1 EXPORTS

$g_debug $g_exec_prefix $g_flags $g_instance
ApplyContainerHooks ApplyLocalHooks Backup CleanupOperations ClearCache
Compile CompileMissingContainers Confirm CopyDirectory CopyModuleFiles
CopyVolumeFiles CreateVolumeDirectory DeleteAllContainers DirCopy
DisableAlternative DisableModule EnableAlternative EnableModule
EndOperations GenerateDockerComposeFile GetContainerName GetEnvVariable
GetLogs GetModuleAlternatives GetModuleConf GetModuleInfo GetModuleRealState
GetModuleServices GetModuleVolumes GetModules GetModulesConfig GetProfile
GetProjectName GetServices GetState GetStatus GetVolumeName GetVolumes GetOs
HandleShellExecutionError InstallModule IsContainerRunning ListAlternatives
ParseDependencies PerformContainerOperations PerformLocalOperations
PrepareOperations Reinitialize RemoveEnvFiles RemoveVolumeFiles
RemoveModuleConf Restore Run SetEnvVariable SetModuleConf SetupGenoring
SetupGenoringEnvironment StartGenoring StopGenoring ToDockerService
ToLocalService UninstallModule Update Upgrade WaitModulesReady
CheckGenoringUser InitGenoringUser CheckFreeSpace GetEnvironmentFiles

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
our @EXPORT =
  qw(
    $g_debug $g_exec_prefix $g_flags $g_instance
    ApplyContainerHooks ApplyLocalHooks Backup CleanupOperations ClearCache
    Compile CompileMissingContainers Confirm CopyDirectory CopyModuleFiles
    CopyVolumeFiles CreateVolumeDirectory DeleteAllContainers DirCopy
    DisableAlternative DisableModule EnableAlternative EnableModule
    EndOperations GenerateDockerComposeFile GetContainerName GetEnvVariable
    GetLogs GetModuleAlternatives GetModuleConf GetModuleInfo GetModuleRealState
    GetModuleServices GetModuleVolumes GetModules GetModulesConfig GetProfile
    GetProjectName GetServices GetState GetStatus GetVolumeName GetVolumes GetOs
    HandleShellExecutionError InstallModule IsContainerRunning ListAlternatives
    ParseDependencies PerformContainerOperations PerformLocalOperations
    PrepareOperations Reinitialize RemoveEnvFiles RemoveVolumeFiles
    RemoveModuleConf Restore Run SetEnvVariable SetModuleConf SetupGenoring
    SetupGenoringEnvironment StartGenoring StopGenoring ToDockerService
    ToLocalService UninstallModule Update Upgrade WaitModulesReady
    CheckGenoringUser InitGenoringUser CheckFreeSpace GetEnvironmentFiles
  );




# CODE END
###########


=pod

=head1 AUTHORS

Valentin GUIGNON (The Alliance Bioversity - CIAT), v.guignon@cgiar.org

=head1 VERSION

Version 1.0.0

Date 11/02/25

=head1 SEE ALSO

GenoRing documentation.

=cut

return 1; # package return
