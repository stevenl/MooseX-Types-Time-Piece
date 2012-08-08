#!perl -T

package Foo;
{
    use Moose;
    use MooseX::Types::Time::Piece;

    has 'time' => (
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

    has 'time' => (
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

use Test::More tests => 57;
use Test::NoWarnings;
use Test::Fatal;
use Test::Warn;

use Time::HiRes ();
use Time::Piece;
use Time::Seconds;

for my $class ('Foo', 'Foo::Declared') {
    my $got = $class->new;
    my $exp;
    my $time;

    # -----------------------
    # coerce from Num
    $time = time();
    $got->time( $time );
    is( $got->time, localtime( $time ), 'int coercion' );

    $time = Time::HiRes::time();
    $got->time( $time );
    $exp = localtime( $time );
    is( $got->time, $exp, 'num coercion' );
    is( $got->time->epoch, $exp->epoch );

    $got->time( "$time" );
    is( $got->time, localtime( $time ), 'string num coercion' );

    $got->time( -$time );
    is( $got->time, localtime( -$time ), 'negative num coercion' );

    $got->time(2**33);
    is( $got->time, localtime(2**33), 'big num coercion' );

    # -----------------------
    # coerce from Str
    $got->time('2012-12-31T23:59:59');
    $exp = Time::Piece->strptime( '2012-12-31T23:59:59', '%Y-%m-%dT%H:%M:%S' );
    is( $got->time, $exp, 'str coercion' );

    SKIP: {
        skip "Time::Piece 1.20 not installed", 8 if $Time::Piece::VERSION lt '1.20';

        $got->time('2012-12-31');
        $exp = Time::Piece->strptime( '2012-12-31', '%Y-%m-%d' );
        is( $got->time, $exp, 'str coercion - date only' );

        # garbage at end of string
        warning_like { $got->time('2012-12-31 23:59:59') } qr/^garbage at end of string/;
        $exp = Time::Piece->strptime( '2012-12-31', '%Y-%m-%d' );
        is( $got->time, $exp, 'str coercion - with space' );

        warning_like { $got->time('2012-12-31T23:59:59.123') } qr/^garbage at end of string/;
        $exp = Time::Piece->strptime( '2012-12-31T23:59:59', '%Y-%m-%dT%H:%M:%S' );
        is( $got->time, $exp, 'str coercion - with milliseconds' );
    }

    like(
        exception { $got->time('apocalypse') },
        qr/^Error parsing time/,
        'str coercion - non-time'
    );
    like(
        exception { $got->time('2012-13-01T23:59:59') },
        qr/^Error parsing time/,
        'str coercion - invalid date'
    );
    like(
        exception { $got->time('2012-12-31T24:59:59') },
        qr/^Error parsing time/,
        'str coercion - invalid time'
    );

    # -----------------------
    # coerce from ArrayRef
    $got->time( ['2012-12-31 23:59:59', '%Y-%m-%d %H:%M:%S'] );
    $exp = Time::Piece->strptime( '2012-12-31 23:59:59', '%Y-%m-%d %H:%M:%S' );
    is( $got->time, $exp, 'arrayref coercion' );

    $got->time( ['23:59:59', '%H:%M:%S'] );
    $exp = Time::Piece->strptime('23:59:59', '%H:%M:%S');
    is( $got->time, $exp, 'arrayref coercion - time only' );

    SKIP: {
        skip "Time::Piece 1.20 not installed", 2 if $Time::Piece::VERSION lt '1.20';

        $got->time( ['2012-12-31', '%Y-%m-%d %H:%M:%S'] );
        $exp = Time::Piece->strptime('2012-12-31', '%Y-%m-%d');
        is( $got->time, $exp, 'arrayref coercion - date only' );
    }

    # ArrayRef with no args
    like(
        exception { $got->time( [ ] ) },
        qr/^Time is undefined/,
        'arrayref coercion - empty array'
    );

    # ArrayRef with single arg
    # this can't always be handled because the format expects a timezone
    SKIP: {
        skip "Time::Piece 1.20 not installed", 2 if $Time::Piece::VERSION lt '1.20';

        $got->time( ['Tue, 31 Dec 2012 23:59:59'] );
        $exp = Time::Piece->strptime('Tue, 31 Dec 2012 23:59:59', '%a, %d %b %Y %H:%M:%S');
        is( $got->time, $exp, 'arrayref coercion - single value' );
    }

    like(
        exception { $got->time( ['Tue 31 Dec 2012 23:59:59'] ) },
        qr/^Error parsing time '.+' with format '.+'/,
        'arrayref coercion - invalid single value'
    );

    # ArrayRef with extra args (ignored)
    $got->time(
        ['2012-12-31 23:59:59', '%Y-%m-%d %H:%M:%S', 'these args', 'should be ignored']
    );
    $exp = Time::Piece->strptime('2012-12-31 23:59:59', '%Y-%m-%d %H:%M:%S');
    is( $got->time, $exp, 'arrayref coercion - extra values' );

    # invalid arg format
    like(
        exception { $got->time( ['2012-12-31T23:59:59', '%Y-%m-%d %H:%M:%S'] ) },
        qr/^Error parsing time '.+' with format '.+'/,
        'arrayref coercion - time and format mismatch'
    );
    like(
        exception { $got->time( ['%Y-%m-%d %H:%M:%S', '2012-12-31 23:59:59'] ) },
        qr/^Error parsing time '.+' with format '.+'/,
        'arrayref coercion - time and format reordered'
    );
    like(
        exception { $got->time( [31, 12, 2012] ) },
        qr/^Error parsing time '.+' with format '.+'/,
        'arrayref coercion - invalid values'
    );
    like(
        exception { $got->time( ['2012-13-31 23:59:59', '%Y-%m-%d %H:%M:%S'] ) },
        qr/^Error parsing time '.+' with format '.+'/,
        'arrayref coercion - invalid date'
    );

    # -----------------------
    # Duration
    $got->duration( 2.5 );
    is( $got->duration->seconds, 2.5, 'duration coercion' );

    $got->duration(-1);
    is( $got->duration->seconds, -1, 'negative duration coercion' );
}
