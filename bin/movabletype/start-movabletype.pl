#!/usr/local/bin/perl
use strict;
use warnings;
use POSIX qw(WIFEXITED WEXITSTATUS WIFSIGNALED WTERMSIG);

my @children;
my $terminating = 0;

sub spawn {
    my ( $name, @cmd ) = @_;
    my $pid = fork();

    die "Failed to fork $name: $!" unless defined $pid;

    if ( $pid == 0 ) {
        exec @cmd or die "Failed to exec $name: $!";
    }

    push @children, [ $pid, $name ];
    return $pid;
}

sub terminate_children {
    return if $terminating;
    $terminating = 1;

    for my $child (@children) {
        my ( $pid ) = @{$child};
        kill 'TERM', $pid if $pid > 0;
    }
}

$SIG{INT}  = \&terminate_children;
$SIG{TERM} = \&terminate_children;

spawn(
    'starman',
    '/usr/local/bin/starman',
    '--workers=4',
    '--max-requests=100',
    '--disable-keepalive',
    '--timeout=1800',
    '--listen', ':5001',
    '--pid=/tmp/mt-starman.pid',
    '--error-log=/var/log/movabletype/error.log',
    '/var/www/movabletype/mt.psgi'
);

spawn(
    'httpd',
    '/usr/local/apache2/bin/httpd',
    '-DFOREGROUND',
    '-f', '/usr/local/apache2/conf/httpd.conf'
);

my $exit_code = 0;

while (@children) {
    my $pid = wait();
    last if $pid < 0;

    my ($finished) = grep { $_->[0] == $pid } @children;
    @children = grep { $_->[0] != $pid } @children;

    if ($finished) {
        my $name = $finished->[1];

        if ( WIFEXITED($?) ) {
            $exit_code = WEXITSTATUS($?);
            warn "$name exited with status $exit_code\n";
        }
        elsif ( WIFSIGNALED($?) ) {
            my $signal = WTERMSIG($?);
            $exit_code = 128 + $signal;
            warn "$name terminated by signal $signal\n";
        }
    }

    terminate_children();
}

exit $exit_code;
