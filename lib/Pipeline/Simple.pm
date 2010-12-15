#-----------------------------------------------------------------
# Pipeline::Simple
# Author: Heikki Lehvaslaiho <heikki.lehvaslaiho@gmail.com>
# For copyright and disclaimer see Pipeline::Simple.pod.
#
# Lightweight workflow manager

package Pipeline::Simple;
# ABSTRACT: Simple workflow manager

use strict;
use warnings;

use Carp;
use File::Basename;
use XML::Simple;
use Data::Dumper;
use Log::Log4perl;


#-----------------------------------------------------------------
# Global variables (available for all packages in this file)
#-----------------------------------------------------------------

use vars qw( $AUTOLOAD );


#-----------------------------------------------------------------
# A list of allowed options/arguments (used in the new() method)
#-----------------------------------------------------------------



{
    my %allowed =
	(

         id             => 1,
         description    => 1,

         name           => 1,
	 path           => 1,
	 args           => 1,
	 next_id        => 1,

	 config         => 1,
	 add            => 1,

	 input          => 1,
         itype          => 1,
	 dir            => 1,
	 run            => 1,
	 stringify      => 1,

	 continue       => 1,
	 start          => 1,
	 stop           => 1,

	 debug          => 1,
	 );

    sub accessible {
	my ($self, $attr) = @_;
	exists $allowed{$attr};
    }
}

#-----------------------------------------------------------------
# Configure the logger
#-----------------------------------------------------------------
my $logger_config = q(
    log4perl.category.Pipeline         = WARN, Logfile
    log4perl.appender.Logfile          = Log::Log4perl::Appender::File
    log4perl.appender.Logfile.filename = pipeline.log
    log4perl.appender.Logfile.layout = \
	Log::Log4perl::Layout::PatternLayout
    log4perl.appender.Logfile.layout.ConversionPattern = %d (%L): [%p] %m %n
);




#-----------------------------------------------------------------
# Deal with 'set' and 'get' methods.
#-----------------------------------------------------------------
sub AUTOLOAD {
    my ($self, $value) = @_;
    my $ref_sub;
    if ($AUTOLOAD =~ /.*::(\w+)/ && $self->accessible ("$1")) { 

	# get/set method
	my $attr_name = "$1";
	$ref_sub =
	    sub {
		# get method
		local *__ANON__ = "__ANON__$attr_name" . "_" . ref ($self);
		my ($this, $value) = @_;
		return $this->{$attr_name} unless defined $value;

		# set method
		$this->{$attr_name} = $value;
		return $this->{$attr_name};
	    };

    } else {
	throw ("No such method: $AUTOLOAD");
    }

    ## no critic  
    no strict 'refs'; 
    *{$AUTOLOAD} = $ref_sub;
    use strict 'refs'; 
    ## use critic

    return $ref_sub->($self, $value);
}

#-----------------------------------------------------------------
# Keep it here! The reason is the existence of AUTOLOAD...
#-----------------------------------------------------------------
sub DESTROY { }

#-----------------------------------------------------------------
# new
#-----------------------------------------------------------------
sub new {
    my ($class, @args) = @_;

    # start logging
#    Log::Log4perl->init_once( \$logger_config );
#    my $log = get_logger("Pipeline");

    # create an object
    my $self = bless {}, ref ($class) || $class;

    # set all @args into this object with 'set' values
    my (%args) = (@args == 1 ? (value => $args[0]) : @args);

    foreach my $key (keys %args) {
	next if $key eq 'config'; # this needs to be evaluated last
	## no critic  
        no strict 'refs';
	## use critic  
        $self->$key($args{$key});
    }
 #   $log->debug("Pipeline object id ". $self->id);
#    $log->warn("Pipeline object id | warn". $self->id);


    # this needs to be done last
    $self->config($args{'config'}) if defined $args{'config'};

    $self->config($self->dir. '/config.xml')
	if not $self->{config} and defined $self->dir and -e $self->dir. '/config.xml';
    croak "ERROR: pipeline config file not provided or not found in pwd"
	if not $self->{config} and not $self->debug;
    # done


    return $self;
}

#-----------------------------------------------------------------
#
#-----------------------------------------------------------------

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

sub config {
    my ($self, $config) = @_;
    if ($config) {
	croak "ERROR: config file [$config] not found in [". $self->dir. "/$config" . "] from [". `pwd`  unless -e "$config";
	$self->{config} = XMLin($config, KeyAttr => {step => 'id'});

	# set pipeline start parameters
	$self->id('s0');
	$self->name($self->{config}->{name} || '');
	$self->description($self->{config}->{description} || '');

	# go through all steps once
	my $nexts;		# hashref for finding start point(s)
	for my $id (sort keys %{$self->{config}->{step}}) {
	    my $step = $self->{config}->{step}->{$id};

	    # bless all steps into Pipeline objects
	    bless $step, ref($self);

	    #print "ERROR: $id already exists\n" if defined $self->step($id); 
	    # create the list of all steps to be used by each_step()
	    $step->id($id);
	    push @{$self->{steps}}, $step;

	    #turn a next hashref into an arrayref, (fixing XML::Simple complication)
	    unless ( ref($step->{next}) eq 'ARRAY' ) {
		my $next = $step->{next};
		delete $step->{next};
		push @{$step->{next}}, $next;
	    }

	    # a step without a parent is a starting point
	    foreach my $next (@{$step->{next}}) {
		$nexts->{$next->{id}}++ if $next->{id}; 
	    } 	
	}
#	print Dumper $nexts;
	# store starting points
	foreach my $step ($self->each_step) {
	    push @{$self->{next}}, { id => $step->id}
	       unless $nexts->{$step->id}
	}

	#run needs to fail if starting input values are not set!

	# insert the startup value into the appropriate starting step
	# unless we are reading old config
	if ($self->itype and $self->input) { # only if new starting input value has been given
	    my $real_start_id;
	    for my $step_id ( $self->each_next) {
		my $step = $self->step($step_id);

		# if input type is right, insert the value
		# note only one of the each type can be used
		foreach my $arg (@{$step->{arg}}) {
		    #print Dumper $arg;
		    next unless $arg->{key} eq 'in' and 
			        defined $arg->{type} and 
			        $arg->{type} eq $self->itype;
		    #print Dumper $self->itype, $step->id, $arg;
		    $arg->{value} = $self->input;
		    #print Dumper $arg;
		    $real_start_id = $step_id;
		}
	    }
	    $self->{next} = undef;
	    push @{$self->{next}}, { id => $real_start_id};
	}

#	print Dumper $self->{next};
#	my @real_start_id = grep { $real_start_id eq $_->{id} } @{$self->each_next};
#	my @real_start_id = @{$self->each_next};
#	print Dumper $self->{next}, @real_start_id;
#	$self->{next} = \@real_start_id  ;

#	print Dumper $self->step('s1.2');
	#print Dumper $self;
	#exit;
    }
    return  $self->{config};
}

#-----------------------------------------------------------------
#
#-----------------------------------------------------------------

sub log {
    my ($self) = shift; 

    croak "Need an output directory" unless $self->dir;

    my $CONFIGFILE = 'config.xml';
    my $LOGFILE = 'log.xml';

    open my $CONF, '>', $CONFIGFILE;
    print $CONF XMLout($self->{config});

    open my $LOG, '>', $LOGFILE;
    print $LOG XMLout($self->{log});

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
	$self->{dir} = $dir;
    }
    $self->{dir};
}

#-----------------------------------------------------------------
#
#-----------------------------------------------------------------
sub step {
    my ($self) = shift;
    my $id = shift;
    return $self->{config}->{step}->{$id};
}

sub each_next {
    map { $_->{id} } grep { $_->{id} } @{shift->{next}};
}

sub each_step {
    @{shift->{steps}};
}

sub next_step {
    my ($self) = @_;

    # check for the log here to restart execution half way through

    # at this stage, only one starting step
    # find the first one: not referenced by any other steps in the pipeline

    for my $id (sort keys %{$self->{config}->{step}}) {
	
    }    
}

sub time {
    my ($self) = @_;
    return scalar localtime;
}

sub run {
    my ($self) = @_;

    croak "Need an output directory" unless $self->dir;

    ###
    # check for input file and warn if not  found

    chdir $self->{dir};

    # idea: launch separate process for each step using Parallel::Forkmanager

    #
    # Determine where in the pipeline to start
    #

    my @steps; # array of next execution points

    # User has given a starting point id
    if ($self->{start}) {
	push @steps, $self->{start};
    }

    # determine where the execution of the pipeline was interrupted
    elsif (-e $self->dir. "/log.xml") {
	$self->{log} = XMLin('log.xml', KeyAttr => {step => 'id'});	
	#print Dumper $self->{log}, "----------------------------------";
	for my $step_id (keys %{$self->{log}}) {
	    push @steps, $step_id
		if not defined $self->{log}->{$step_id}->{end_time};
	}
    } else { 	# or start from the beginning
	@steps = $self->each_next;
    }
#    print Dumper \@steps; exit;

    #
    # Execute one step at a time
    #
    while (my $step_id = shift @steps) {
	$self->{log}->{$step_id}->{start_time} = $self->time;
	my $step = $self->step($step_id);
	croak "ERROR: Step [$step_id] does not exist" unless $step;
	# check that we got an object

	print $step->id, "\t", $step->render, "\n";

	# check that the input file exists
	foreach my $arg (@{$step->{arg}}) {
	    next unless $arg->{key} eq 'in';
	    next unless $arg->{type} =~ /file|dir/ ;
#	    croak "Can not read input at [". $arg->{value}. "]"
#		unless -e $arg->{value};
	}

#	print Dumper $step;exit;
	$self->{log}->{$step_id}->{action} = $step->render;

	my $command = $step->render;
	`$command`;
	$self->{log}->{$step_id}->{end_time} = $self->time;

	# Add next step(s) to the execution queue unless
	# the user has asked to stop here
	push @steps, $step->each_next 
	    unless defined $self->{stop} and $step_id eq $self->{stop};

    }
}


#-----------------------------------------------------------------
# Render a step into a command line string
#-----------------------------------------------------------------

sub render {
    my ($step, $display) = @_;

#    $step ||= $self;
#    print "\n"; print Dumper $step; print "\n";

    my $str;
    # path to program
    if (defined $step->{path}) {
	$str .=  $step->{path};
	$str .=  '/' unless substr($str, -1, 1) eq '/' ;
    }
    # program name
    $str .=  $step->{name};

    # arguments
    my $endstr = '';
    foreach my $arg (@{$step->{arg}}) {

	if (defined $arg->{type} and $arg->{type} eq 'unnamed') {
	    #$str .= ' "'. $arg->{value}. '"';
	    $str .= ' '. $arg->{value};
	    next;
	}

	if (defined $arg->{type} and $arg->{type} eq 'redir') {
	    if ($arg->{key} eq 'in') {
		$endstr .= " < ". $arg->{value}; 
	    }
	    elsif ($arg->{key} eq 'out') {
		$endstr .= " > ". $arg->{value}; 
	    } else {
		croak "Unknown key ". $arg->{key};
	    }
	    next;
	}

	if (defined $arg->{value}) {
	    $str .= " -". $arg->{key}. "=". $arg->{value}; 
	} else {
	    $str .= " -". $arg->{key};
	}

    }
    $str .= $endstr;

    $str =~ s/(['"])/\\$1/g if $display;

    return $str;
}

sub stringify {
    my ($self) = @_;

    # add checks for duplicated ids

    # add check for a next pointer that leads nowhere

    my @steps = $self->each_next;
    my $outputs; #hashref for storing input and output filenames 
    while (my $step_id = shift @steps) {
	my $step = $self->step($step_id);
	print $step->id, "\n\t", $step->render('4display'), " # ";
	map { print "->", $_, " " } $step->each_next;

	push @steps, $step->each_next;

#	print "\n"; print Dumper $outputs;
	foreach my $arg (@{$step->{arg}}) {
	    if ($arg->{key} eq 'out') {
		for ($step->each_next) {
		    print "\n\t", "WARNING: Output file [".$arg->{value}."] is read by [",
		    $outputs->{$arg->{value}}, "] and [$_]" 
		    if  $outputs->{$arg->{value}};

		    $outputs->{$arg->{value}} = $_;
		}
	    }
	    elsif ($arg->{key} eq 'in' and $arg->{type} ne 'redir') {
		my $prev_step_id = $outputs->{$arg->{value}} || '';
		print "\n\t", "ERROR: Output from the previous step is not [",
		    $arg->{value} || '', "]" 
		    if $prev_step_id ne $step->id and $prev_step_id eq $self->id;
	    }
	    # test for steps not refencesed by other steps (missing next tag)
	}
	print "\n";
    }
    #print "\n"; print Dumper $outputs;
}


sub graphviz {
    my $self = shift;
    my $function = shift;

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
	$g->add_node($step->id, label => $step->id. " : ". $step->name );
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

}

1;
__END__


#-----------------------------------------------------------------
# only for debugging
#-----------------------------------------------------------------

=head1 NAME

Pipeline::Simple - A simple workflow manager

=head1 SYNOPSIS

  # called from a script

=head1 DESCRIPTION

Workflow management in computational (biological) sciences is a hard
problem. This module is based on assumption that unix pipe and
redirect system is closest to optimal solution with these
improvements:

* Enforce the storing of all intermediry steps in a file. 

  This is for clarity, accountability and to enable arbitrarily big
  data sets. Pipeline can contain a independent step that removes
  intermediate files if so required.

* Naming of each step.

  This is to make it possible to stop, restart, and restart at any
  intermediate step after adjusting pipeline parameters.

* detailed logging ()

  To keep track of all runs of the pipeline.

A pipeline is a collection of steps that are functionally equivalent
to a pipeline. In other words, execution of a pipeline equals to
execution of a each ordered step within the pipeline. From that derives
that the pipeline object model needs only one object that can
recursively represent the whole pipeline and individual steps.

=head2 RUNNING

Pipeline::Simple comes with a wrapper C<pipeline.pl> command line
program. Do

   pipeline.pl -h

to see instructions on how to run it.

Example run:

  pipeline.pl -config t/data/string_manipulation.xml -d /tmp/test

reads instructions from the config file and writes all information to
the project directory.


The debug option will parse the config file, print out the command
line equivalents of all commands and print warnings of problems
encountered in the file:

  pipeline.pl -config t/data/string_manipulation.xml -d /tmp/test

An other tool integrated in the system is visualisation of the
execution graph. It is done withe help of L<GraphViz> perl interface
module that will need to be installed from CPAN first.

The following command line creates the Graphviz dot file, converts it
into an image file and opens it with Imagemagic display program:

  pipeline.pl -config t/data/string_manipulation.xml -graph > \
    /tmp/p.dot; dot -Tpng /tmp/p.dot | display

Additionally, you can check the xml for validity using the DTD file in
the docs directory. The DTD has been written so that any attribute
that can occurr only once can equally well be written as a tag. That
is how L<XML::Simple> treats XML, so the the aim is to maximize that
convernience. The following commandline is convenient way to validate
an XML file:

  xmllint --dtdvalid docs/pipeline.dtd t/data/string_manipulation.xml

=head2 CONFIGURATION

The default configuration is written in XML. The top level tag,
C<pipeline> encloses a unordered list of pipeline C<step>s. A sensible
ordering is encouraged but the pipeline execution does not depend on
it.

In addition to step, there are only three other top level tags: 1)
C<name> to give the pipeline a short name, 2) C<version> to indicate
the version number and 3) C<description> to give a more verbose
explanation what the pipeline does.

  <pipeline>
    <name>String Manipulation</name>
    <version>0.4</version>
    <description>Example of a pipeline
      Same as running:
         echo 'abcd' | tee /tmp/str | wc -c ; cat -n /tmp/str | wc -c
      but every stage is stored in a file
    </description>
  ...
  </pipeline>

Each C<step> needs an C<id> that is unique within the pipeline and a
C<name> that identifies an executable somewhere in the system
path. Alternatively, you can give the path leading to the executable
file with attribute C<path>. The name will be added to it, padded with
a suitable separator character, if needed.

Arguments to the executable are given individually within C<arg>
tags. They are named with the C<key> attribute. A single hyphen is
added in front of the arguments when they are executed. If two hyphens
are needed, just add one the file.

Arguments can exist without values, or they can be given with
attribute C<value>.

  <step id="s3" name="cat">
    <arg key='n' />
    <arg key='in' value="s1.txt" type='redir'/>
    <arg key='out' value="s3_mod.txt" type='redir'/>
    <next id="s4"/>
  </step>

There are two special keys C<in> and C<out> that need the further
attibute C<type>. The attribute C<type> can get several kinds values:
1) C<unnamed> that indicates that the argument is an unnamed argument
to the excutable. 2) C<redir> will be interpreted as unix redirection
character '&lt' or '&gt' depending on the context. 3) C<str> in a
special case which is accompanied by an empty tring as a value that
indicates that the string is read from the command line input.

The last two values C<file> and C<dir> are not needed by the pipeline
but are useful to include to make the pipeline easier to read for
humans. The interpretation of these arguments is done by the program
executable called by the step.

Finally, the C<step> tag can contain one or more C<next> tags that
tell the pipeline the ID of the next step in the execution. Typically,
these steps depends on the previous step for input.

Practicies that are completely bonkers, like spaces in file names, are
not supported.

=head1 ACKNOWLEDGMENTS


=head1 COPYRIGHT

Copyright (c) 2010, Heikki Lehvaslaiho, KAUST (King Abdullah
University of Science and Technology)
All Rights Reserved.

This module is free software; you can redistribute it and/or modify it
under the same terms as Perl itself.

See F<http://dev.perl.org/licenses/artistic.html>

=head1 DISCLAIMER

This software is provided "as is" without warranty of any kind.


=head1 SUBRUTINES

=head2 new

Contructor that uses AUTOLOAD

=head2 config

Read in the named config file.

=head2 id

ID of the step

=head2 description

Verbose desctiption of the step

=head2 name

Name of the program that will be executed

=head2 path

Path to the directory where the program recides. Can be used if the
program is not on path. Will be prepended to the name.

=head2 next_id

ID of the next step in execution. It typically depends on the output
of this step.

=head2 input

Value read in interactively from commanline

=head2 itype

type of input for the commandline value

=head2 start

The ID of the step to start the execution

=head2 stop

The ID of the step to stop the execution

=head2 log

Save config and log of steps into file.

=head2 dir

Working directory where all files are stored.

=head2 step

Returns the step by its ID.

=head2 each_next

Return an array of steps after this one.

=head2 each_step

Return all steps.

=head2 next_step

Deprecated. Superceded by each_next()

=head2 time

Return timestamp.

=head2 run

Run this step and call the one(s).

=head2 debug

Run in debug mode and test teh configuration file

=head2 render

Transcribe the step into a *nix command line string ready for display
or execution.

=head2 stringify

Analyze the configuration without executing it.

=head2 graphviz

Create a GraphViz dot file from the config.

=for Pod::Coverage accessible

=cut


