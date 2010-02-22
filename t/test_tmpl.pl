#!/usr/bin/perl -w

use strict;
use warnings;
use Tenjin;

my $t = Tenjin->new({ path => ['./'], postfix => '.html' });
print $t->render('test_tmpl.html', {
	scalar_variable		=> 'hello',
	hash_variable		=> { hash_value_key => 'sensible' },
	array_variable		=> [ undef, undef, 'world' ],
	this			=> { is => { a => { very => { deep => { hash => { structure => 'of' } } } } } },
	array_loop		=> [ 'soccer', 'sega', 'genesis' ],
	hash_loop		=> { 1992 => 'bad', 1993 => 'ok', 1994 => 'good', 1995 => 'perfect' },
	records_loop		=> [ { name => 'Ido Perlmuter', age => 25 }, { name => 'Noi Perlmuter', age => 13 } ],
	variable_if		=> 1,
	variable_if_else	=> undef,
	template_if_true	=> 'true.html',
	template_if_false	=> 'false.html',
	variable_expression_a	=> 2,
	variable_expression_b	=> 5,
	variable_function_arg	=> 'asf asdf asdfff',
});
