package SQL::Abstract::Plugin::Apply;

use strict;
use warnings;
use Moo;

our $VERSION = '0.01';

with 'SQL::Abstract::Role::Plugin';

sub register_extensions {
  my ($self, $sqla) = @_;

  # detect if these are already loaded (idempotent?)
  $sqla->plugin('+ExtraClauses')->plugin('+BangOverrides') unless (grep {m/^with$/} $sqla->clauses_of('select'));
  $self->register(expander => [apply => '_expand_apply'], renderer => [apply => '_render_apply'],);

  $sqla->wrap_clause_expander(
    'select.from' => sub {
      my ($orig) = @_;
      sub {
        my ($sqla, $x, $args) = @_;
        if (ref($args) eq 'ARRAY' and grep { !ref($_) and $_ =~ /^-apply/ } @$args) {
          local $self->{sqla}
            = $sqla;    # fix: Attempted to access 'sqla' but it is not set (expand_expr calls in _expand_from_list)
          return $self->_expand_from_list(undef, $args);
        }
        return $sqla->$orig(undef, $args);
      }
    }
  );

  return $sqla;
}

# Most of the rest is extremely similar to _expand_join, _expand_from_list and _render_join in S::A::P::ExtraClauses

sub _expand_apply {
  my ($self, undef, $args) = (shift, shift, shift);
  my %proto = (ref($args) eq 'HASH' ? %$args : (to => @$args));

  if (my $as = delete $proto{as}) {
    $proto{to} = $self->expand_expr({-as => [{-from_list => $proto{to}}, $as]});
  }
  my %ret
    = (type => delete $proto{type} || 'cross', to => $self->expand_expr({-from_list => delete $proto{to}}, -ident));
  %ret = (%ret, map +($_ => $self->expand_expr($proto{$_}, -ident)), sort keys %proto);

  return +{-apply => \%ret};
}

sub _expand_from_list {
  my ($self, undef, $args) = @_;
  if (ref($args) eq 'HASH') {
    return $args if $args->{-from_list};
    return {-from_list => [$self->expand_expr($args)]};
  }
  my @list;
  my @args = ref($args) eq 'ARRAY' ? @$args : ($args);
  while (my $entry = shift @args) {
    if (!ref($entry) and $entry =~ /^-(.*)/) {
      if ($1 eq 'as') {
        $list[-1] = $self->expand_expr({-as => [$list[-1], map +(ref($_) eq 'ARRAY' ? @$_ : $_), shift(@args)]});
        next;
      }
      $entry = {$entry => shift @args};
    }
    my $aqt = $self->expand_expr($entry, -ident);
    if ($aqt->{-join} and not $aqt->{-join}{from}) {
      $aqt->{-join}{from} = pop @list;
    }
    if ($aqt->{-apply} and not $aqt->{-apply}{from}) {
      $aqt->{-apply}{from} = pop @list;
    }
    push @list, $aqt;
  }
  return $list[0] if @list == 1;
  return {-from_list => \@list};
}

sub _render_apply {
  my ($self, $x, $args) = (shift, shift, shift);

  my @parts = (
    $args->{from}, {-keyword => join '_', ($args->{type} || ()), $x},    # 'join' -> $x is only real difference here
    (
      map +($_->{-ident} || $_->{-as}      ? $_                  : ('(', $self->render_aqt($_, 1), ')')),
      map +(@{$_->{-from_list} || []} == 1 ? $_->{-from_list}[0] : $_),
      $args->{to}
    ),
    ($args->{on} ? ({-keyword => 'on'}, $args->{on},) : ()),
  );

  return $self->join_query_parts(' ', @parts);
}

1;

=encoding utf8

=head1 NAME

SQL::Abstract::Plugin::Apply - Cross and outer apply for SQL::Abstract 2+

=head1 SYNOPSIS

  # compose the plugin
  my $sqla = SQL::Abstract->new->plugin('+Apply');
  # SELECT c.category, p.product_name, p.entry_date
  #   FROM category AS c
  #  CROSS APPLY (
  #    SELECT product_name, entry_date
  #      FROM product AS p
  #     WHERE c.id = p.cat_id
  #     ORDER BY p.entry_date DESC
  #  )
  $sqla->select({
    from => [
      {category => {-as => ['c']}},
      -apply => {
        to => {
          -select => {
            select   => [qw(product_name entry_date)],
            from     => [{product => {-as => ['p']}}],
            where    => {'c.id' => 'p.cat_id'},
            order_by => {-desc  => 'p.entry_date'},
            }
          }
        },
        type => 'cross'
    ],
    select => [qw(c.category p.product_name p.entry_date)]
  });

=head1 DESCRIPTION

The I<JOIN> syntax of SQL::Abstract does not allow for I<CROSS> or I<OUTER> I<APPLY>. This module

=head1 METHODS

L<SQL::Abstract::Plugin::Apply> implements the following methods.

=head2 register_extensions

=head1 AUTHOR

=cut
