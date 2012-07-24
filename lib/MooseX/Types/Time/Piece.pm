package MooseX::Types::Time::Piece;

use strict;
use warnings;
use namespace::autoclean;

our $VERSION = '0.02';

use Carp 'confess';
use Time::Piece ();
use Time::Seconds ();
use Try::Tiny;

use MooseX::Types -declare => [qw( Time Duration )];
use MooseX::Types::Moose qw( ArrayRef Int Str );

class_type 'Time::Piece';
class_type 'Time::Seconds';

subtype Time,     as 'Time::Piece';
subtype Duration, as 'Time::Seconds';

my $DEFAULT_FORMAT = '%a, %d %b %Y %H:%M:%S %Z';
my $ISO_FORMAT = '%Y-%m-%dT%H:%M:%S';

for my $type ( 'Time::Piece', Time )
{
    coerce $type,
        from Int, via
        {
            Time::Piece->new($_)
        },
        from Str, via
        {
            my $time = $_;
            try
              { $time = Time::Piece->strptime($time, $ISO_FORMAT) }
            catch
              # error message from strptime on its own is inadequate
              { confess "Error parsing time '$time' with format '$ISO_FORMAT'" };
            $time;
        },
        from ArrayRef, via
        {
            my ( $time, $format ) = @$_;
            $format ||= $DEFAULT_FORMAT; # if only 1 arg
            ( defined $time ) || confess "Time is undefined";
            try
              { $time = Time::Piece->strptime(@$_) }
            catch
              { confess "Error parsing time '$time' with format '$format'" };
            $time;
        };
}

for my $type ( 'Time::Seconds', Duration )
{
    coerce $type,
        from Int, via { Time::Seconds->new($_) };
}

1;

__END__

=head1 NAME

MooseX::Types::Time::Piece - Time::Piece type and coercions for Moose

=head1 SYNOPSIS

    package Foo;

    use Moose;
    use MooseX::Types::Time::Piece qw( Time Duration );

    has 'time' => (
        is      => 'ro',
        isa     => Time,
        coerce  => 1,
    );

    has 'duration' => (
        is      => 'ro',
        isa     => Duration,
        coerce  => 1,
    );

    # ...

    my $f = Foo->new(
        datetime => '2012-12-31T23:59:59',
        duration => Time::Seconds::ONE_DAY * 2,
    );

=head1 DESCRIPTION

This module provides L<Moose> type constraints and coercions for using
L<Time::Piece> objects as Moose attributes.

=head1 EXPORTS

The following type constants provided by L<MooseX::Types> must be explicitly
imported. The full class name may also be used (as strings with quotes) without
importing the constant declarations.

=over

=item Time

A class type for L<Time::Piece>.

=over

=item coerce from C<Int>

The Int value is interpreted as epoch seconds as provided by the
L<time() function|perlfunc/time>.

=item coerce from C<Str>

Parses strings in ISO 8601 format, e.g. C<'2012-12-31T23:59:59'>.
See also L<Time::Piece/YYYY-MM-DDThh:mm:ss>.

=item coerce from C<ArrayRef>

The ArrayRef should contain a time string and a format string as accepted by
L<strptime()|Time::Piece/"Date Parsing">.

=back

An exception is thrown if the time does not match the format, or
the time or format is invalid.

=item Duration

A class type for L<Time::Seconds>

=over

=item coerce from C<Int>

The integer value will be interpreted as the number of C<seconds>.

=back

=back

=head1 SEE ALSO

L<Time::Piece>, L<Moose::Util::TypeConstraints>, L<MooseX::Types>

=head1 AUTHOR

Steven Lee, C<< <stevenl at cpan.org> >>

=head1 LICENSE AND COPYRIGHT

Copyright E<copy> 2012 Steven Lee. All rights reserved.

This program is free software; you can redistribute it and/or modify it
under the same terms as Perl itself.

=cut
