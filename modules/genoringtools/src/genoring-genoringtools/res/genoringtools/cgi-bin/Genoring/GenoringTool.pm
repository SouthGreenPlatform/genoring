=pod

=head1 NAME

Genoring::GenoringTool - Program execution interface for GenoRing Tools

=head1 SYNOPSIS

    # Simple use:
    use Genoring::GenoringTool;
    my $program = new Genoring::GenoringTool('samtools');
    $program->run();
    print $program->getResponse();


    # More complex use (derived class):
    package Genoring::faidx;
    ...
    use base qw(Genoring::GenoringTool);
    ...
    sub getProgram
    {
      return 'samtools faidx';
    }

    sub getParameters
    {
      my ($self) = @_;

      # Get parameters.
      my $fasta_file = $self->query->param('fasta') || '';
      my $output_file = $self->query->param('output') || '';

      # Check for parameter error.
      my $error = $self->query->cgi_error;
      if ($error) {
        # Request not processed.
        $self->data->{'error'} = $error;
        return;
      }

      # Missing FASTA.
      if (!$fasta_file) {
        $self->data->{'error'} = '400 Missing FASTA file path';
        return;
      }

      my $parameters = $fasta_file;
      if ($output_file) {
        $parameters .= ' -o ' . $output_file;
        $self->data->{'output_fai'} = $output_file;
      }
      else {
        $self->data->{'output_fai'} = $fasta_file . '.fai';
      }
      return $parameters;
    }

    my $program = new Genoring::faidx('fasta indexer');
    $program->run();
    print $program->getResponse();


=head1 REQUIRES

Perl5

=head1 EXPORTS

Nothing

=head1 DESCRIPTION

This is an interface for programs provided by GenoRing Tools.

=cut

package Genoring::GenoringTool;


use strict;
use warnings;
use utf8;
use CGI qw/:standard/;
use JSON;




# Package subs
###############

=pod

=head1 STATIC METHODS

=head2 CONSTRUCTOR

B<Description>: Creates a new instance and sets class member 'name' to
the given program name.

B<ArgsCount>: 1

=over 4

=item $name: (string) (R)

The name of the program that as been instanciated.

=back

B<Return>: (Genoring::GenoringTool child class)

a new instance.

=cut

sub new
{
  my ($proto, $name) = @_;
  my $class = ref($proto) || $proto;

  # parameters check
  if ((2 != @_) || (!$name))
  {
      die "usage: my \$instance = Genoring::GenoringTool->new(name);";
  }

  # instance creation
  my $self = {
    'name' => $name,
    'query' => new CGI,
    'data' => {},
  };
  bless($self, $class);

  return $self;
}


=pod

=head1 AUTOLOAD

=cut

sub AUTOLOAD {
  my ($self, $value) = @_;
  our $AUTOLOAD;
  (my $method = lc $AUTOLOAD) =~ s/.*:://;
  if (defined($value)) {
    $self->{$method} = $value;
  }
  return $self->{$method};
}


=pod

=head1 METHODS

=head2 getProgram

B<Description>: Returns the program command name.

B<ArgsCount>: 1

=over 4

=item $self: (Genoring::GenoringTool child class)

current program object.

=back

B<Return>: (string)

The command name.

=cut

sub getProgram
{
  my ($self) = @_;
  return $self->name || die "Not implemented!\n";
}


=pod

=head2 getParameters

B<Description>: Returns command line parameters.

B<ArgsCount>: 1

=over 4

=item $self: (Genoring::GenoringTool child class)

current program object.

=back

B<Return>: (string or undef)

The command line parameters in a string or undef in case of error.

=cut

sub getParameters
{
  my ($self) = @_;

  # Get parameters.
  my $parameters = $self->query->param('param') || '';

  # Check for parameter error.
  my $error = $self->query->cgi_error;
  if ($error) {
    # Request not processed.
    $self->data->{'error'} = $error;
    return;
  }

  my @parameters = map
    {
      # Remove surrounding quotes.
      s/^(?:"(.*)")|(?:'(.*)')$/$1$2/;
      # Escape single quotes.
      s/'/'"'"'/g;
      # Re-quote.
      return "'$_'";
    }
    split(/ +/, $parameters);
  $parameters =~ join(' ', @parameters);

  return $parameters;
}


=pod

=head2 run

B<Description>: Runs the program command.

B<ArgsCount>: 1

=over 4

=item $self: (Genoring::GenoringTool child class)

current program object.

=back

B<Return>: (nothing)

=cut

sub run
{
  my ($self) = @_;

  my $parameters = $self->getParameters();

  # Do not run in case of previous error.
  if (!defined($parameters) || $self->data->{'error'}) {
    return;
  }

  my $command = $self->data->{'command'} = join(
    ' ',
    $self->getProgram(),
    $parameters
  );

  # Run command.
  $self->data->{'output'} = qx($command 2>&1);

  # Check for command error.
  my $error_message = '';
  if ($?) {
    if ($? == -1) {
      $error_message = "Execution failed! (error $?)\n$!";
    }
    elsif ($? & 127) {
      $error_message = "Execution failed!\n"
        . sprintf(
          "Child died with signal %d, %s coredump\n",
          ($? & 127), ($? & 128) ? 'with' : 'without'
        );
    }
    else {
      $error_message = "Execution failed! " . sprintf("(error %d)", $? >> 8);
    }
    $self->data->{'error'} = "500 Program execution error";
    $self->data->{'message'} = $error_message;
  }
}


=pod

=head2 getResponse

B<Description>: Returns the response string.

B<ArgsCount>: 1

=over 4

=item $self: (Genoring::GenoringTool child class)

current program object.

=back

B<Return>: (string)

The response content. It is an HTTP response with a JSON content type with the
following structure (some keys may not be set):
{
  'error' => '000 The error code with a single line text',
  'output' => 'multi-line text printed to STDOUT and STDERR.',
  'message' => 'Error message or other type of message provided by this script',
  'command' => 'The executed command line with its parameters',
  # Additional keys like file URIs, tokens, etc. can be added by sub-classes.
}

=cut

sub getResponse
{
  my ($self) = @_;

  my $response = '';
  if ($self->data->{'error'}) {
    $response .= $self->query->header(-type => 'application/json', -status => $self->data->{'error'});
  }
  else {
    $response = $self->query->header(-type => 'application/json');
  }

  $response .= to_json($self->data);

  return $response;
}


=pod

=head1 AUTHORS

Valentin GUIGNON (Bioversity), v.guignon@cgiar.org

=head1 VERSION

Version 1.0.0

Date 07/04/2025

=cut

return 1; # package return
