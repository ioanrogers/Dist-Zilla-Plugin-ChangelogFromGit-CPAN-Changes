use Test::Roo;
use Test::DZil;
use Test::CPAN::Changes;
use Archive::Tar;
use File::chdir;
use Dist::Zilla::File::InMemory;

has test_repo => (is => 'lazy');
has tzil      => (is => 'lazy', clearer => 1);
has tzil_ini  => (is => 'rw');

sub _build_tzil {
    my $self = shift;
    my $tzil = Builder->from_config(
        {dist_root => $self->test_repo},
        {add_files => $self->tzil_ini},
    );
    $tzil->build;
    return $tzil;
}

sub _set_tzil_ini_opts {
    my $self = shift;

    my @opts = ('GatherDir');
    if (scalar @_ == 0) {
        push @opts, 'ChangelogFromGit::CPAN::Changes';
    } else {
        @opts = (@opts, @_);
    }

    $self->tzil_ini({'source/dist.ini' => simple_ini(@opts)});
}

sub _build_test_repo {
    local $CWD = 't';
    diag 'Extracting test repo';
    Archive::Tar->extract_archive('test_repo.tar.gz');
    return Path::Class::Dir->new('t/test_repo');
}

after teardown  => sub { shift->test_repo->rmtree };
after each_test => sub { shift->clear_tzil };

sub test_changes {
    my ($self, $expected_name) = @_;

    my $changes_file = $self->tzil->tempdir->file('build/Changes');
    changes_file_ok $changes_file;

    my $expected_file    = Path::Class::File->new("t/changes/$expected_name");
    my @expected_changes = $expected_file->slurp;
    my @got_changes      = $changes_file->slurp;

    # everything should match except the date
    foreach (my $i = 0 ; $i < scalar @expected_changes ; $i++) {
        if ($expected_changes[$i] =~ /^\d+\.\d{3}/) {
            like $got_changes[$i],
              qr/^\d+\.\d{3} \d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}$/,
              'Matched line';
        } else {
            is $expected_changes[$i], $got_changes[$i], 'Matched line';
        }
    }
}

test v1_defaults => sub {
    my $self = shift;
    $self->_set_tzil_ini_opts;
    $self->test_changes('v1_defaults');
};

test v1_no_author => sub {
    my $self = shift;
    $self->_set_tzil_ini_opts([
            'ChangelogFromGit::CPAN::Changes' => {
                show_author => 0,
            }
        ],
    );

    $self->test_changes('v1_no_author');
};

test v1_email => sub {
    my $self = shift;
    $self->_set_tzil_ini_opts([
            'ChangelogFromGit::CPAN::Changes' => {
                show_author_email => 1,
            }
        ],
    );

    $self->test_changes('v1_email');
};

test v1_group_author => sub {
    my $self = shift;
    $self->_set_tzil_ini_opts([
            'ChangelogFromGit::CPAN::Changes' => {
                group_by_author => 1,
            }
        ],
    );

    $self->test_changes('v1_group_author');
};

test v1_group_author_email => sub {
    my $self = shift;
    $self->_set_tzil_ini_opts([
            'ChangelogFromGit::CPAN::Changes' => {
                group_by_author   => 1,
                show_author_email => 1,
            }
        ],
    );

    $self->test_changes('v1_group_author_email');
};

run_me;
done_testing;
