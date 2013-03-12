package Ukigumo::Agent::Manager;
use strict;
use warnings;
use utf8;
use Ukigumo::Client;
use Ukigumo::Client::VC::Git;
use Ukigumo::Client::Executor::Perl;

use Mouse;

has 'children' => ( is => 'rw', default => sub { +{ } } );
has 'work_dir' => ( is => 'rw', isa => 'Str', required => 1 );
has 'server_url' => ( is => 'rw', isa => 'Str', required => 1 );
has job_queue => (is => 'ro', default => sub { +[ ] });
has max_children => ( is => 'ro', default => 1 );

no Mouse;

sub count_children {
    my $self = shift;
    0+(keys %{$self->children});
}

sub push_job {
    my ($self, $job) = @_;
    push @{$self->{job_queue}}, $job;
}

sub pop_job {
    my ($self, $job) = @_;
    push @{$self->{job_queue}}, $job;
}

sub run_job {
    my ($self, $args) = @_;
    Carp::croak "Missing args" unless $args;

    my $pid = fork();
    if (!defined $pid) {
        die "Cannot fork: $!";
    }

    my $repository = $args->{repository} || die;
    my $branch     = $args->{branch} || die;

    if ($pid) {
        print "Spawned $pid\n";
        $self->{children}->{$pid} = AE::child($pid, sub {
            my ($pid, $status) = @_;
            print "[child exit] pid: $pid, status: $status\n";
            delete $self->{children}->{$pid};

            if ($self->count_children < $self->max_children && $self->count_children > 0) {
                $self->run_job($self->pop_job);
            }
        });
    } else {
        eval {
            my $vc = Ukigumo::Client::VC::Git->new(
                branch => $branch,
                repository => $repository,
            );
            my $client = Ukigumo::Client->new(
                workdir => $self->work_dir,
                vc => $vc,
                executor => Ukigumo::Client::Executor::Perl->new(),
                server_url => $self->server_url,
            );
            $client->run();
        };
        print "[child] error: $@\n" if $@;
        print "[child] finished to work\n";
        exit;
    }
}

sub register_job {
    my ($self, $params) = @_;

    $self->push_job($params);

    if ($self->count_children < $self->max_children) {
        # run job.
        $self->run_job($params);
    } else {
        $self->push_job($params);
    }
}

1;

