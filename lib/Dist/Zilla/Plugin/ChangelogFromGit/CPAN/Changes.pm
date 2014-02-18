package Dist::Zilla::Plugin::ChangelogFromGit::CPAN::Changes;

# ABSTRACT: Generate valid CPAN::Changes Changelogs from git

use v5.10.2;
use Moose;
use Moose::Util::TypeConstraints;
use CPAN::Changes::Release;
use CPAN::Changes;
use DateTime;
use Git::Wrapper;

with qw/Dist::Zilla::Role::FileGatherer Dist::Zilla::Role::Git::Repo/;

subtype 'CoercedRegexpRef' => as 'RegexpRef';

coerce 'CoercedRegexpRef' => from 'Str' => via {qr/$_[0]/};

=attr group_by_author

Whether to group commit messages by their author. This is the only way previous
versions did it. Defaults to no, and [ Anne Author ] is appended to the commit
message.

Defaults to off.

=cut

has group_by_author => ( is => 'ro', isa => 'Bool', default => 0);

=attr show_author_email

Author email is probably just noise for most people, but turn this on if you
want to show it [ Anne Author <anne@author.com> ]

Defaults to off.

=cut

has show_author_email => ( is => 'ro', isa => 'Bool', default => 0);

=attr show_author

Whether to show authors at all. Turning this off also
turns off grouping by author and author emails.

Defaults to on.

=cut

has show_author => ( is => 'ro', isa => 'Bool', default => 1);

=attr C<tag_regexp>

A regexp string which will be used to match git tags to find releases. If your
release tags are not compliant with L<CPAN::Changes::Spec>, you can use a
capture group. It will be used as the version in place of the full tag name.

Defaults to '^\d+\.\d+$'

=cut

has tag_regexp => (
    is      => 'ro',
    isa     => 'CoercedRegexpRef',
    coerce  => 1,
    default => sub {'qr/^(\d+\.\d+)$/'},
);

=attr C<file_name>

The name of the changelog file.

Defaults to 'Changes'.

=cut

has file_name => (is => 'ro', isa => 'Str', default => 'Changes');

=attr C<preamble>

Block of text at the beginning of the changelog.

Defaults to 'Changelog for $dist_name'

=cut

has preamble => (
    is      => 'ro',
    lazy    => 1,
    isa     => 'Str',
    default => sub { 'Changelog for ' . $_[0]->zilla->name },
);

has _changes => (is => 'ro', lazy_build => 1, isa => 'CPAN::Changes');
has _last_release => (is => 'rw', isa => 'Str');
has _tags => (is => 'rw', isa => 'ArrayRef');

has _git => (
    is      => 'ro',
    lazy    => 1,
    isa     => 'Git::Wrapper',
    default => sub { Git::Wrapper->new('.') },
);

has _git_tag => (
    is      => 'ro',
    lazy    => 1,
    isa     => 'Maybe[Dist::Zilla::Plugin::Git::Tag]',
    default => sub {
        foreach (@{shift->zilla->plugins}) {
            return $_ if ref eq 'Dist::Zilla::Plugin::Git::Tag';
        }
        return;
    },
);

sub _build__changes {
    my $self = shift;

    my $changes;
    my @args = (preamble => $self->preamble);

    if (-f $self->file_name) {
        $changes = CPAN::Changes->load($self->file_name, @args);
    } else {

        # TODO maybe. If Changelog is new and this is the first release,
        # first entry should just be "First release"
        $changes = CPAN::Changes->new(@args);
    }

    return $changes;
}

sub gather_files {
    my $self = shift;

    $self->_get_tags;
    $self->_get_changes;

    my $content = return $self->_changes->serialize;

    my $file = Dist::Zilla::File::InMemory->new({
        content => $content,
        name    => $self->file_name,
    });

    $self->add_file($file);
}

sub _get_tags {
    my $self = shift;

    my $last_tag;
    my @tags;
    foreach my $tag ($self->_git->RUN('tag')) {
        my $release = $self->_changes->release($tag);
        if ($release) {
            $last_tag = $tag;
            next;
        }
        push @tags, $tag;
    }

    push @tags, 'HEAD';

    $self->_tags(\@tags);
    $self->_last_release($last_tag) if $last_tag;
    return;
}

sub _git_log {
    my ($self, $revs) = @_;

    # easier to read than just writing the string directly
    my $format = {
        author  => '%aN',
        date    => '%at',
        email   => '<%aE>',
        subject => '%s',
    };

    # commit has to come first
    my $format_str = 'commit:%H%n';
    while (my ($attr, $esc) = each $format) {
        $format_str .= "$attr:$esc%n";
    }
    $format_str .= '<END COMMIT>%n';

    my @out = $self->_git->RUN(
        log => {
            no_color      => 1,
            'use-mailmap' => 1,
            format        => $format_str,
        },
        $revs
    );

    my $commits;
    my $cur_commit;
    while (my $line = shift @out) {
        if ($line eq '<END COMMIT>') {
            $cur_commit = undef;
            shift @out;
            next;
        }

        if ($line =~ /^commit:(\w+)$/) {
            $cur_commit = $1;
            $commits->{$cur_commit}->{id} = $cur_commit;
            next;
        } elsif (!$cur_commit) {
            die 'Failed to parse commit id';
        }

        if ($line =~ /^(\w+):(.+)$/) {
            die 'WTF? Not currently in a commit?' if !$cur_commit;
            $commits->{$cur_commit}->{$1} = $2;
            next;
        }
    }

    return [sort { $b->{date} <=> $a->{date} } values $commits];
}

sub _get_release_date {
    my ($self, $tag) = @_;

    # TODO configurable date formats
    if ($tag eq 'HEAD') {
        return DateTime->now->iso8601;
    }

    # XXX 'max-count' => '1' doesn't work with Git::Wrapper, it becomes
    # just '--max-count'. File a bug!
    my @out = $self->_git->RUN(log => {format => '%ct', 1 => 1}, $tag);
    my $dt = DateTime->from_epoch(epoch => $out[0]);
    return $dt->iso8601;
}

sub _get_changes {
    my $self     = shift;
    my $last_tag = $self->_last_release;

    # TODO sorting tags
    foreach my $tag (@{$self->_tags}) {
        my $rev = $last_tag ? "$last_tag..$tag" : $tag;
        $last_tag = $tag;

        $self->logger->log_debug("Getting commits for $rev");
        my $commits = $self->_git_log($rev);

        # get release version
        my $version = $tag eq 'HEAD' ? $self->zilla->version : $tag;
        $self->logger->log_debug("V=$version T=$tag");
        $version =~ $self->tag_regexp;
        if (!$1) {
            die sprintf 'Failed to get a match from tag_regexp: [%s] vs [%s]',
              $version, $self->tag_regexp;
        }
        $version = $1;

        my $release = CPAN::Changes::Release->new(
            version => $version,
            date    => $self->_get_release_date($tag),
        );

        my %seen;
        foreach my $commit (@$commits) {

            # TODO strip extra spaces and newlines
            # TODO convert * lists

            # weed out dupes
            chomp $commit->{subject};
            next if exists $seen{$commit->{subject}};
            $seen{$commit->{subject}} = 1;

            # ignore the auto-commits
            next if $commit->{subject} eq $tag;
            next if $commit->{subject} =~ /^Release /;
            next if $commit->{subject} =~ /^Merge (pull|branch)/;

            if ($self->show_author) {
                my $author = $commit->{author};

                if ($self->show_author_email) {
                    $author .= ' ' . $commit->{email};
                }

                if ($self->group_by_author) {
                    my $group = $author;
                    $release->add_changes({group => $group},
                        $commit->{subject});
                } else {
                    $release->add_changes($commit->{subject} . " [$author]");
                }
            } else {
                $release->add_changes($commit->{subject});
            }
        }

        $self->_changes->add_release($release);
    }

    return;
}

__PACKAGE__->meta->make_immutable;

1;

=head1 SYNOPSIS

 [ChangelogFromGit::CPAN::Changes]
 ; All options from [ChangelogFromGit] plus
 group_by_author       = 1 ; default 0
 show_author_email     = 1 ; default 0
 show_author           = 0 ; default 1
