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

sub render_changelog {
    my ($self) = @_;

    my $cpan_changes = CPAN::Changes->new( preamble => 'Changelog for ' . $self->zilla->name, );

    foreach my $release ( reverse $self->all_releases ) {
        next if $release->has_no_changes;    # no empties

        my $version = $release->version;
        if ( $version eq 'HEAD' ) {
            $version = $self->zilla->version;
        }

        my $cpan_release = CPAN::Changes::Release->new(
            version => $version,
            date    => $release->date,
        );

        foreach my $change ( @{ $release->changes } ) {
            next if $change->description =~ /^\s+$/; # does git allow empty messages?
            
            my $author = $change->author_name;
    
            if ($self->show_author_email) {
                $author .= ' <' . $change->author_email . '>';
            }
            
            my $desc = $change->description;
            chomp $desc;
            
            if ($self->group_by_author) {
                my $group = $author;
                $cpan_release->add_changes( { group => $group }, $desc );
            } else {
                $cpan_release->add_changes( $desc . " [$author]" );
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
 group_by_author = 1 ; default 0
 show_author_email = 1 ; default 0

=head1 SEE ALSO

L<Dist::Zilla::Plugin::ChangelogFromGit::Debian> which was used as a template for this

