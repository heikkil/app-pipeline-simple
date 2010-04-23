#-----------------------------------------------------------------
# Pipeline
# Authors:Heikki Lehvasllaiho <heikki.lehvaslaiho@gmail.com>
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
    my %_allowed =
	(

         id             => 1,
         description    => 1,
         name           => 1,
	 args           => 1,
	 next_id        => 1,

	 input_name     => 1,
	 input_format   => 1,

	 config         => 1,
	 add            => 1,

	 dir            => 1,
	 run            => 1,
	 stringify      => 1,
	 );

    sub _accessible {
	my ($self, $attr) = @_;
	exists $_allowed{$attr};
    }
}

#-----------------------------------------------------------------
# Deal with 'set' and 'get' methods.
#-----------------------------------------------------------------
sub AUTOLOAD {
    my ($self, $value) = @_;
    my $ref_sub;
    if ($AUTOLOAD =~ /.*::(\w+)/ && $self->_accessible ("$1")) {

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
sub DESTROY {
}

#-----------------------------------------------------------------
# new
#-----------------------------------------------------------------
sub new {
    my ($class, @args) = @_;

    # create an object
    my $self = bless {}, ref ($class) || $class;

    # set default values
    $self->{compiled_operations} = {};

    # set all @args into this object with 'set' values
    my (%args) =
 (@args == 1 ? (value => $args[0]) : @args);
    foreach my $key (keys %args) {
        no strict 'refs';
        $self->$key ($args {$key});
    }

    $self->host ($ENV{'MRS_HOST'}) if $ENV{'MRS_HOST'};

    # done
    return $self;
}

#-----------------------------------------------------------------
#
#-----------------------------------------------------------------
sub config {
    my ($self, $config) = @_;
    if ($config) {
	$self->{config} = XMLin($config, KeyAttr => {tool => 'id'});

	# go through all steps once
	my $nexts;		# hashref for finding start point(s)
	for my $id (sort keys %{$self->{config}->{tool}}) {
	    my $step = $self->{config}->{tool}->{$id};

	    # bless all steps into Pipepeline objects
	    bless $step, ref($self);

	    # create the list of all steps to be used by each_step()
	    $step->id($id);
	    push @{$self->{steps}}, $step;

	    #turn a next hashref into an arrayref, (XML::Simple complication)
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
	foreach my $step ($self->each_step) {
	    push @{$self->{next}}, { id => $step->id}
	       unless $nexts->{$step->id}
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
	$self->{dir} = $dir;
    }
    $self->{dir};
}

#-----------------------------------------------------------------
#
#-----------------------------------------------------------------
sub step ($$) {
    shift->step(shift);
}

sub each_next ($) {
    @{shift->{next}};
}

sub each_step ($) {
    @{shift->{steps}};
}

sub next_step {
    my ($self) = @_;

    # check for the log here to restart execution half way through

    # at this stage, only one start step
    # find the first one: not referenced by any other steps in the pipeline

    for my $id (sort keys %{$self->{config}->{tool}}) {
	
    }    
}

sub run {
    my ($self) = @_;

    croak "Need an output directory" unless $self->{dir};


    while ( my $step = $self->next_step) {

    }

    #map {print "$_\n"} sort keys %{$self->{config}->{tool}};

    for my $id (sort keys %{$self->{config}->{tool}}) {
	print "$id\t";
	#    say "  ", Dumper $self->{config}->{tool}->{$id};
	print $self->config->{tool}->{$id}->{name};
	foreach my $arg (@{$self->{config}->{tool}->{$id}->{arg}}) {
	    #print Dumper $arg;
	    print " ", $arg->{key}, "=", ($arg->{value} || ''); 
	}
#	print "\n\t--> ",  $self->{config}->{tool}->{$id}->{next}->{id} || '', "\n" if defined $self->{config}->{tool}->{$id}->{next};
	print "\n";
    }
}


#-----------------------------------------------------------------
# Render a tool into a command line string
#-----------------------------------------------------------------

sub render {
    my ($self, $tool) = @_;

#    print "\n"; print Dumper $tool; print "\n";

    my $str;
    $str .=  $tool->{name};
    my $endstr;
    foreach my $arg (@{$tool->{arg}}) {

	if (defined $arg->{type} and $arg->{type} eq 'str') {
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
	    $str .= " ". $arg->{key}. "=". $arg->{value}; 
	} else {
	    $str .= " ". $arg->{key};
	}

    }

    return $str. $endstr;
}

sub stringify {
    my ($self) = shift;

    print "-" x 50, "\n";
    foreach my $step ($self->each_step) {
	print $step->id, "\t", $self->render($step), " # ";
	map { print "-->", $_->{id}, " " }
	    grep { $_->{id} }
	    $step->each_next;

	print "\n";
    }
    print "-" x 50, "\n";
}


1;
__END__


#-----------------------------------------------------------------
# only for debugging
#-----------------------------------------------------------------
