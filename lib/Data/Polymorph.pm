
use warnings;
use strict;

package Data::Polymorph;

use Carp;
use Scalar::Util qw( blessed looks_like_number );
use UNIVERSAL qw( isa can );

=head1 NAME

Data::Polymorph - Yet another approach for polymorphism.

=head1 VERSION

Version 0.01

=cut

our $VERSION = '0.01';

=head1 SYNOPSIS

  my $poly = Data::Polymorph->new;
  
  ## defining external method 'freeze'
  
  $poly->define( 'FileHandle' => freeze => sub{
    "do{ require Symbol; bless Symbol::gensym(), '".ref($_[0])."'}"
  }  );
  
  $poly->define( "UNIVERSAL" => freeze => sub{
    use Data::Dumper;
    sprintf( 'do{ my %s }', Dumper $_[0]);
  });
  
  ## it returns `undef'
  FileHandle->can('freeze');
  UNIVERSAL->('freeze');
  
  ###
  ### applying defined method.
  ###
  
  ## returns "do{ requier Symbol; bless Symbol::gensym(), 'FileHandle'}"
  $poly->apply( FileHandle->new , 'freeze' );

=head1 ATTRIBUTES

=over 4

=item C<runs_native>

  ##
  ##  If external method "foo" is not defined into the $poly...
  ##
  
  $poly->runs_native(1);
  $poly->apply($obj, foo => $bar ); # ... same as $obj->foo($bar)
  $poly->runs_native(0);
  $poly->apply($obj, foo => $bar ); # ... die

If this value is true, the object uses "UNIVERSAL-can" 
when the method is not defined.

=item C<methods>

The dictionary of class methods.

=item C<special>

The dictionary of type methods.

=back

=cut


{
  my @Template =
    (
     [ methods => sub{{}} ],
     [ special => sub{
         return
           [
            [Undef     => sub{ !defined( $_[1] );            },{}],
            [Object    => sub{ blessed $_[1] and 1           },{}],
            [ScalarRef => sub{ isa( $_[1], 'SCALAR' )        },{}],
            [CodeRef   => sub{ isa( $_[1], 'CODE' )          },{}],
            [ArrayRef  => sub{ isa( $_[1], 'ARRAY' )         },{}],
            [HashRef   => sub{ isa( $_[1], 'HASH' )          },{}],
            [GlobRef   => sub{ isa( $_[1], 'GLOB' )          },{}],
            [RefRef    => sub{ isa( $_[1], 'REF' )           },{}],
            [Ref       => sub{ ref( $_[1] ) and 1            },{}],
            [Num       => sub{ looks_like_number( $_[1] )    },{}],
            [Glob      => sub{ isa(\$_[1],'GLOB' )           },{}],
            [Str       => sub{ isa(\$_[1],'SCALAR');         },{}],
            [Value     => sub{ 1                             },{}],
            [Defined   => sub{ 1                             },{}],
            [Any       => sub{ 1                             },{}],
           ]
         }],
     [ runs_native     => sub{0} ],
     );

  sub{
    my ( $caller ) = caller;
    foreach (@_){
      my $field = $_;
      my $glob = do{ no strict 'refs'; \*{"${caller}::$field"} };
      *{$glob} = sub  ($;$){
        my $self = shift;
        return $self->{$field} unless @_;
        $self->{$field} = shift;
      };
    }
  }->( map { $_->[0]} @Template );

  sub new {
    my ($self, %args) = @_;
    $self = bless {} , (blessed $self) || $self;
    foreach my $spec ( @Template ){
      $self->{$spec->[0]} = $spec->[1]->($self);
    }
    $self->runs_native(1) if $args{runs_native};
    $self;
  }
}

=head1 METHODS

=over 4

=item C<new>

  $poly = Data::Polymorph->new();
  $poly = Data::Polymorph->new( runs_native => 0 ); 
  $poly = Data::Polymorph->new( runs_native => 1 ); 

Constructs and returns a new object of this class.

=item C<type>

  $type = $poly->type( 123  ); # returns 'Num'

Returns type name of given data. Types are below.

  Any
    Undef
    Defined
      Value
        Num
        Str
        Glob
      Ref
        Object
        ScalarRef
        HashRef
        ArrayRef
        CodeRef

They seem like L<Moose> Types.

Actually, I designed these types based on the man pages from 
L<Moose::Util::TypeConstraints>. Though they don't depend on L<Moose>, 
as optional features, 
I intend to make them compatible with actual L<Moose>-types

But, at this time, they are not implemented.

=item C<is_type>

  $poly->is_type('Any') ; # => 1
  $poly->is_type('Str') ; # => 1
  $poly->is_type('Object') ; # => 1
  $poly->is_type('UNIVERSAL') ; # => 0

=item C<define_type_method>

  $poly->define_type_method('ArrayRef' => 'values' => sub{ @$_[0]});
  $poly->define_type_method('HashRef'  => 'values' => sub{ values %$_[0]});
  $poly->define_type_method('Any'      => 'values' => sub{ $_[0] });

Defines a new method for the given type. Types that are able to use to this
is below.

=item C<define_class_method>

  $poly->define_class_method( 'Class::Name' => 'method' => sub{
    #                    code reference
  }  );

Defines a new external method of the given class which is applyable 
by this object of this class.

=item C<define>

  $poly->define('Class::Name' => 'method' => sub{ ... } );
  $poly->define('Undef'       => 'method' => sub{ ... } );

Defines a new method for a type or a class.

=item C<method>

  $meth = $poly->method( 'A::Class' => 'method' );
  ($poly->apply( 'A::Class' => $method ) or
   sub{ confess "method $method is not defined" } )->( $args .... );

Returns applicable method to invoke by an object of the class.

=item C<super_method>

  $super = $poly->super_method( 'A::Class' => 'method' );
  ($poly->apply( 'A::Class' => $method ) or
   sub{ confess "method $method is not defined" } )->( $args .... );

Returns applicable method to invoke as super method
by an object of the object.

=item C<type_method>

  $meth = $poly->type_method( ArrayRef => 'values' );

Returns applicable method to invoke by non object value.

Returns the type name of the given object.

=item C<apply>

  $poly->apply( $obj => 'method' => $arg1, $arg1 , $arg3 .... );

Invokes an external method which was defined.

=item C<super>

  $poly->super( $obj => 'method' => $arg1, $arg1 , $arg3 .... );

Invokes a external method of super class of the object.

=back

=cut

sub is_type {
  my ($self, $class) = @_;
  foreach my $type ( @{$self->special} ) {
    return 1 if $type->[0] eq $class;
  }
  0
}

sub define {
  my ( $self, $class, $method, $code ) = @_;
  goto ( $self->is_type( $class )
         ? \&define_type_method
         : \&define_class_method );
}

sub define_class_method {
  my ( $self, $class, $method , $code ) = @_;
  my $slot = ($self->methods->{$method} ||= []);
  my $i = 0;
  for(; $i < scalar @$slot ; $i++){
    my $klass = $slot->[$i]->[0];

    if( $klass eq $class ){
      $slot->[$i]->[1] = $code;
      return;
    }

    last if isa $class => $klass;
  }
  splice @$slot, $i, 0, [$class => $code];
}

sub define_type_method {
  my ( $self, $class, $method , $code ) = @_;
  foreach my $slot ( @{$self->special}) {
    next unless $slot->[0] eq $class;
    return $slot->[2]->{$method} = $code;
  }
  confess "unknown special class: $class";
}

sub type {
  my ( $self, $obj, $meth ) = @_;
  foreach my $slot ( @{$self->special} ) {
    return $slot->[0] if $slot->[1]->($self, $obj) ;
  }
}

sub type_method {
  my ( $self, $obj, $meth ) = @_;
  foreach my $slot ( @{$self->special} ) {
    return $slot->[2]->{$meth} if ( $slot->[1]->($self, $obj) and
                                    exists $slot->[2]->{$meth} );
  }
}

sub method {
  my ( $self, $class, $method, $super ) = @_;
  my $slot = ($self->methods->{$method} ||= []);
  foreach my $meth ( @$slot ){
    next unless  isa( $class, $meth->[0] );
    next if $super && $class eq $meth->[0];
    return $meth->[1];
  }
}

sub super_method { $_[0]->method(@_[1,2],1); }

sub apply {
  my $self   = shift;
  my $obj    = $_[0];
  my $method = splice @_, 1, 1;
  my $class  = blessed( $obj );
  my $code   = ($class
                ?( $self->method( $class, $method ) or
                   $self->type_method( $obj, $method ) or
                   UNIVERSAL::can( $obj , $method ) )
                :  $self->type_method( $obj, $method ));

  confess sprintf('method "%s" is not defined in %s',
                  $method,
                  $class || $self->type($obj)) unless $code;
  goto $code;
}

sub super {
  my $self   = shift;
  my $obj    = $_[0];
  my $method = splice @_, 1, 1;
  my $class  = blessed( $obj );
  my $code   = ( $class and $class eq 'UNIVERSAL'
                 ? $self->type_method( $obj )
                 : $self->super_method( $class, $method ) );

  if( !$code && $self->runs_native ){
    foreach my $parent ( do{ no strict 'refs'; @{"${class}::ISA"} } ){
      $code = UNIVERSAL::can( $parent, $method );
      last if $code;
    }
  }

  confess sprintf('method "%s" is not defined in %s',
                  $method,
                   $class || $self->type($obj)) unless $code;
  goto $code;
}

1; # End of Data::Polymorph

__END__


=head1 AUTHOR

lieutar, C<< <lieutar at 1dk.jp> >>

=head1 BUGS

Please report any bugs or feature requests to C<bug-class-external-method at
rt.cpan.org>, or through
the web interface at 
L<http://rt.cpan.org/NoAuth/ReportBug.html?Queue=Data-Polymorph>.
I will be notified, and then you'll
automatically be notified of progress on your bug as I make changes.

and...

Even if I am writing strange English because I am not good at English, 
I'll not often notice the matter. (Unfortunately, these cases aren't
testable automatically.)

If you find strange things, please tell me the matter.


=head1 SUPPORT

You can find documentation for this module with the perldoc command.

    perldoc Data::Polymorph


You can also look for information at:

=over 4

=item * RT: CPAN's request tracker

L<http://rt.cpan.org/NoAuth/Bugs.html?Dist=Data-Polymorph>

=item * AnnoCPAN: Annotated CPAN documentation

L<http://annocpan.org/dist/Data-Polymorph>

=item * CPAN Ratings

L<http://cpanratings.perl.org/d/Data-Polymorph>

=item * Search CPAN

L<http://search.cpan.org/dist/Data-Polymorph>

=back

=head1 COPYRIGHT & LICENSE

Copyright 2008 lieutar, all rights reserved.

This program is free software; you can redistribute it and/or modify it
under the same terms as Perl itself.

=cut
