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
#use Log::Log4perl;


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
    #Log::Log4perl->init_once( \$logger_config );
    #my $log = get_logger("Pipeline");

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
    #$log->debug("Pipeline object id ". $self->id);

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

=head2 

  pipeline.pl  -config pipelines/string_manipulation.xml -graph  > \
    /tmp/p.dot; dot -Tpng /tmp/p.dot| display

=cut

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
