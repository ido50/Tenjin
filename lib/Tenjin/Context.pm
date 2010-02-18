package Tenjin::Context;

use strict;
use warnings;

sub new {
	my ($class, $self) = @_;

	$self ||= {};
	return bless $self, $class;
}

sub evaluate {
	my ($self, $script, $filename) = @_;

	my $context = $self;
	$script = ($script =~ /\A.*\Z/s) && $& if $Tenjin::BYPASS_TAINT;
	my $s = $filename ? "# line 1 \"$filename\"\n" : '';  # line directive
	$s .= $script;

	my $ret;
	if ($Tenjin::USE_STRICT) {
		$ret = eval($s);
	} else {
		no strict;
		$ret = eval($s);
		use strict;
	}
	
	return $ret;
}

sub to_func {
	my ($self, $script, $filename) = @_;

	$script = ($script =~ /\A.*\Z/s) && $& if $Tenjin::BYPASS_TAINT;
	my $s = $filename ? "# line 1 \"$filename\"\n" : '';  # line directive
	$s .= "sub { my (\$context) = \@_; $script }";
	
	my $ret;
	if ($Tenjin::USE_STRICT) {
		$ret = eval($s);
	} else {
		no strict;
		$ret = eval($s);
		use strict;
	}
	
	return $ret;
}

sub _build_decl {
	my $self = shift;

	my $s = '';
	foreach my $k (keys %$self) {
		next if $k eq '_context' || $k eq 'context';
		$s .= "my \$$k = \$context->{'$k'}; ";
	}
	return $s;
}

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

Tenjin is developed by Makoto Kuwata at L<http://www.kuwata-lab.com/tenjin/>.
The CPAN version was tidied and CPANized from the original 0.0.2 source (with later updates from Makoto Kuwata's tenjin github repository) by Ido Perlmuter E<lt>ido@ido50.netE<gt>.

=head1 LICENSE AND COPYRIGHT

Tenjin is licensed under the MIT license.

	Copyright (c) 2007-2010 the aforementioned authors.

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
