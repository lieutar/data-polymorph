
use strict;
use warnings;
use Test::More tests => 24;
require Data::Polymorph;

{
  @t0::ISA   = qw();
  @t1::ISA   = qw();
  @t00::ISA  = qw( t0 );
  @t01::ISA  = qw( t0 );
  @t000::ISA = qw( t00 );
  @t001::ISA = qw( t00 );
  @t002::ISA = qw( t00 );
  @t010::ISA = qw( t01 );
  @t011::ISA = qw( t01 );
}

my $new = sub{ bless {}, ref($_[0]) || shift };
{
  no warnings;
  *t0::new = $new;
  *t1::new = $new;
  *t2::new = $new;
}


my $p00 = Data::Polymorph->new;

do{
  my $class = $_;
  $p00->define( $class => 'foo', sub{$class});
}foreach(qw(t1 t001 t0 t000 UNIVERSAL t00));

do{
  my $class = $_;
  $p00->define( $class => 'foo', sub{$class});
}foreach(qw(Any Num HashRef ArrayRef GlobRef Undef Ref));


is( $p00->apply($_->[0]->new => foo => ) , $_->[1] )
  foreach ([t1   => 't1'],
           [t2   => 'UNIVERSAL'],
           [t00  => 't00'],
           [t01  => 't0'],
           [t000 => 't000'],
           [t001 => 't001'],
           [t002 => 't00'],
           [t010 => 't0'],
           [t011 => 't0']);


is( $p00->type($_->[0]) , $_->[1], "type: ". ($_->[0] ||
                                                               'undef'))
  foreach([ foo   => 'Str'],
          [ 356   => 'Num'],
          [ undef , 'Undef' ],
          [ {}    => 'HashRef' ],
          [ []    => 'ArrayRef' ],
          [ do{ no warnings; \*main::Hoo } => 'GlobRef' ],
          [ sub{}  => 'CodeRef' ]);


is( $p00->apply($_->[0] => foo => ) ,
    $_->[1], "apply(special): ". ($_->[0] || 'undef'))
  foreach([ foo   => 'Any'],
          [ 356   => 'Num'],
          [ undef , 'Undef' ],
          [ {}    => 'HashRef' ],
          [ []    => 'ArrayRef' ],
          [ do{ no warnings; \*main::Hoo } => 'GlobRef' ],
          [ sub{}  => 'Ref' ]);


my $p01 = Data::Polymorph->new;
$p01->define( Any => foo => sub{'Any'} );
is( $p01->apply( bless({}, 'A') => foo => ) , 'Any', 'over UNIVERSAL' );
