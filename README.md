# NAME

SQL::Abstract::Plugin::Apply - Cross and outer apply for SQL::Abstract 2+

# SYNOPSIS

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

# DESCRIPTION

The _JOIN_ syntax of SQL::Abstract does not allow for _CROSS_ or _OUTER_ _APPLY_. This module

# METHODS

[SQL::Abstract::Plugin::Apply](https://metacpan.org/pod/SQL%3A%3AAbstract%3A%3APlugin%3A%3AApply) implements the following methods.

## register\_extensions

# AUTHOR
