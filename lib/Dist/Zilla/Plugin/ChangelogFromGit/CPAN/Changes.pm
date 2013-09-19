package Dist::Zilla::Plugin::ChangelogFromGit::CPAN::Changes;

# ABSTRACT: Format Changelogs using CPAN::Changes

use Moose;
use CPAN::Changes;
use CPAN::Changes::Release;

extends 'Dist::Zilla::Plugin::ChangelogFromGit';

=attr group_by_author

Whether to group commit messages by their author. This is the only way previous
versions did it. Defaults to no, and [ Anne Author ] is appended to the commit
message.

=cut
has group_by_author => ( is => 'ro', isa => 'Bool', default => 0);

=attr show_author_email

Author email is probably just noise for most people, but turn this on if you
want to show it [ Anne Author <anne@author.com> ]

=cut
has show_author_email => ( is => 'ro', isa => 'Bool', default => 0);

=attr show_author

Whether to show authors at all. Enabled by default. Turning this off also
turns off grouping by author and author emails.

=cut
has show_author => ( is => 'ro', isa => 'Bool', default => 1);

=attr transform_version_tag

Transform a git version tag to one compliant with L<CPAN::Changes::Spec> using
C<tag_regexp>. Use this if your git tag doesn't follow the standard.

Defaults to off.

=cut

has transform_version_tag => (
    is      => 'ro',
    isa     => 'Bool',
    default => 0,
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

sub render_changelog {
    my ($self) = @_;

    my $cpan_changes = CPAN::Changes->new( preamble => 'Changelog for ' . $self->zilla->name, );
    my $tag_re = qr/$self->{tag_regexp}/;

    foreach my $release ( reverse $self->all_releases ) {
        next if $release->has_no_changes;    # no empties

        my $version = $release->version;
        if ($version eq 'HEAD') {
            if ($self->_git_tag) {
                $version = $self->_git_tag->tag;
            } else {
                $version = $self->zilla->version;
            }
        }

        if ($self->transform_version_tag) {
            $version =~ $tag_re;
            if (!$1) {
                die sprintf 'Failed to get a match from tag_regexp: [%s] vs [%s]',
                $version, $tag_re;
            }
            $version = $1;
        }

        my $cpan_release = CPAN::Changes::Release->new(
            version => $version,
            date    => $release->date,
        );

        foreach my $change ( @{ $release->changes } ) {
            next if $change->description =~ /^\s+$/; # does git allow empty messages?

            my $desc = $change->description;
            chomp $desc;

            if ($self->show_author) {
                my $author = $change->author_name;

                if ($self->show_author_email) {
                    $author .= ' <' . $change->author_email . '>';
                }

                if ($self->group_by_author) {
                    my $group = $author;
                    $cpan_release->add_changes( { group => $group }, $desc );
                } else {
                    $cpan_release->add_changes( $desc . " [$author]" );
                }
            } else {
                $cpan_release->add_changes( $desc );
            }
        }

        $cpan_changes->add_release($cpan_release);
    }

    return $cpan_changes->serialize;
}

__PACKAGE__->meta->make_immutable;

1;

=head1 SYNOPSIS

 [ChangelogFromGit::CPAN::Changes]
 ; All options from [ChangelogFromGit] plus
 group_by_author       = 1 ; default 0
 show_author_email     = 1 ; default 0
 show_author           = 0 ; default 1
 transform_version_tag = 1 ; default 0

=head1 SEE ALSO

L<Dist::Zilla::Plugin::ChangelogFromGit::Debian> which was used as a template for this
