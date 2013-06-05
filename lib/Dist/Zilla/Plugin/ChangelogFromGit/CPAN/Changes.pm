package Dist::Zilla::Plugin::ChangelogFromGit::CPAN::Changes;
{
  $Dist::Zilla::Plugin::ChangelogFromGit::CPAN::Changes::VERSION = '0.0.3';
}

# ABSTRACT: Format Changelogs using CPAN::Changes

use Moose;
use CPAN::Changes;
use CPAN::Changes::Release;

extends 'Dist::Zilla::Plugin::ChangelogFromGit';

has group_by_author => ( is => 'ro', isa => 'Bool', default => 0);

has show_author_email => ( is => 'ro', isa => 'Bool', default => 0);

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

__END__

=pod

=head1 NAME

Dist::Zilla::Plugin::ChangelogFromGit::CPAN::Changes - Format Changelogs using CPAN::Changes

=head1 VERSION

version 0.0.3

=head1 SYNOPSIS

 [ChangelogFromGit::CPAN::Changes]
 ; All options from [ChangelogFromGit] plus
 group_by_author = 1 ; default 0
 show_author_email = 1 ; default 0

=head1 ATTRIBUTES

=head2 group_by_author

Whether to group commit messages by their author. This is the only way previous
versions did it. Defaults to no, and [ Anne Author ] is appended to the commit
message.

=head2 show_author_email

Author email is probably just noise for most people, but turn this on if you
want to show it [ Anne Author <anne@author.com> ]

=head1 SEE ALSO

L<Dist::Zilla::Plugin::ChangelogFromGit::Debian> which was used as a template for this

=head1 BUGS AND LIMITATIONS

You can make new bug reports, and view existing ones, through the
web interface at L<https://github.com/ioanrogers/Dist-Zilla-Plugin-ChangelogFromGit-CPAN-Changes/issues>.

=head1 SOURCE

The development version is on github at L<http://github.com/ioanrogers/Dist-Zilla-Plugin-ChangelogFromGit-CPAN-Changes>
and may be cloned from L<git://github.com/ioanrogers/Dist-Zilla-Plugin-ChangelogFromGit-CPAN-Changes.git>

=head1 AUTHOR

Ioan Rogers <ioanr@cpan.org>

=head1 COPYRIGHT AND LICENSE

This software is copyright (c) 2013 by Ioan Rogers.

This is free software; you can redistribute it and/or modify it under
the same terms as the Perl 5 programming language system itself.

=cut
