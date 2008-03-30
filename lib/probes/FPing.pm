package probes::FPing;

=head1 NAME

probes::FPing - FPing Probe for SmokePing

=head1 SYNOPSIS

 *** Probes ***
 + FPing
 binary = /usr/sepp/bin/fping

=head1 DESCRIPTION

Integrates FPing as a probe into smokeping. The variable B<binary> must
point to your copy of the FPing program. If it is not installed on
your system yet, you can get it from http://www.fping.com/.

=head1 AUTHOR

Tobias Oetiker <tobi@oetiker.ch>

=cut

use strict;
use base qw(probes::base);
use IPC::Open3;
use Symbol;
use Carp;

sub new($$$)
{
    my $proto = shift;
    my $class = ref($proto) || $proto;
    my $self = $class->SUPER::new(@_);

    croak "ERROR: FPing 'binary' not defined in FPing probe definition"
        unless defined $self->{properties}{binary};

    croak "ERROR: FPing 'binary' does not point to an executable"
        unless -f $self->{properties}{binary} and -x $self->{properties}{binary};
    
    $_ = `$self->{properties}{binary} -C 1 localhost 2>&1`;
    if (m/bytes, ([0-9.]+)\sms\s+.*\n.*\n.*:\s+([0-9.]+)/){
        $self->{pingfactor} = 1000 * $2/$1;
        print "### fping seems to report in ", $1/$2, " miliseconds\n" unless $ENV{SERVER_SOFTWARE};
    } else {
        $self->{pingfactor} = 1000; # Gives us a good-guess default
        print "### assuming you are using an fping copy reporting in miliseconds\n" unless $ENV{SERVER_SOFTWARE};
    };
    return $self;
}

sub ProbeDesc($){
    return "ICMP Echo Pings";
}

sub ping ($){
    my $self = shift;
    # do NOT call superclass ... the ping method MUST be overwriten
    my %upd;
    my $inh = gensym;
    my $outh = gensym;
    my $errh = gensym;
    # pinging nothing is pointless
    return unless @{$self->addresses};
    my $pid = open3($inh,$outh,$errh, 
                    $self->{properties}{binary}, 
                    '-C', $self->{cfg}{Database}{pings}, '-q',
                    @{$self->addresses});
    $self->{rtts}={};
    while (<$errh>){
        chomp;
        my @times = split /\s+/;
        my $ip = shift @times;
        next unless ':' eq shift @times; #drop the colon

        @times = map {sprintf "%.10e", $_ / $self->{pingfactor}} sort {$a <=> $b} grep {$_ ne "-"} @times;
        map { $self->{rtts}{$_} = [@times] } @{$self->{addrlookup}{$ip}} ;
    }
    waitpid $pid,0;
    close $inh;
    close $outh;
    close $errh;
}

1;
