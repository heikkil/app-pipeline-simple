#-----------------------------------------------------------------
# Pipeline
# Author: Heikki Lehvaslaiho <heikki.lehvaslaiho@gmail.com>
# For copyright and disclaimer see Pipeline pod.
#
# Lghtweight workflow manager

package Pipeline;

use strict;
use warnings;
use vars qw( $AUTOLOAD );

use Carp;
use File::Basename;
use XML::Simple;
use Data::Dumper;


=pod

 sceleton

=cut

#-----------------------------------------------------------------
# Global variables (available for all packages in this file)
#-----------------------------------------------------------------
our $VERSION = '0.1';

#-----------------------------------------------------------------
# A list of allowed options/arguments (used in the new() method)
#-----------------------------------------------------------------


{
    my %allowed =
	(

         id             => 1,
         description    => 1,
         name           => 1,
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
	 end            => 1,
	 );

    sub accessible {
	my ($self, $attr) = @_;
	exists $allowed{$attr};
    }
}

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

    no strict 'refs'; 
    *{$AUTOLOAD} = $ref_sub;
    use strict 'refs'; 
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

    # create an object
    my $self = bless {}, ref ($class) || $class;

    # set all @args into this object with 'set' values
    my (%args) = (@args == 1 ? (value => $args[0]) : @args);

    foreach my $key (keys %args) {
	next if $key eq 'config'; # this needs to be evaluated last
        no strict 'refs';
        $self->$key($args{$key});
    }

    # this needs to be done last
    $self->config($args{'config'}) if defined $args{'config'};


    $self->config($self->dir. '/config.xml') if not $self->{config} and -e $self->dir. '/config.xml';
    croak "ERROR: pipeline config file not provided or not found in pwd" if not $self->{config};
    # done

    #print Dumper $self; exit;
    return $self;
}

#-----------------------------------------------------------------
#
#-----------------------------------------------------------------
sub config {
    my ($self, $config) = @_;
    if ($config) {
	croak "ERROR: config file [$config] not found in [". $self->dir. "/$config" . "]" unless -e $self->dir. "/$config";
	$self->{config} = XMLin($self->dir. "/$config", KeyAttr => {tool => 'id'});

	# set pipeline start parameters
	$self->id('s0');
	$self->name($self->{config}->{name} || '');
	$self->description($self->{config}->{description} || '');


	# go through all steps once
	my $nexts;		# hashref for finding start point(s)
	for my $id (sort keys %{$self->{config}->{tool}}) {
	    my $step = $self->{config}->{tool}->{$id};

	    # bless all steps into Pipepeline objects
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
		    next unless $arg->{key} eq 'in' and defined $arg->{type} and $arg->{type} eq $self->itype;
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

    my $CONFIGFILE = $self->dir. '/config.xml';
    my $LOGFILE = $self->dir. '/log.xml';

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
sub step ($$) {
    my ($self) = shift;
    my $id = shift;
    return $self->{config}->{tool}->{$id};
#    print Dumper $id;
#    print Dumper $self->step(shift); 
    #shift->step(shift);
}

sub each_next ($) {
    map { $_->{id} } grep { $_->{id} } @{shift->{next}};
}

sub each_step ($) {
    @{shift->{steps}};
}

sub next_step {
    my ($self) = @_;

    # check for the log here to restart execution half way through

    # at this stage, only one starting step
    # find the first one: not referenced by any other steps in the pipeline

    for my $id (sort keys %{$self->{config}->{tool}}) {
	
    }    
}

sub time {
    my ($self) = @_;
    my $date = `date`;
    chomp $date;
    return $date;
}

sub run {
    my ($self) = @_;

    croak "Need an output directory" unless $self->dir;

    ###
    # check for input file and warn if not  found

    chdir $self->{dir};

    # determine where the execution of the pipeline was interrupted
    my @steps;
    if (-e $self->dir. "/log.xml") {
	$self->{log} = XMLin('log.xml', KeyAttr => {tool => 'id'});	
	#print Dumper $self->{log}, "----------------------------------";
	for my $step_id (keys %{$self->{log}}) {
	    push @steps, $step_id if not defined $self->{log}->{$step_id}->{end_time};
	}

    } else { # or start from the beginning
	@steps = $self->each_next;	
    }
#    print Dumper \@steps;
#    exit;
    while (my $step_id = shift @steps) {
	$self->{log}->{$step_id}->{start_time} = $self->time;
	my $step = $self->step($step_id);	
	print $step->id, "\t", $step->render, "\n";

	foreach my $arg (@{$step->{arg}}) {
	    next unless $arg->{key} eq 'in';
	    next unless $arg->{type} =~ /file|dir/ ;
	    croak "Can not read input at [". $arg->{value}. "]" unless -e $arg->{value};
	}

#	print Dumper $step;exit;	exit;
	$self->{log}->{$step_id}->{action} = $step->render;
	push @steps, $step->each_next;
	my $command = $step->render;
	`$command`;
	$self->{log}->{$step_id}->{end_time} = $self->time;
    }
}


#-----------------------------------------------------------------
# Render a tool into a command line string
#-----------------------------------------------------------------

sub render {
    my ($self, $tool) = @_;

    $tool ||= $self;
#    print "\n"; print Dumper $tool; print "\n";

    my $str;
    $str .=  $tool->{name};
    my $endstr = '';
    foreach my $arg (@{$tool->{arg}}) {

	if (defined $arg->{type} and $arg->{type} eq 'unnamed') {
	    $str .= ' "'. $arg->{value}. '"';
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

    return $str. $endstr;
}

sub stringify {
    my ($self) = @_;

    # add checks for duplicated ids

    # add checks for next pointers that lead nowhere

    my @steps = $self->each_next;
    my $outputs; #hashref for storing input and output filenames 
    while (my $step_id = shift @steps) {
	my $step = $self->step($step_id);
	print $step->id, "\n\t", $step->render, " # ";
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
		    if $prev_step_id ne $step->id;
	    }
	    # test for steps not refencesed by other steps (missing next tag)
	}
	print "\n";
    }
    #print "\n"; print Dumper $outputs;
}

=head2 

pipeline.pl  -config pipelines/string_manipulation.xml -graph  > /tmp/p.dot; dot -Tpng /tmp/p.dot| display


=cut

sub graphviz {
    my $self = shift;
    my $function = shift;

    require GraphViz;
    my $g= GraphViz->new;

    my $end;
    $g->add_node($self->id, label => $self->id. " : ". $self->render );
    map {  $g->add_edge('s0' => $_) }  $self->each_next;
    foreach my $step ($self->each_step) {
	$g->add_node($step->id, label => $step->id. " : ". $step->name );
	if ($step->each_next) {
	    map {  $g->add_edge($step->id => $_, label => $step->render) }  $step->each_next;
	} else {
	    $end++;
	    $g->add_node($end, label => ' ');
	    $g->add_edge($step->id => $end, label => $step->render)
	}

    }
    return $g->as_dot;

}

1;
__END__


#-----------------------------------------------------------------
# only for debugging
#-----------------------------------------------------------------
