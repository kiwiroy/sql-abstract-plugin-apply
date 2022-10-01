use strict;
use warnings;
use Test::More;
use SQL::Abstract;
use SQL::Abstract::Test import => [qw(is_same_sql is_same_sql_bind)];

subtest 'Track extraclauses assumptions' => sub {
  ok my $sqla = SQL::Abstract->new;
  $sqla->plugin('+ExtraClauses');

  is_deeply [$sqla->expander_list],
    [
    'alias',     'bool',     'cast',   'delete',    'except',        'except_all',
    'from_list', 'func',     'insert', 'intersect', 'intersect_all', 'join',
    'list',      'old_from', 'op',     'row',       'select',        'union',
    'union_all', 'update',   'values'
    ],
    'expander_list includes "apply"';
  is_deeply [$sqla->renderer_list],
    [
    'alias',  'as',        'bind', 'delete',  'except',  'from_list', 'func', 'ident',
    'insert', 'intersect', 'join', 'keyword', 'literal', 'op',        'row',  'select',
    'union',  'update',    'values'
    ],
    'renderer list include "apply"';
  is_deeply [$sqla->clauses_of('select')],
    ['with', 'select', 'from', 'where', 'setop', 'group_by', 'having', 'order_by'], 'ExtraClauses...';
};

subtest 'select and subselect with limit' => sub {
  my $sqla = SQL::Abstract->new;
  $sqla->plugin('+ExtraClauses');

  my $sqlac = $sqla->clone->clauses_of(select => ($sqla->clauses_of('select'), qw(limit offset),));

  my ($sql, @bind) = $sqlac->select({select => '*', from => 'foo', limit => 10, offset => 20,});
  is_same_sql_bind $sql, \@bind, q/SELECT * FROM foo LIMIT ? OFFSET ?/, [10, 20], 'Added to bind.';

  ($sql, @bind) = $sqlac->select({
    from => [{
      -select => {
        select   => [qw(product_name entry_date)],
        from     => [{product => {-as => ['p']}}],
        where    => {'c.id' => 'p.cat_id'},
        order_by => {-desc  => 'c.entry_date'},
        limit    => 10,
        offset   => 20,
      },
    }],
    select => [qw(c.category p.product_name p.entry_date)]
  });

  is_same_sql_bind $sql, \@bind, q/
      SELECT c.category, p.product_name, p.entry_date
        FROM (
          SELECT product_name, entry_date
            FROM product AS p
           WHERE c.id = p.cat_id
           ORDER BY c.entry_date DESC
           LIMIT 10 OFFSET 20
        )/, [], 'subselect limits have different rules? - not added to bind!';
};

done_testing;
