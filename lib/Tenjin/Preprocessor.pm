package Tenjin::Preprocessor;

use strict;

our @ISA = ('Tenjin::Template');

sub stmt_pattern {
	return shift->SUPER::compile_stmt_pattern('PL');
}

sub expr_pattern {
	return qr/\[\*=(=?)(.*?)(=?)=\*\]/s;
}

sub add_expr {
	my ($this, $bufref, $expr, $flag_escape) = @_;

	$expr = "Tenjin::Util::_decode_params($expr)";
	$this->SUPER::add_expr($bufref, $expr, $flag_escape);
}

__PACKAGE__;

__END__

=pod

=head1 NAME

Tenjin::Preprocessor - The Tenjin preprocessor

=head1 SYNOPSIS

	used internally.

=head1 SEE ALSO

L<Tenjin>.

=head1 AUTHOR

Tenjin is developed by Makoto Kuwata at L<http://www.kuwata-lab.com/tenjin/>. Version 0.03 was tidied and CPANized from the original 0.0.2 source by Ido Perelmutter E<lt>ido50@yahoo.comE<gt>.

=head1 COPYRIGHT & LICENSE

Tenjin is licensed under the MIT license.

	Copyright (c) 2007-2009 the aforementioned authors.

	Permission is hereby granted, free of charge, to any person obtaining
	a copy of this software and associated documentation files (the
	"Software"), to deal in the Software without restriction, including
	without limitation the rights to use, copy, modify, merge, publish,
	distribute, sublicense, and/or sell copies of the Software, and to
	permit persons to whom the Software is furnished to do so, subject to
	the following conditions:

	The above copyright notice and this permission notice shall be
	included in all copies or substantial portions of the Software.

	THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,
	EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF
	MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND
	NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE
	LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION
	OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION
	WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.

=cut
