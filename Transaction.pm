package Transaction;

use strict;
use vars qw($VERSION @ISA @EXPORT @EXPORT_OK);

require Exporter;

@ISA = qw(Exporter AutoLoader);
#@EXPORT = qw();

$VERSION = '0.01';
$SIG{PIPE} = 'IGNORE';

my %errors = (
	1 => 'Username Invalid',
	2 => 'Incorrect password',
	3 => 'User not permitted from referring host',
	4 => 'Unknown trasaction',
	5 => 'User not permited to do transaction',
);

sub new {
	my ($self, %config) = @_;
	%config = map {uc $_=>$config{$_}} keys %config;
	return bless \%config, $self;
}

sub send {
	my ($self, $action, %args) = @_;

	my $trys = 0;
	delete $self->{_param} if exists $self->{_param};

	my $server;
	if (exists $self->{SSL} and $self->{SSL}) {
		use IO::Socket::SSL;
		$server = IO::Socket::SSL->new(
			PeerAddr => $self->{SERVER},
			PeerPort => $self->{PORT},
			Proto    => 'tcp',
			SSL_use_cert => 1,
			SSL_verify_mode => 0x01,
			SSL_passwd_cb => sub { return "testing" }
		) or die "unable to create socket: ", &IO::Socket::SSL::errstr, "\n";

	} else {
		#Open TCP port
		use IO::Socket;
		$server = IO::Socket::INET->new (
			PeerAddr => $self->{SERVER},	
			PeerPort	=> $self->{PORT},
			Type		=> SOCK_STREAM,
		) or die "Couldn't be a tcp server on port $self->{PORT} : $@\n";
	}
		
	print $server "ACTION=$action\n";
	print $server "USER=$self->{USER}\n";
	print $server "PASSWD=$self->{PASSWD}\n";
	print $server "$_=$args{$_}\n" foreach keys %args;
	
	shutdown $server, 1;
	
	$self->params($server, (exists $self->{SSL} and $self->{SSL}) ? '1' : 0);
	#print Dumper([$self]);
	shutdown $server, 2;
	#close $server or die $!;
	return $self;
}

sub _process_raw {
	my ($self, $raw) = @_;
	my ($key, $val) = split '=', $raw;
	return unless defined $key and defined $val;
	$val  =~ s/\r?\n$//;	
	if (exists $self->{_param}{$key}) {
		if (ref $self->{_param}{$key} eq 'ARRAY') {
			push @{$self->{_param}{$key}}, $val;
		} else {
			$self->{_param}{$key} = [$self->{_param}{$key}, $val]
		}	
	} else {
		$self->{_param}{$key} = $val;
	}
}

sub params {
	my ($self, $socket, $ssl) = @_;
	
	if ($ssl) {
		foreach ($socket->getlines) {
			$self->_process_raw($_);
		}
	} else {
	
		while (defined($_ = <$socket>) and not /^\n?\r$/) {
			$self->_process_raw($_);
		}
	}
	#print Dumper([$self->{_param}]);

	if (exists $self->{_param}{count}) {
		my %ret;
		for my $i (1 .. $self->{_param}{count}) {
			my %a;
			foreach my $key (grep /^$i\-/, $self->param()) {
				$key=~s/^$i\-//;
				$a{$key} = $self->param($&.$key); 

			}
			push @{$ret{$i}}, \%a
		}
		$ret{primary} = $self->{_param}{primary} if exists $self->{_param}{primary};
		$self->{_param} = \%ret;
	}	
}

sub param {
	my ($self, $param, $opr, $val) = @_;
	my $p = $self->{_param};
	
	if ($param and ref $p->{$param} eq 'ARRAY') {
		return $p->{$param};
	} elsif ($param and ref $p->{$param} eq 'HASH') {
		return $p->{$param};
	} elsif ($param) {
		return $p->{$param}
	} elsif ($opr and $opr eq '+') {
		$self->{_param}{$param} = $val;
	} else {
		if(wantarray()) {
			return keys %$p;
		}
	}
}

sub errstr {
	my $self = shift;
	return $errors{$self->param('err')};
}

1;

__END__

=head1 NAME

Transaction - Perl extension for Transactions

=head1 SYNOPSIS

	use Transaction;
	my $trn = new Transaction SERVER=>'localhost', PORT=>50001;
	my $ret = $trn->send('echotest', blah => 'foo');

	if ($ret->param('err') == 0) {
		print "$_=".$ret->param($_) foreach $ret->param();
	} else {
		die "Transaction err=". $ret->param('err');
	}
	
=head1 DESCRIPTION

Perl interface to send Transactions 

=head1 METHODS

=item B<new(...)>

Creates a new Transaction

=item B<param(...)>

=head1 AUTHOR

Kiel R. Stirling, kiel@comcen.com.au

=head1 SEE ALSO

perl(1).

=cut
