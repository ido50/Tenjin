package Tenjin;

use Tenjin::Context;
use Tenjin::Engine;
use Tenjin::HTML;
use Tenjin::Template;
use Tenjin::Preprocessor;
use Tenjin::Util;

use strict;

our $VERSION = 0.03;
our $USE_STRICT = 0;

__PACKAGE__;

__END__

=pod

=head1 NAME

Tenjin - Fast templating engine with support for embedded Perl.

=head1 SYNOPSIS

	use Tenjin;
	$Tenjin::USE_STRICT = 1; # use strict in the embedded Perl inside
							 # your templates. Optional but recommended.

	my $engine = new Tenjin::Engine();
	my $context = { title => 'Tenjin Example', items => [qw/AAA BBB CCC/] };
	my $filename = 'file.html';
	my $output = $engine->render($filename, $context);
	print $output;

=head1 DESCRIPTION

Tenjin is a very fast and full-featured templating engine, implemented in several programming languages.
It supports embedded Perl, nestable layout template, other templates inclusion, capture parts of or the
entire template, file and memory caching, template arguments and preprocessing.

=head1 SEE ALSO

See L<<a href="http://www.kuwata-lab.com/tenjin/pltenjin-users-guide.html">detailed usage guide</a>>,
L<<a href="http://www.kuwata-lab.com/tenjin/pltenjin-examples.html">examples</a>> and
L<<a href="http://www.kuwata-lab.com/tenjin/pltenjin-faq.html">frequently asked questions</a>> in the
kuwata-lab.com website.

L<Tenjin::Engine>, L<Tenjin::Template>, L<Catalyst::View::Tenjin>.

=head1 AUTHOR

Tenjin is developed by Makoto Kuwata at L<<a href="http://www.kuwata-lab.com/tenjin/">kuwata-lab.com</a>>. Version 0.03 was tidied and CPANized from the original 0.0.2 source by Ido Perelmutter E<lt>ido50@yahoo.comE<gt>.

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
