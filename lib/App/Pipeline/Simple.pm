#-----------------------------------------------------------------
# Pipeline::Simple
#
## no critic
package App::Pipeline::Simple;
# ABSTRACT: Simple workflow manager
# VERSION

use strict;
use warnings;
use autodie;
## use  critic

use Carp;
use File::Basename;
use File::Copy;
use YAML::Syck;
use Log::Log4perl qw(get_logger :levels :no_extra_logdie_message);
use Data::Printer;

#-----------------------------------------------------------------
# Global variables
#-----------------------------------------------------------------

my $logger_level =   {
    '-1' => $WARN,
    '0'  => $INFO,
    '1'  => $DEBUG,
};

#-----------------------------------------------------------------
# new
#-----------------------------------------------------------------
sub new {
    my ($class, @args) = @_;

    # create an object
    my $self = bless {}, ref ($class) || $class;

    # set all @args into this object with 'set' values
    my (%args) = (@args == 1 ? (value => $args[0]) : @args);

    # do dir() first so that we know where to write the log
    $self->dir($args{'dir'}) if defined $args{'dir'};

    # start logging
    $self->_configure_logging;

    foreach my $key (keys %args) {
	next if $key eq 'config'; # this needs to be evaluated last
	next if $key eq 'dir'; # done this
	## no critic
        no strict 'refs';
	## use critic
        $self->$key($args{$key});
    }
    # delayed to first find out the verbosity level
    $self->logger->info("Logging into file: [ ". $self->dir. '/pipeline.log'. " ]");

    # this argument needs to be done last
    $self->config($args{'config'}) if defined $args{'config'};

    # look into dir() if config not given
    $self->config($self->dir. '/config.yml')
	if not $self->{config} and defined $self->dir and -e $self->dir. '/config.yml';

    # die if no config found
    $self->logger->fatal("pipeline config file not provided or not found in pwd")
	if not $self->{config} and not $self->debug;

    # done
    return $self;
}


#-----------------------------------------------------------------
# Configure the logger
#-----------------------------------------------------------------

sub _configure_logging {
    my $self = shift;

    my $logger_config = q(
      log4perl.category.Pipeline         = INFO, Screen
        log4perl.appender.Screen         = Log::Log4perl::Appender::Screen
        log4perl.appender.Screen.stderr  = 1
        log4perl.appender.Screen.layout  = Log::Log4perl::Layout::SimpleLayout
    );

    Log::Log4perl->init_once( \$logger_config );
    my $logger = Log::Log4perl->get_logger("Pipeline");

    if ($self->dir) {
	my $to_file = Log::Log4perl::Appender->new
	    ("Log::Log4perl::Appender::File",
	     name     => 'Log',
	     filename => $self->dir. '/pipeline.log',
	     mode     => 'append');
	my $pattern =  '%d [%r] %p %L | %m%n';
	my $layout = Log::Log4perl::Layout::PatternLayout->new ($pattern);
        $to_file->layout ($layout);

	$logger->add_appender($to_file);
    }

    $logger->level( $INFO );
    $self->logger($logger);
}



#-----------------------------------------------------------------
#
#-----------------------------------------------------------------

sub verbose {
    my ($self, $value) = @_;
    if (defined $value) {
	$self->{_verbose} = $value;

        # verbose   =  -1    0     1
	# log level =  WARN INFO  DEBUG

	$self->logger->level( $logger_level->{$value} );
    }
    return $self->{_verbose};
}

sub id {
    my ($self, $value) = @_;
    if (defined $value) {
	$self->{_id} = $value;
    }
    return $self->{_id};
}

sub description {
    my ($self, $value) = @_;
    if (defined $value) {
	$self->{_description} = $value;
    }
    return $self->{_description};
}

sub name {
    my ($self, $value) = @_;
    if (defined $value) {
	$self->{_name} = $value;
    }
    return $self->{_name};
}

sub path {
    my ($self, $value) = @_;
    if (defined $value) {
	$self->{_path} = $value;
    }
    return $self->{_path};
}

sub next_id {
    my ($self, $value) = @_;
    if (defined $value) {
	$self->{_next_id} = $value;
    }
    return $self->{_next_id};
}


sub input {
    my ($self, $value) = @_;
    if (defined $value) {
	$self->{_input} = $value;
    }
    return $self->{_input};
}


sub itype {
    my ($self, $value) = @_;
    if (defined $value) {
	$self->{_itype} = $value;
    }
    return $self->{_itype};
}

sub start {
    my ($self, $value) = @_;
    if (defined $value) {
	$self->{_start} = $value;
    }
    return $self->{_start};
}


sub stop {
    my ($self, $value) = @_;
    if (defined $value) {
	$self->{_stop} = $value;
    }
    return $self->{_stop};
}


sub debug {
    my ($self, $value) = @_;
    if (defined $value) {
	$self->{_debug} = $value;
    }
    return $self->{_debug};
}

sub logger {
    my ($self, $value) = @_;
    if (defined $value) {
	$self->{_logger} = $value;
    }
    return $self->{_logger};
}

sub config {
    my ($self, $config) = @_;

    if ($config) {
	$self->logger->info("Using config file: [ ". $config. " ]");
	my $pwd = `pwd`; chomp $pwd;
	$self->logger->debug("pwd: $pwd");
	die unless -e $config;
	# copy the pipeline config

	if ($self->dir and not -e $self->dir."/config.yml") {
	    #print "--->", `pwd`, "\n";
	    copy $config, $self->dir."/config.yml";
	    $self->logger->info("Config file [ $config ] copied to: [ ".
				  $self->dir."/config.yml ]");
	}

	$self->{config} = LoadFile($self->dir."/config.yml");

	# set pipeline start parameters
	$self->id('s0');
	$self->name($self->{config}->{name} || '');
	$self->description($self->{config}->{description} || '');

	# go through all steps once
	my $nexts;		# hashref for finding start point(s)
	for my $id (sort keys %{$self->{config}->{steps}}) {
	    my $step = $self->{config}->{steps}->{$id};

	    # bless all steps into Pipeline objects
	    bless $step, ref($self);

	    #print "ERROR: $id already exists\n" if defined $self->step($id);
	    # create the list of all steps to be used by each_step()
	    $step->id($id);
	    push @{$self->{steps}}, $step;

	    # a step without a parent is a starting point, store those with children
	    foreach my $next (@{$step->{next}}) {
		$nexts->{$next}++;
	    }
	}

	# store starting points, not listed as children
	foreach my $step ($self->each_step) {
	    push @{$self->{next}}, $step->id
	       unless $nexts->{$step->id}
	}

	#run needs to fail if starting input values are not set!

	# insert the startup value into the appropriate starting step
	# unless we are reading old config
	if ($self->itype and $self->input) { # only if new starting input value has been given
	    $self->logger->info("Input value: [". $self->input. "]" );
	    $self->logger->info("Input type: [". $self->itype. "]" );
	    my $real_start_id;
	    for my $step ( $self->each_step) {
		#my $s = p $step;
		#$self->logger->info("Step: [". $s. "]" );

		# if input type is right, insert the value
		# note only one of the each type can be used
		foreach my $key ( keys %{$step->{args}} ) {
		    my $arg = $step->{args}->{$key};

		    next unless $key eq 'in';
		    next unless defined $arg->{type};
		    next unless $arg->{type} eq $self->itype;

		    #my $s = p $arg;
		    #$self->logger->info("Arg before: [". $s. "]" );

#		    $self->logger->info("Input arg: [". $s. "]" );
		    $arg->{value} = $self->input;
		    $real_start_id = $step->id;
#		    my $ss = p $arg;
#		    $self->logger->info("Arg after: [". $ss. "]" );
#		    $self->logger->info("Start ID: [". $real_start_id. "]" );
		}
	    }
	    $self->{next} = undef;
	    push @{$self->{next}}, $real_start_id;
#	    my $s = p $self->config;
#	    $self->logger->info("Self-config after: [". $s. "]" );
	    $self->logger->info("Starting point: [". $real_start_id. "]" );

	    # the stored config file needs to be overwritten with these modifications
	    open my $OUT, ">", $self->dir."/config.yml";
#	    print $OUT 'testing';
	    print $OUT Dump ($self->config);
	}
    }
    return  $self->{config};
}

#-----------------------------------------------------------------
#
#-----------------------------------------------------------------
sub dir {
    my ($self, $dir) = @_;
    if ($dir) {
	mkdir $dir unless -e $dir and -d $dir;
	croak "Can not create project directory $dir"
            unless -e $dir and -d $dir;
	$self->{_dir} = $dir;
    }
    $self->{_dir} || '';
}

#-----------------------------------------------------------------
#
#-----------------------------------------------------------------
sub step {
    my ($self) = shift;
    my $id = shift;
    return $self->{config}->{steps}->{$id};
}

sub each_next {
    #map { $_->{id} } grep { $_->{id} } @{shift->{next}};
    @{shift->{next}};
}

sub each_step {
    @{shift->{steps}};
}



sub run {
    my ($self) = shift;
    unless ($self->dir) {
	$self->logger->fatal("Need an output directory to run()");
	croak "Need an output directory to run()";
    }

    ###
    # check for input file and warn if not  found

    chdir $self->{_dir};

    #
    # Determine where in the pipeline to start
    #

    my @steps; # array of next execution points

    # User has given a starting point id
    if ($self->start) {
	$self->logger->info("Start point: user input [". $self->start. "]" );
	push @steps, $self->start;
	$self->logger->info("Starting at [". $self->start. "]" );
    }
    # determine if and where the execution of the pipeline was interrupted
    elsif (-e $self->dir. "/pipeline.log") {
	$self->logger->info("Start point: consult the log [".
			    $self->dir. "/pipeline.log ]");
	open my $LOG, '<', $self->dir. "/pipeline.log"
	    or $self->logger->fatal("Can't open ". $self->dir.
				    "/pipeline.log for reading: $!");
	my $in_execution;

	# look into only the latest run
	my @log;
	while (<$LOG>) {
	    push @log, $_;
	    @log = () if /Run started/;
	}

	my $done;
	for (@log) {
	    next unless /\[(\d+)\]/;
	    undef $in_execution; # start of a new run
	    next unless /\| (Running|Finished) +\[(\w+)\]/;
	    $in_execution->{$2}++ if $1 eq 'Running';
	    delete $in_execution->{$2} if $1 eq 'Finished';
	    $done = 1 if /DONE/;
	}

	@steps = sort keys %$in_execution;
	if (scalar @steps == 0 and $done) {
	    $self->logger->warn("Pipeline is already finished. ".
				"Drop -config and define the start step to rerun" );
	    exit 0;
	}
	elsif (@steps) {
	    $self->logger->info("Continuing at ". $steps[0] );
	} else {
	    # start from beginning
	    @steps = $self->each_next;
	    $self->logger->info("Starting at [". $steps[0] . "]");
	}
    }
    else {
	# start from beginning
	$self->logger->info("Start point: start from beginning" );
	@steps = $self->each_next;
	$self->logger->info("Starting at [". $steps[0] . "]");

    }

    #
    # Execute one step at a time
    #

    $self->logger->info("Run started");

    while (my $step_id = shift @steps) {
	$self->logger->debug("steps: [". join (", ", @steps). "]");
	my $step = $self->step($step_id);
	croak "ERROR: Step [$step_id] does not exist" unless $step;
	# check that we got an object

	# check that the input file exists
	foreach my $arg (@{$step->{arg}}) {
	    next unless $arg->{key} eq 'in';
	    next unless $arg->{type} =~ /file|dir/ ;
	}

	my $command = $step->render;
	$self->logger->info("Running     [". $step->id . "] $command" );
	`$command`;
	$self->logger->info("Finished    [". $step->id . "]" );

	# Add next step(s) to the execution queue unless
	# the user has asked to stop here
	if ( defined $self->{_stop} and $step->id eq $self->{_stop} ) {
	    $self->logger->info("Stopping at [". $step->id . "]" );
	} else {
	    push @steps, $step->each_next;
	}

    }
    $self->logger->info("DONE" );
    return 1;
}


#-----------------------------------------------------------------
# Render a step into a command line string
#-----------------------------------------------------------------

sub render {
    my ($step, $display) = @_;

    my $str;
    # path to program
    if (defined $step->{path}) {
	$str .=  $step->{path};
	$str .=  '/' unless substr($str, -1, 1) eq '/' ;
    }
    # program name
    $str .=  $step->{name} || '';

    # arguments
    my $endstr = '';

    foreach my $key (keys %{$step->{args}}) {
	my $arg = $step->{args}->{$key};

	if (defined $arg->{type} and $arg->{type} eq 'unnamed') {
	    $str .= ' '. $arg->{value};
	    next;
	}

	if (defined $arg->{type} and $arg->{type} eq 'redir') {
	    if ($key eq 'in') {
		$endstr .= " < ". $arg->{value};
	    }
	    elsif ($key eq 'out') {
		$endstr .= " > ". $arg->{value};
	    } else {
		croak "Unknown key ". $key;
	    }
	    next;
	}

	if (defined $arg->{value}) {
	    $str .= " -". $key. "=". $arg->{value};
	} else {
	    $str .= " -". $key;
	}

    }
    $str .= $endstr;

    $str =~ s/(['"])/\\$1/g if $display;

    return $str;
}

sub stringify {
    my ($self) = @_;

    $self->logger->info("Stringify starting" );

    my @res;
    # add checks for duplicated ids

    # add check for a next pointer that leads nowhere

    my @steps = $self->each_next;

    my $outputs; # hashref for storing input and output filenames
    while (my $step_id = shift @steps) {
	my $step = $self->step($step_id);

	push @res, $step->id, "\n";
	push @res, "\t", $step->render('4display'), " # ";
	map { push @res, "->", $_, " " } $step->each_next;

	push @steps, $step->each_next;

	foreach my $arg (@{$step->{arg}}) {
	    if ($arg->{key} eq 'out') {
		for ($step->each_next) {
		    push @res, "\n\t", "WARNING: Output file [".
			$arg->{value}."] is read by [",
			$outputs->{$arg->{value}}, "] and [$_]"
		    if  $outputs->{$arg->{value}};

		    $outputs->{$arg->{value}} = $_;
		}
	    }
	    elsif ($arg->{key} eq 'in' and $arg->{type} ne 'redir') {
		my $prev_step_id = $outputs->{$arg->{value}} || '';
		push @res, "\n\t". "ERROR: Output from the previous step is not [".
		    ($arg->{value} || ''). "]"
		    if $prev_step_id ne $step->id and $prev_step_id eq $self->id;
	    }
	    # test for steps not referenced by other steps (missing next tag)
	}
	push @res, "\n";
    }
    return join '', @res;
}


sub graphviz {
    my $self = shift;
    my $function = shift;

    $self->logger->info("Graphing started. Redirect to a dot file" );

    require GraphViz;
    my $g= GraphViz->new;

    my $end;
    $g->add_node($self->id,
		 label => $self->id. " : ".
		 $self->render('4display'), rank => 'top');
    map {  $g->add_edge('s0' => $_) }  $self->each_next;
    if ($self->description) {
	$g->add_node('desc', label => $self->description,
		     shape => 'box', rank => 'top');
	$g->add_edge('s0' => 'desc');
    }

    foreach my $step ($self->each_step) {
	$g->add_node($step->id, label => $step->id. " : ". ($step->name||'') );
	if ($step->each_next) {
	    map {  $g->add_edge($step->id => $_, label => $step->render('display') ) }
		$step->each_next;
	} else {
	    $end++;
	    $g->add_node($end, label => ' ');
	    $g->add_edge($step->id => $end, label => $step->render('display') );
	}

    }
    return $g->as_dot;

    $self->logger->info("Graphing done. Process the dot ".
			 "file (e.g. dot -Tpng p.dot|display " );

}

1;
__END__

=head1 SYNOPSIS

  # called from a script

=head1 DESCRIPTION

Workflow management in computational (biological) sciences is a hard
problem. This module is based on assumption that UNIX pipe and
redirect system is closest to optimal solution with these
improvements:

* Enforce the storing of all intermediary steps in a file.

  This is for clarity, accountability and to enable arbitrarily big
  data sets. Pipeline can contain independent steps that remove
  intermediate files if so required.

* Naming of each step.

  This is to make it possible to stop, restart, and restart at any
  intermediate step after adjusting pipeline parameters.

* detailed logging

  To keep track of all runs of the pipeline.

A pipeline is a collection of steps that are functionally equivalent
to a pipeline. In other words, execution of a pipeline equals to
execution of a each ordered step within the pipeline. From that derives
that the pipeline object model needs only one object that can
recursively represent the whole pipeline as well as individual steps.

=head1 RUNNING

App::Pipeline::Simple comes with a wrapper C<spipe> command line
program. Do

   spipe -h

to see instructions on how to run it.

Example run:

  spipe -config t/data/string_manipulation.xml -d /tmp/test

reads instructions from the config file and writes all information to
the project directory.


The debug option will parse the config file, print out the command
line equivalents of all commands and print out warnings of problems
encountered in the file:

  spipe -config t/data/string_manipulation.xml -d /tmp/test

An other tool integrated in the system is visualization of the
execution graph. It is done with the help of L<GraphViz> perl
interface module that will need to be installed from CPAN.

The following command line creates a Graphviz dot file, converts it
into an image file and opens it with the Imagemagic display program:

  spipe -config t/data/string_manipulation.xml -graph > \
    /tmp/p.dot; dot -Tpng /tmp/p.dot | display

=head1 CONFIGURATION

The default configuration is written in YAML, a simple and human
readable language that can be parsed in many languages cleanly into
data structures.

The YAML file contains four top level keys for the hash that the file
will be read into: 1) C<name> to give the pipeline a short name, 2)
C<version> to indicate the version number, 3) C<description> to give a
more verbose explanation what the pipeline does, and 4) C<steps>
listing pipeline steps.

  ---
  description: "Example of a pipeline"
  name: String Manipulation
  version: '0.4'
  steps:

Each C<step> needs an C<id> that is unique within the pipeline and a
C<name> that identifies an executable somewhere in the system
path. Alternatively, you can give the path leading to the executable
file with key C<path>. The name will be added to the path,
padded with a suitable separator character, if needed.

Arguments to the executable are given individually within C<arg>
tags. They are named with the C<key> attribute. A single hyphen is
added in front of the arguments when they are executed. If two hyphens
are needed, just add one the file.

Arguments can exist without values, or they can be given with
attribute C<value>.

  s3:
    name: cat
    args:
      in:
        type: redir
        value: s1.txt
      "n": {}
      out:
        type: redir
        value: s3_mod.txt
    next:
      - s4

There are two special keys C<in> and C<out> that need to have a further
 C<type> defined. The IO C<type> can get two kind of values:

=over

=item  C<unnamed>

that indicates that the argument is an unnamed argument
to the executable.

=item  C<redir>

will be interpreted as UNIX redirection character '&lt' or '&gt'
depending on the context.

=back

The values C<file> and C<dir> are not needed by the pipeline
but are useful to include to make the pipeline easier to read for
humans. The interpretation of these arguments is done by the program
executable called by the step.

Finally, the C<step> tag can contain the C<next> key that
gives an array of IDs for the next steps in the execution. Typically,
these steps depends on the previous step for input.

Practices that are completely bonkers, like spaces in file names, are
not supported.

=head2 Advanced features

The pipeline does not have to be linear; it can contain branches. For
example, the pipeline can have several start points with different
kinds of input: file and string.

Sometimes it is useful to be run the same pipeline with different
parameter. The starting point of execution can take a value from the
command line.  Leave the value for the given argument blank in the
configuration file and give it from the command line. Matching of
values is done by matching the type string.

  spipe -conf input_demo.yml --input=ABC --itype=str

  ---
  description: "Demonstrate input from command line"
  name: input.yml
  version: '0.1'
  steps:
    s1:
      name: echo
      args:
        in:
          type: unnamed
          value:
        out:
          type: redir
          value: s1_string.txt

The empty C<value> will be filled in from the command line into the
C<config.yml> stored in the project directory. Also, the config file
looks slightly different since the steps are written out as
App::Pipeline::Simple objects. Functionally there is no difference.


=method new

Constructor

=method verbose

Control logging output. Defaults to 0.

Setting verbose sets the logging level:

  verbose   =  -1    0     1
  log level =>  WARN INFO  DEBUG

=method config

Read in the named config file.

=method id

ID of the step

=method description

Verbose description of the step

=method name

Name of the program that will be executed

=method path

Path to the directory where the program resides. Can be used if the
program is not on path. Will be prepended to the name.

=method next_id

ID of the next step in execution. It typically depends on the output
of this step.

=method input

Value read in interactively from command line

=method itype

Type of input for the command line value

=method start

The ID of the step to start the execution

=method stop

The ID of the step to stop the execution

=method dir

Working directory where all files are stored.

=method step

Returns the step by its ID.

=method each_next

Return an array of steps after this one.

=method each_step

Return all steps.

=method run

Run this step and call the one(s).

=method debug

Run in debug mode and test the configuration file

=method logger

Reference to the internal Log::Logger4perl object

=method render

Transcribe the step into a UNIX command line string ready for display
or execution.

=method stringify

Analyze the configuration without executing it.

=method graphviz

Create a GraphViz dot file from the config.

=cut


