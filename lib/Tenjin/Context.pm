package Tenjin::Context;

use strict;

sub new {
	my ($class, $this) = @_;

	$this = {} unless defined($this);
	return bless($this, $class);
}

sub evaluate {
	my ($this, $_script) = @_;

	return $this->to_func($_script)->($this);
}

sub to_func {
	my ($this, $_script) = @_;

	my $_s = "sub { my (\$_context) = \@_; $_script }";
	my $_func;
	if ($Tenjin::USE_STRICT) {
		$_func = eval($_s);
	} else {
		no strict;
		$_func = eval($_s);
		use strict;
	}

	if ($@) {
		die "Tenjin::Context: Failed rendering, ", $@;
	}

	return $_func;
}

## ex. {'x'=>10, 'y'=>20} ==> "my $x = $_context->{'x'}; my $y = $_context->{'y'}; "
sub _build_decl {
	my $this = shift;

	my @buf = ();
	foreach (keys %$this) {
		push(@buf, "my \$$_ = \$_context->{'$_'}; ") unless $_ eq '_context';
	}

	return join('', @buf);
}

sub escape {
	return shift;
}

*_p			= *Tenjin::Util::_p;
*_P			= *Tenjin::Util::_P;
*escape     = *Tenjin::HTML::escape_xml;
*escape_xml = *Tenjin::HTML::escape_xml;
*encode_url = *Tenjin::HTML::encode_url;
*checked    = *Tenjin::HTML::checked;
*selected   = *Tenjin::HTML::selected;
*disabled   = *Tenjin::HTML::disabled;
*nl2br      = *Tenjin::HTML::nl2br;
*text2html  = *Tenjin::HTML::text2html;
*tagattr    = *Tenjin::HTML::tagattr;

__PACKAGE__;

__END__

=pod

=head1 NAME

Tenjin::Context

=head1 SYNOPSIS

	used internally.

=head1 SEE ALSO

L<Tenjin>.

=head1 AUTHOR

Tenjin is developed by Makoto Kuwata at L<<a href="http://www.kuwata-lab.com/tenjin/">kuwata-lab.com</a>>. Version 0.0.3 was tidied and CPANized from the original 0.0.2 source by Ido Perelmutter E<lt>ido50@yahoo.comE<gt>.

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
