Whether to group commit messages by their author. This is the only way previous
versions did it. Defaults to no, and \[ Anne Author \] is appended to the commit
message.

Defaults to off.

Author email is probably just noise for most people, but turn this on if you
want to show it \[ Anne Author &lt;anne@author.com> \]

Defaults to off.

Whether to show authors at all. Turning this off also
turns off grouping by author and author emails.

Defaults to on.

A regexp string which will be used to match git tags to find releases. If your
release tags are not compliant with [CPAN::Changes::Spec](https://metacpan.org/pod/CPAN::Changes::Spec), you can use a
capture group. It will be used as the version in place of the full tag name.

Also takes `semantic`, which becomes `qr{^v?(\d+\.\d+\.\d+)$}`, and
`decimal`, which becomes `qr{^v?(\d+\.\d+)$}`.

Defaults to 'decimal'

The name of the changelog file.

Defaults to 'Changes'.

Block of text at the beginning of the changelog.

Defaults to 'Changelog for $dist\_name'

When true, the generated changelog will be copied into the root folder where it
can be committed (possiby automatically by [Dist::Zilla::Plugin::Git::Commit](https://metacpan.org/pod/Dist::Zilla::Plugin::Git::Commit))

Defaults to true.

When true, the generated changelog will be opened in an editor to allow manual
editing.

Defaults to false.

# SYNOPSIS

    [ChangelogFromGit::CPAN::Changes]
    ; All options from [ChangelogFromGit] plus
    group_by_author       = 1 ; default 0
    show_author_email     = 1 ; default 0
    show_author           = 0 ; default 1
    edit_changelog        = 1 ; default 0

# POD ERRORS

Hey! **The above document had some coding errors, which are explained below:**

- Around line 1:

    Unknown directive: =attr

- Around line 9:

    Unknown directive: =attr

- Around line 16:

    Unknown directive: =attr

- Around line 23:

    Unknown directive: =attr

- Around line 34:

    Unknown directive: =attr

- Around line 40:

    Unknown directive: =attr

- Around line 46:

    Unknown directive: =attr

- Around line 53:

    Unknown directive: =attr
