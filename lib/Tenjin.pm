package Tenjin;

use Tenjin::Context;
use Tenjin::Engine;
use Tenjin::HTML;
use Tenjin::Template;
use Tenjin::Preprocessor;
use Tenjin::Util;

use strict;

our $VERSION = 0.04;
our $USE_STRICT = 0;
our $ENCODING = "utf8";

__PACKAGE__;

__END__

=pod

=head1 NAME

Tenjin - Fast templating engine with support for embedded Perl.

=head1 SYNOPSIS

	use Tenjin;

	$Tenjin::USE_STRICT = 1;	# use strict in the embedded Perl inside
					# your templates. Recommended, but not used
					# by default.

	$Tenjin::ENCODING = "utf8";	# set the encoding of your template files
					# to utf8. This is the default encoding used
					# so there's no need to do this if your
					# templates really are utf8.

	my $engine = new Tenjin::Engine(\%options);
	my $context = { title => 'Tenjin Example', items => [qw/AAA BBB CCC/] };
	my $filename = 'file.html';
	my $output = $engine->render($filename, $context);
	print $output;

=head1 DESCRIPTION

Tenjin is a very fast and full-featured templating engine, implemented in several programming languages.
It supports embedded Perl, nestable layout template, inclusion of other templates inside a template,
capturing parts of or the entire template output, file and memory caching, template arguments and preprocessing.

Tenjin also comes with a command line application, C<pltenjin>, for rendering templates. For example,
C<pltenjin example.html> will render the template stored in the example.html file. You can also convert
a template to Perl code by using C<pltenjin -s example.html>. This is the code used internally
by Tenjin when rendering templates. There are more options, checkout SEE ALSO for links to the usage guides.

For detailed usage instructions see L<Tenjin::Engine>.

=head1 SEE ALSO

The original Tenjin website is located at L<http://www.kuwata-lab.com/tenjin/>. In there check out
L<http://www.kuwata-lab.com/tenjin/pltenjin-users-guide.html> for detailed usage guide,
L<http://www.kuwata-lab.com/tenjin/pltenjin-examples.html> for examples, and
L<http://www.kuwata-lab.com/tenjin/pltenjin-faq.html> for frequently asked questions.

Note that the Perl version of Tenjin is refered to as plTenjin on the Tenjin website,
and that, as oppose to this module, the website suggests using a .plhtml extension
for the templates instead of .html (this is entirely your choice).

L<Tenjin::Engine>, L<Tenjin::Template>, L<Catalyst::View::Tenjin>.

=head1 TODO

=over

=item * Check if all the sub-modules (like L<Tenjin::Context>, L<Tenjin::HTML>, etc.) are really necessary.

=item * In particular, check if L<Tenjin::HTML> can be replaced with some existing CPAN module (HTML::Tiny was suggested).

=item * Add the documentation files linked in SEE ALSO to the module distribution, like in the original Tenjin.

=item * Expand the description of this module.

=item * Create tests, adapted from the tests provided by the original Tenjin.

=back

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
