package probes::base;

=head1 NAME

probes::base - Base Class for implementing SmokePing Probes

=head1 OVERVIEW
 
For the time being, please use the probes::FPing for
inspiration when implementing your own probes.

=head1 AUTHOR

Tobias Oetiker <tobi@oetiker.ch>

=cut

use vars qw($VERSION);
use Carp;
use lib qw(..);
use Smokeping;

$VERSION = 1.0;

use strict;

sub new($$)
{
    my $this   = shift;
    my $class   = ref($this) || $this;
    my $self = { properties => shift, cfg => shift, 
    targets => {}, rtts => {}, addrlookup => {}};
    bless $self, $class;
    return $self;
}

sub add($$)
{
    my $self = shift;
    my $tree = shift;
    
    $self->{targets}{$tree} = shift;
}

sub ping($)
{
    croak "this must be overridden by the subclass";
}

sub round ($) {
    return sprintf "%.0f", $_[0];
}

sub ProbeDesc ($) {
    return "Probe which does not overrivd the ProbeDesc methode";
}    

sub rrdupdate_string($$)
{   my $self = shift;
    my $tree = shift;
#    print "$tree -> ", join ",", @{$self->{rtts}{$tree}};print "\n";    
    # skip invalid addresses
    my $pings = $self->{cfg}{Database}{pings}; 
    return join ":", map {"U"} 1..($pings+3) unless defined $self->{rtts}{$tree};
    my $entries = @{$self->{rtts}{$tree}};
    my @times = @{$self->{rtts}{$tree}};
    my $loss = $pings - $entries;
    my $median = $times[int($entries/2)] || 'U';
    splice @times, round($pings/2),0,map {'U'} 1..$loss;
    my $age;
    if ( -f $self->{targets}{$tree}.".adr" ) {
      $age =  time - (stat($self->{targets}{$tree}.".adr"))[9];
    } else {
      $age = 'U';
    }
    if ( $entries == 0 ){
      $age = 'U';
      $loss = 'U';
      if ( -f $self->{targets}{$tree}.".adr"
	   and not -f $self->{targets}{$tree}.".snmp" ){
	unlink $self->{targets}{$tree}.".adr";
      }
    } ;
    return "${age}:${loss}:${median}:".(join ":", @times);
}

sub addresses($)
{
    my $self = shift;
    my $addresses = [];
    $self->{addrlookup} = {};
    foreach my $tree (keys %{$self->{targets}}){
        my $target = $self->{targets}{$tree};
        if ($target =~ m|/|) {
	   if ( open D, "<$target.adr" ) {
	       my $ip;
	       chomp($ip = <D>);
	       close D;
	       
	       if ( open D, "<$target.snmp" ) {
		   my $snmp = <D>;
		   chomp($snmp);
		   if ($snmp ne Smokeping::snmpget_ident $ip) {
		       # something fishy snmp properties do not match, skip this address
		       next;
		   }
                   close D;
	       }
	       $target = $ip;
	   } else {
	       # can't read address file skip
	       next;
	   }
	}
        $self->{addrlookup}{$target} = () 
                unless defined $self->{addrlookup}{$target};
        push @{$self->{addrlookup}{$target}}, $tree;
	push @{$addresses}, $target;
    };    
    return $addresses;
}


1;
