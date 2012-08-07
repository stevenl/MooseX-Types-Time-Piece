#!perl -T

package Foo;
{
    use Moose;
    use MooseX::Types::Time::Piece;

    has 'time_from_int' => (
        is  => 'rw',
        isa => 'Time::Piece',
        coerce => 1,
    );
    has 'time_from_str' => (
        is  => 'rw',
        isa => 'Time::Piece',
        coerce => 1,
    );
    has 'time_from_arrayref' => (
        is  => 'rw',
        isa => 'Time::Piece',
        coerce => 1,
    );

    has 'duration' => (
        is  => 'rw',
        isa => 'Time::Seconds',
        coerce => 1,
    );
}

package Foo::Declared;
{
    use Moose;
    use MooseX::Types::Time::Piece qw( Time Duration );

    has 'time_from_int' => (
        is  => 'rw',
        isa => Time,
        coerce => 1,
    );
    has 'time_from_str' => (
        is  => 'rw',
        isa => Time,
        coerce => 1,
    );
    has 'time_from_arrayref' => (
        is  => 'rw',
        isa => Time,
        coerce => 1,
    );

    has 'duration' => (
        is  => 'rw',
        isa => Duration,
        coerce => 1,
    );
}

package main;

use Test::More tests => 81;
use Test::NoWarnings;
use Test::Fatal;
use Test::Warn;

use Time::Local 'timelocal';
use Time::Piece;
use Time::Seconds;

for my $class ('Foo', 'Foo::Declared') {
    my $got = $class->new;
    my $exp;

    # -----------------------
    # coerce from Int
    $got->time_from_int( timelocal(59, 59, 23, 31, 11, 112) );
    $exp = localtime( timelocal(59, 59, 23, 31, 11, 112) );
    is( $got->time_from_int, $exp );
    isa_ok( $got->time_from_int, 'Time::Piece' );

    $got->time_from_int(-1);
    is( $got->time_from_int, localtime(-1) );
    isa_ok( $got->time_from_int, 'Time::Piece' );

    $got->time_from_int(2**33);
    is( $got->time_from_int, localtime(2**33) );
    isa_ok( $got->time_from_int, 'Time::Piece' );

    # -----------------------
    # coerce from Str
    #$got->time_from_str('Tue, 31 Dec 2012 23:59:59');
    $got->time_from_str('2012-12-31T23:59:59');
    $exp = Time::Piece->strptime( '2012-12-31T23:59:59', '%Y-%m-%dT%H:%M:%S' );
    is( $got->time_from_str, $exp );
    isa_ok( $got->time_from_str, 'Time::Piece' );

    SKIP: {
        skip "Time::Piece 1.20 not installed", 8 if $Time::Piece::VERSION lt '1.20';

        $got->time_from_str('2012-12-31');
        $exp = Time::Piece->strptime( '2012-12-31', '%Y-%m-%d' );
        is( $got->time_from_str, $exp );
        isa_ok( $got->time_from_str, 'Time::Piece' );

        # garbage at end of string
        warning_like { $got->time_from_str('2012-12-31 23:59:59') } qr/^garbage at end of string/;
        $exp = Time::Piece->strptime( '2012-12-31', '%Y-%m-%d' );
        is( $got->time_from_str, $exp );
        isa_ok( $got->time_from_str, 'Time::Piece' );

        warning_like { $got->time_from_str('2012-12-31T23:59:59.123') } qr/^garbage at end of string/;
        $exp = Time::Piece->strptime( '2012-12-31T23:59:59', '%Y-%m-%dT%H:%M:%S' );
        is( $got->time_from_str, $exp );
        isa_ok( $got->time_from_str, 'Time::Piece' );
    }

    like( exception { $got->time_from_str('apocalypse') },          qr/^Error parsing time/ );
    like( exception { $got->time_from_str('2012-13-01T23:59:59') }, qr/^Error parsing time/ );
    like( exception { $got->time_from_str('2012-12-31T24:59:59') }, qr/^Error parsing time/ );

    # -----------------------
    # coerce from ArrayRef
    $got->time_from_arrayref( ['2012-12-31 23:59:59', '%Y-%m-%d %H:%M:%S'] );
    $exp = Time::Piece->strptime( '2012-12-31 23:59:59', '%Y-%m-%d %H:%M:%S' );
    is( $got->time_from_arrayref, $exp );
    isa_ok( $got->time_from_arrayref, 'Time::Piece' );

    $got->time_from_arrayref( ['23:59:59', '%H:%M:%S'] );
    $exp = Time::Piece->strptime('23:59:59', '%H:%M:%S');
    is( $got->time_from_arrayref, $exp );
    isa_ok( $got->time_from_arrayref, 'Time::Piece' );

    SKIP: {
        skip "Time::Piece 1.20 not installed", 2 if $Time::Piece::VERSION lt '1.20';

        $got->time_from_arrayref( ['2012-12-31', '%Y-%m-%d %H:%M:%S'] );
        $exp = Time::Piece->strptime('2012-12-31', '%Y-%m-%d');
        is( $got->time_from_arrayref, $exp );
        isa_ok( $got->time_from_arrayref, 'Time::Piece' );
    }

    # ArrayRef with no args
    like( exception { $got->time_from_arrayref( [ ] ) }, qr/^Time is undefined/ );

    # ArrayRef with single arg
    SKIP: {
        skip "Time::Piece 1.20 not installed", 2 if $Time::Piece::VERSION lt '1.20';

        $got->time_from_arrayref( ['Tue, 31 Dec 2012 23:59:59'] );
        $exp = Time::Piece->strptime('Tue, 31 Dec 2012 23:59:59', '%a, %d %b %Y %H:%M:%S');
        is( $got->time_from_arrayref, $exp );
        isa_ok( $got->time_from_arrayref, 'Time::Piece' );
    }

    # ArrayRef with no args
    like( exception { $got->time_from_arrayref( [ ] ) }, qr/^Time is undefined/ );

    like(
        exception { $got->time_from_arrayref( ['Tue 31 Dec 2012 23:59:59'] ) },
        qr/^Error parsing time '.+' with format '.+'/
    );

    # ArrayRef with extra args (ignored)
    $got->time_from_arrayref(
        ['2012-12-31 23:59:59', '%Y-%m-%d %H:%M:%S', 'these args', 'should be ignored']
    );
    $exp = Time::Piece->strptime('2012-12-31 23:59:59', '%Y-%m-%d %H:%M:%S');
    is( $got->time_from_arrayref, $exp );
    isa_ok( $got->time_from_arrayref, 'Time::Piece' );

    # invalid arg format
    like(
        exception { $got->time_from_arrayref( ['2012-12-31T23:59:59', '%Y-%m-%d %H:%M:%S'] ) },
        qr/^Error parsing time '.+' with format '.+'/
    );
    like(
        exception { $got->time_from_arrayref( ['%Y-%m-%d %H:%M:%S', '2012-12-31 23:59:59'] ) },
        qr/^Error parsing time '.+' with format '.+'/
    );
    like(
        exception { $got->time_from_arrayref( [31, 12, 2012] ) },
        qr/^Error parsing time '.+' with format '.+'/
    );
    like(
        exception { $got->time_from_arrayref( ['2012-13-31 23:59:59', '%Y-%m-%d %H:%M:%S'] ) },
        qr/^Error parsing time '.+' with format '.+'/
    );

    # Duration
    $got->duration( Time::Seconds::ONE_DAY * 2.5 );
    isa_ok( $got->duration, 'Time::Seconds' );
    is( $got->duration->days, 2.5 );

    $got->duration(-1);
    isa_ok( $got->duration, 'Time::Seconds' );
    is( $got->duration->seconds, -1 );
}
