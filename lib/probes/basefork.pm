package probes::basefork;

my $DEFAULTFORKS = 5;

=head1 NAME

probes::basefork - Yet Another Base Class for implementing SmokePing Probes

=head1 OVERVIEW

Like probes::basevars, but supports the probe-specific property `forks'
to determine how many processes should be run concurrently.

=head1 SYNOPSYS

 *** Probes ***

 + MyForkingProbe
 # run this many concurrent processes
 forks = 10 

 + MyOtherForkingProbe
 # we don't want any concurrent processes at all for some reason.
 forks = 1 

=head1 DESCRIPTION

Not all pinger programs support testing multiple hosts in a single go like
fping(1). If the measurement takes long enough, there may be not enough time 
perform all the tests in the time available. For example, if the test takes
30 seconds, measuring ten hosts already fills up the SmokePing default 
five minute step.

Thus, it may be necessary to do some of the tests concurrently. This module
defines the B<ping> method that forks the requested number of concurrent 
processes and calls the B<pingone> method that derived classes must provide.

The B<pingone> method is called with one argument: a hash containing
the target that is to be measured. The contents of the hash are
described in I<probes::basevars>(3pm).

The number of concurrent processes is determined by the probe-specific 
variable `forks' and is 5 by default. If there are more 
targets than this value, another round of forks is done after the first 
processes are finished. This continues until all the targets have been
tested.

=head1 AUTHOR

Niko Tyni E<lt>ntyni@iki.fiE<gt>

=head1 BUGS

Doesn't signal failures in child processes, partly because SmokePing 
hasn't any logging features after daemonization.

=head1 SEE ALSO

probes::basevars(3pm), probes::EchoPing(3pm)

=cut

use strict;
use base qw(probes::basevars);
use Symbol;
use Carp;
use IO::Select;

sub ping_one {
	croak "ping_one: this must be overridden by the subclass";
}

sub ping {
	my $self = shift;
	my $forks = $self->{properties}{forks};
	$forks = $DEFAULTFORKS unless defined $forks;
	$forks = $DEFAULTFORKS if $forks !~ /^\d+$/ or $forks < 1;

	my @targets = @{$self->targets};

	while (@targets) {
		my %targetlookup;
		my $s = IO::Select->new();
		for (1..$forks) {
			last unless @targets;
			my $t = pop @targets;
			my $pid;
			my $handle = gensym;
			do {
				$pid = open($handle, "-|");
				my $sleep_count = 0;

				unless (defined $pid) {
					carp("cannot fork: $!");
					croak("bailing out") 
						if $sleep_count++ > 6;
					sleep 10;
				}
			} until defined $pid;
			if ($pid) { #parent
				$s->add($handle);
				$targetlookup{$handle} = $t;
			} else { #child
				my @times = $self->pingone($t);
				print join(" ", @times), "\n";
				exit;
			}
		}
		my $step = $self->{cfg}{Database}{step};
		my $starttime = time();
		while ($s->handles and time() - $starttime < $step) {
			if( $s->can('has_exception') ) {
				$s->remove($s->has_exception(0)); # should we carp?
			} elsif( $s->can('has_error') ) {
				$s->remove($s->has_error(0));
			} else {
				croak 'IO::Select neither knows has_exception() nor has_error()';
 			};
			for my $ready ($s->can_read($step / 2)) {
				$s->remove($ready);
				my $response = <$ready>;
				close $ready;

				chomp $response;
				my @times = split(/ /, $response);
				my $target = $targetlookup{$ready};
				my $tree = $target->{tree};
				$self->{rtts}{$tree} = \@times;
			}
		}
	}
}

sub ProbeDesc {
	return "Probe that can fork and doesn't override the ProbeDesc method";
}

1;
