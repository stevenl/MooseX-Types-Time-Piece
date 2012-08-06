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

use Test::More tests => 79;
use Test::NoWarnings;
use Test::Fatal;
use Test::Warn;

use Time::Local 'timelocal';
use Time::Piece;
use Time::Seconds;

for my $class ('Foo', 'Foo::Declared') {
    my $f = $class->new;

    # -----------------------
    # coerce from Int
    $f->time_from_int( timelocal(59, 59, 23, 31, 11, 112) );
    isa_ok( $f->time_from_int, 'Time::Piece' );
    is( $f->time_from_int->datetime, '2012-12-31T23:59:59' );

    $f->time_from_int(-1);
    isa_ok( $f->time_from_int, 'Time::Piece' );
    is( $f->time_from_int->datetime, localtime(-1)->datetime );

    $f->time_from_int(2**33);
    isa_ok( $f->time_from_int, 'Time::Piece' );

    # -----------------------
    # coerce from Str
    #$f->time_from_str('Tue, 31 Dec 2012 23:59:59');
    $f->time_from_str('2012-12-31T23:59:59');
    isa_ok( $f->time_from_str, 'Time::Piece' );
    is( $f->time_from_str->datetime, '2012-12-31T23:59:59' );

    SKIP: {
        skip "Time::Piece 1.20 not installed", 8 if $Time::Piece::VERSION lt '1.20';

        $f->time_from_str('2012-12-31');
        isa_ok( $f->time_from_str, 'Time::Piece' );
        is( $f->time_from_str->datetime, '2012-12-31T00:00:00' );

        # garbage at end of string
        warning_like { $f->time_from_str('2012-12-31 23:59:59') } qr/^garbage at end of string/;
        isa_ok( $f->time_from_str, 'Time::Piece' );
        is( $f->time_from_str->datetime, '2012-12-31T00:00:00' );

        warning_like { $f->time_from_str('2012-12-31T23:59:59.123') } qr/^garbage at end of string/;
        isa_ok( $f->time_from_str, 'Time::Piece' );
        is( $f->time_from_str->datetime, '2012-12-31T23:59:59' );
    }

    like( exception { $f->time_from_str('apocalypse') },          qr/^Error parsing time/ );
    like( exception { $f->time_from_str('2012-13-01T23:59:59') }, qr/^Error parsing time/ );
    like( exception { $f->time_from_str('2012-12-31T24:59:59') }, qr/^Error parsing time/ );

    # -----------------------
    # coerce from ArrayRef
    $f->time_from_arrayref( ['2012-12-31 23:59:59', '%Y-%m-%d %H:%M:%S'] );
    isa_ok( $f->time_from_arrayref, 'Time::Piece' );
    is( $f->time_from_arrayref->datetime, '2012-12-31T23:59:59' );

    $f->time_from_arrayref( ['23:59:59', '%H:%M:%S'] );
    isa_ok( $f->time_from_arrayref, 'Time::Piece' );
    my $epoch = localtime(0);
    my $time = $epoch + (23 - $epoch->hour)*3600 + 59*60 + 59;
    is( $f->time_from_arrayref->datetime, $time->datetime );

    SKIP: {
        skip "Time::Piece 1.20 not installed", 2 if $Time::Piece::VERSION lt '1.20';

        $f->time_from_arrayref( ['2012-12-31', '%Y-%m-%d %H:%M:%S'] );
        isa_ok( $f->time_from_arrayref, 'Time::Piece' );
        is( $f->time_from_arrayref->datetime, '2012-12-31T00:00:00' );
    }

    # ArrayRef with no args
    like( exception { $f->time_from_arrayref( [ ] ) }, qr/^Time is undefined/ );

    # ArrayRef with single arg
    $f->time_from_arrayref( ['Tue, 31 Dec 2012 23:59:59'] );
    isa_ok( $f->time_from_arrayref, 'Time::Piece' );
    is( $f->time_from_arrayref->datetime, '2012-12-31T23:59:59' );

    # ArrayRef with no args
    like( exception { $f->time_from_arrayref( [ ] ) }, qr/^Time is undefined/ );

    like(
        exception { $f->time_from_arrayref( ['Tue 31 Dec 2012 23:59:59'] ) },
        qr/^Error parsing time '.+' with format '.+'/
    );

    # ArrayRef with extra args (ignored)
    $f->time_from_arrayref(
        ['2012-12-31 23:59:59', '%Y-%m-%d %H:%M:%S', 'these args', 'should be ignored']
    );
    isa_ok( $f->time_from_arrayref, 'Time::Piece' );
    is( $f->time_from_arrayref->datetime, '2012-12-31T23:59:59' );

    # invalid arg format
    like(
        exception { $f->time_from_arrayref( ['2012-12-31T23:59:59', '%Y-%m-%d %H:%M:%S'] ) },
        qr/^Error parsing time '.+' with format '.+'/
    );
    like(
        exception { $f->time_from_arrayref( ['%Y-%m-%d %H:%M:%S', '2012-12-31 23:59:59'] ) },
        qr/^Error parsing time '.+' with format '.+'/
    );
    like(
        exception { $f->time_from_arrayref( [31, 12, 2012] ) },
        qr/^Error parsing time '.+' with format '.+'/
    );
    like(
        exception { $f->time_from_arrayref( ['2012-13-31 23:59:59', '%Y-%m-%d %H:%M:%S'] ) },
        qr/^Error parsing time '.+' with format '.+'/
    );

    # Duration
    $f->duration( Time::Seconds::ONE_DAY * 2.5 );
    isa_ok( $f->duration, 'Time::Seconds' );
    is( $f->duration->days, 2.5 );

    $f->duration(-1);
    isa_ok( $f->duration, 'Time::Seconds' );
    is( $f->duration->seconds, -1 );
}
