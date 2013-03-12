#!/usr/bin/env perl
use strict;
use warnings;
use utf8;
use 5.010000;
use autodie;
use FindBin;
use lib "$FindBin::Bin/../lib";

use Twiggy::Server;
use Plack::Builder;
use Ukigumo::Agent::Manager;
use Ukigumo::Agent;
use Getopt::Long;
use Pod::Usage;
use FIle::ShareDir qw(dist_dir);
use List::Util qw(first);
use Data::Thunk qw(lazy);
use Plack::App::File;

my $port = 1984;
my $host = '127.0.0.1';
GetOptions(
    'work_dir=s'   => \my $work_dir,
    'server_url=s' => \my $server_url,
    'h|host=i' => \$host,
    'p|port=i' => \$port,
);
$work_dir or pod2usage();
$server_url or pod2usage();

my $manager = Ukigumo::Agent::Manager->new(
    work_dir   => $work_dir,
    server_url => $server_url,
);
Ukigumo::Agent->register_manager($manager);

my $static_dir = first { -d $_ } (
    lazy { File::Spec->catfile(Ukigumo::Agent->base_dir, 'share/static') },
    lazy { File::ShareDir::dist_dir('Ukigumo-Agent', 'static') },
);

my $app = builder {
    enable 'AccessLog';

    mount '/static/' => Plack::App::File->new(
        {root => $static_dir}
    );
    mount '/' => Ukigumo::Agent->to_app();
};

my $twiggy = Twiggy::Server->new(
    host => $host,
    port => $port,
);
$twiggy->register_service($app);

print "http://${host}:${port}/\n";

AE::cv->recv;
__END__

=head1 NAME

ukigumo-agent.pl - CI agent server

=head1 SYNOPSIS

    % ukigumo-agent.pl --server_url=http://example.com/
        
        --server_url=http://example.com  ukigumo-server URL
        --work_dir=/tmp/                 working directory
        --host=127.0.0.1                 Bind host
        --port=80                        Bind port(Default: 1984)

=head1 DESCRIPTION

ukigumo-agent.pl is CI agent server, runs test cases.
