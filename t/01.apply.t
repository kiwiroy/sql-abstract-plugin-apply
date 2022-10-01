use strict;
use warnings;
use Test::More;
use SQL::Abstract;
use SQL::Abstract::Test import => [qw(is_same_sql is_same_sql_bind)];
use SQL::Abstract::Plugin::Apply;

subtest 'apply plugin' => sub {
  ok my $sqla = SQL::Abstract->new;
  ok +SQL::Abstract::Plugin::Apply->apply_to($sqla), 'apply_to applies ok';

  # TODO: use grep?
  is_deeply [$sqla->expander_list],
    [
    'alias',      'apply',     'bool',     'cast',   'delete',    'except',
    'except_all', 'from_list', 'func',     'insert', 'intersect', 'intersect_all',
    'join',       'list',      'old_from', 'op',     'row',       'select',
    'union',      'union_all', 'update',   'values'
    ],
    'expander_list includes "apply"';
  is_deeply [$sqla->renderer_list],
    [
    'alias',  'apply',  'as',        'bind', 'delete',  'except',  'from_list', 'func',
    'ident',  'insert', 'intersect', 'join', 'keyword', 'literal', 'op',        'row',
    'select', 'union',  'update',    'values'
    ],
    'renderer list include "apply"';

  # Check clauses
  is_deeply [$sqla->clauses_of('select')],
    ['with', 'select', 'from', 'where', 'setop', 'group_by', 'having', 'order_by'], 'As from ExtraClauses...';
};

subtest 'select and cross apply' => sub {
  my $sqla = SQL::Abstract->new->plugin('+Apply');

  # Table Valued Function
  my $sql = $sqla->select({
    from => [
      {items => {-as => ['i']}},
      -apply => [{-literal => [q/STRING_SPLIT(i.synonyms, ';')/]} => as => 'f', type => 'cross']
    ],
    select => [qw(id name size f.value)],
  });
  diag $sql if $ENV{HARNESS_IS_VERBOSE};
  is_same_sql $sql, q/
    SELECT id, name, size, f.value
      FROM items AS i
     CROSS APPLY STRING_SPLIT(i.synonyms, ';') AS f/
    ;

  # Inner join like
  $sql = $sqla->select({
    from => [
      {category => {-as => ['c']}},
      -apply => {
        to => {
          -select => {
            select   => [qw(product_name entry_date)],
            from     => [{product => {-as => ['p']}}],
            where    => {'c.id' => 'p.cat_id'},
            order_by => {-desc  => 'c.entry_date'},
          }
        }
      }
    ],
    select => [qw(c.category p.product_name p.entry_date)]
  });
  diag $sql if $ENV{HARNESS_IS_VERBOSE};
  is_same_sql $sql, q/
    SELECT c.category, p.product_name, p.entry_date
      FROM category AS c
     CROSS APPLY (
       SELECT product_name, entry_date
         FROM product AS p
        WHERE c.id = p.cat_id
        ORDER BY c.entry_date DESC
     )/, 'cross apply - similar to inner join';
};

subtest 'Cross Apply with limits' => sub {
  my $sqlac = SQL::Abstract->new->plugin('+Apply');
  $sqlac->clauses_of(select => ($sqlac->clauses_of('select'), qw(limit offset),));

  my ($sql, @bind) = $sqlac->select({
    from => [
      {category => {-as => ['c']}},
      -apply => {
        to => {
          -select => {
            select   => [qw(product_name entry_date)],
            from     => [{product => {-as => ['p']}}],
            where    => {'c.id' => 'p.cat_id'},
            order_by => {-desc  => 'c.entry_date'},
            limit    => 10
          }
        }
      }
    ],
    select => [qw(c.category p.product_name p.entry_date)]
  });

  diag $sql if $ENV{HARNESS_IS_VERBOSE};
  is_same_sql_bind $sql, \@bind, q/
      SELECT c.category, p.product_name, p.entry_date
        FROM category AS c
       CROSS APPLY (
         SELECT product_name, entry_date
           FROM product AS p
          WHERE c.id = p.cat_id
          ORDER BY c.entry_date DESC
          LIMIT 10
       )/, [], 'see 00.sqla-extraclauses.t tests';
};

subtest 'Outer apply' => sub {
  my $sqla = SQL::Abstract->new->plugin('+Apply');

  # Table Valued Function
  my $sql = $sqla->select({
    from => [
      {items => {-as => ['i']}},
      -apply => [{-literal => [q/STRING_SPLIT(i.synonyms, ';')/]} => as => 'f', type => 'outer']
    ],
    select => [qw(id name size f.value)],
  });
  diag $sql if $ENV{HARNESS_IS_VERBOSE};
  is_same_sql $sql, q/
    SELECT id, name, size, f.value
      FROM items AS i
     OUTER APPLY STRING_SPLIT(i.synonyms, ';') AS f/
    ;
};

done_testing;
